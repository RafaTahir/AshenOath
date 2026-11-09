"""Pure temporary-file/process doubles; never launches Godot or Blender."""
import argparse
from contextlib import ExitStack
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import run_living_scenery_pipeline as pipeline


class Child:
    pid = 4321
    def __init__(self, action="success"):
        self.action=action
        self.running=True
        self.killed=False
    def wait(self, timeout):
        if self.running and self.action=="timeout": raise subprocess.TimeoutExpired("owned",timeout)
        if self.running and self.action=="interrupt": raise KeyboardInterrupt()
        self.running=False
        return -9 if self.killed else 0
    def kill(self): self.killed=True; self.running=False
    def poll(self): return None if self.running else -9 if self.killed else 0


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory(prefix="ao-scenery-pipeline-")
        self.addCleanup(self.temporary.cleanup)
        self.folder=Path(self.temporary.name)

    def test_real_pipeline_has_full_builders_and_no_synthetic_equivalence(self):
        for step in pipeline.STEPS:
            command,deadline,markers=pipeline.command(step)
            self.assertTrue(markers)
            self.assertNotIn("--verify-contract",command)
            self.assertNotIn("--check-only",command)
            if step.startswith("author_"):
                self.assertEqual(deadline,480)
                self.assertIn("--background",command)
                self.assertEqual(command[command.index("--threads")+1],"2")
                self.assertEqual(command[command.index("--python-exit-code")+1],"1")
            else:
                self.assertEqual(deadline,180)
                self.assertIn("--headless",command)
        self.assertEqual(len(pipeline.STEPS),9)

    def run_child(self,action="success",callback=lambda pid: None):
        child=Child(action)
        row={}
        with patch.object(pipeline.subprocess,"Popen",return_value=child):
            try:
                pipeline.run_child(["fake"],1,self.folder/"child.log",{},row,callback)
            finally:
                self.assertFalse(child.running)
                self.assertTrue(row["owned_process_exited"])
                self.assertEqual(row["pid"],4321)
        return child,row

    def test_success_reaps_only_owned_child(self):
        child,row=self.run_child()
        self.assertFalse(child.killed)
        self.assertEqual(row["exit_code"],0)

    def test_timeout_kills_reaps_and_records_failure(self):
        child,row=self.run_child("timeout")
        self.assertTrue(child.killed)
        self.assertTrue(row["timed_out"])
        self.assertEqual(row["exit_code"],-9)

    def test_interrupt_cleans_owned_child_before_propagation(self):
        with self.assertRaises(KeyboardInterrupt): self.run_child("interrupt")

    def test_receipt_write_error_cleans_owned_child(self):
        def fail(pid): raise OSError("receipt write failed")
        with self.assertRaisesRegex(OSError,"receipt write"): self.run_child(callback=fail)

    def checkpoint(self):
        source=self.folder/"source"
        source.write_bytes(b"exact")
        return {"schema_version":1,"kind":"living_scenery_actual_pipeline","status":"checkpoint","output":str(self.folder),
                "runs":[{"step":"extract_campaign","passed":True,"exit_code":0,"timed_out":False}],
                "originals":[],"sources":[pipeline.record(source)],"current_outputs":{}}

    def test_resume_requires_exact_completed_prefix_and_later_boundary(self):
        receipt=self.checkpoint()
        pipeline.validate_checkpoint(receipt,self.folder,"extract_hart")
        for change in ({"status":"failed"},{"owned_pid":123},{"runs":[]},{"runs":[{"step":"extract_hart","passed":True,"exit_code":0,"timed_out":False}]}):
            candidate=copy.deepcopy(receipt); candidate.update(change)
            with self.assertRaises(ValueError): pipeline.validate_checkpoint(candidate,self.folder,"extract_hart")
        with self.assertRaisesRegex(ValueError,"later process boundary"):
            pipeline.validate_checkpoint(receipt,self.folder,"extract_campaign")

    def test_resume_rejects_changed_source_and_output_bytes(self):
        receipt=self.checkpoint()
        target=self.folder/"output"
        target.write_bytes(b"original output")
        receipt["current_outputs"][str(target)]=pipeline.record(target)
        target.write_bytes(b"modified output")
        with self.assertRaisesRegex(ValueError,"changed"):
            pipeline.validate_checkpoint(receipt,self.folder,"extract_hart")
        receipt["current_outputs"]={}
        (self.folder/"source").write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError,"changed"):
            pipeline.validate_checkpoint(receipt,self.folder,"extract_hart")

    def test_logs_fail_closed_on_errors_even_with_zero_exit(self):
        for value in ["SCRIPT ERROR: bad", "Parse Error", "ERROR: resource missing", "ObjectDB instances leaked", "resources still in use"]:
            self.assertIsNotNone(pipeline.BAD.search(value))

    def test_first_failed_step_stops_and_preserves_receipt(self):
        output=self.folder/"run"
        launched=[]
        def run(command,deadline,log,env,row,on_started):
            launched.append(command)
            row.update({"pid":4321,"exit_code":0,"timed_out":False,"owned_process_exited":True,"log":str(log),"seconds":.01})
            on_started(4321)
            log.write_text("SCRIPT ERROR: fixture failure\n")
            return log.read_text()
        with ExitStack() as stack:
            stack.enter_context(patch.object(pipeline,"originals",return_value=[]))
            stack.enter_context(patch.object(pipeline,"source_inputs",return_value=[]))
            stack.enter_context(patch.object(pipeline,"mutable_paths",return_value=[]))
            stack.enter_context(patch.object(pipeline,"run_child",side_effect=run))
            code=pipeline.execute(argparse.Namespace(output=output,resume=False,through="equivalence"))
        self.assertEqual(code,1)
        self.assertEqual(len(launched),1)
        receipt=json.loads((output/"pipeline.json").read_text())
        self.assertEqual(receipt["status"],"failed")
        self.assertNotIn("owned_pid",receipt)
        self.assertFalse(receipt["visual_acceptance"])
        self.assertTrue(Path(receipt["runs"][0]["log"]).is_file())

    def test_authoring_receipt_rejects_changed_or_escaped_archive(self):
        art=self.folder/"art"; models=art/"models"; folder=models/"checkpoint_cloth"
        folder.mkdir(parents=True)
        payload=art/"retained.blend"; payload.write_bytes(b"retained")
        receipt={"asset":"checkpoint_cloth","blender_authored":True,"parts":[{},{}]}
        for field in ("blend","carrier","recipe","retained_input","retained_native","retained_receipt","transport_helper","raw_carrier"):
            receipt[field]="retained.blend";receipt[field+"_sha256"]=pipeline.sha(payload)
        (art/"tools").mkdir()
        for name in ("author_living_world_parts.py","living_world_gltf_transport.py"):
            (art/"tools"/name).write_bytes(b"retained")
        receipt["normal_transport"]={"verified":True,"before_sha256":pipeline.sha(payload),"after_sha256":pipeline.sha(payload)}
        path=folder/"authoring.json"; pipeline.write(path,receipt)
        with patch.object(pipeline,"ART",art),patch.object(pipeline,"MODELS",models):
            self.assertEqual(len(pipeline.outputs("author_checkpoint_cloth")),9)
            (art/"tools/living_world_gltf_transport.py").write_bytes(b"changed helper")
            with self.assertRaisesRegex(ValueError,"stale"): pipeline.outputs("author_checkpoint_cloth")
            (art/"tools/living_world_gltf_transport.py").write_bytes(b"retained")
            payload.write_bytes(b"tampered")
            with self.assertRaisesRegex(ValueError,"provenance mismatch"): pipeline.outputs("author_checkpoint_cloth")
            outside=self.folder/"outside.blend";outside.write_bytes(b"outside")
            receipt["blend"]="../outside.blend";receipt["blend_sha256"]=pipeline.sha(outside)
            pipeline.write(path,receipt)
            with self.assertRaisesRegex(ValueError,"provenance mismatch"): pipeline.outputs("author_checkpoint_cloth")

    def test_completed_boundaries_resume_latest_outputs_and_honor_stop_request(self):
        output=self.folder/"run"
        artifact=self.folder/"mutable_scene"
        launched=[]
        def run(command,deadline,log,env,row,on_started):
            step=pipeline.STEPS[len(launched)]
            launched.append(step)
            row.update({"pid":4321,"exit_code":0,"timed_out":False,"owned_process_exited":True,"log":str(log),"seconds":.01})
            on_started(4321)
            artifact.write_text(step)
            log.write_text("\n".join(pipeline.command(step)[2]))
            if len(launched)==4: (output/"STOP_AFTER_STEP").write_text("return slot after this asset")
            return log.read_text()
        with ExitStack() as stack:
            for name in ("originals","source_inputs","mutable_paths"):
                stack.enter_context(patch.object(pipeline,name,return_value=[]))
            stack.enter_context(patch.object(pipeline,"run_child",side_effect=run))
            stack.enter_context(patch.object(pipeline,"outputs",return_value=[artifact]))
            args=argparse.Namespace(output=output,resume=False,through="extract_mill")
            self.assertEqual(pipeline.execute(args),0)
            self.assertEqual(launched,pipeline.STEPS[:3])
            args.resume=True;args.through="equivalence"
            self.assertEqual(pipeline.execute(args),0)
            self.assertEqual(launched,pipeline.STEPS[:4])
            receipt=json.loads((output/"pipeline.json").read_text())
            self.assertEqual(receipt["status"],"checkpoint")
            self.assertEqual(receipt["stop_request_observed_after"],pipeline.STEPS[3])
            with self.assertRaisesRegex(ValueError,"stop marker"): pipeline.execute(args)
            (output/"STOP_AFTER_STEP").unlink()
            self.assertEqual(pipeline.execute(args),0)
        receipt=json.loads((output/"pipeline.json").read_text())
        self.assertEqual(launched,pipeline.STEPS)
        self.assertEqual(receipt["status"],"passed_geometry")
        self.assertEqual(len(receipt["current_outputs"]),1)
        self.assertEqual(receipt["current_outputs"][str(artifact)]["sha256"],pipeline.sha(artifact))
        self.assertFalse(receipt["actual_level_acceptance"])


if __name__=="__main__": unittest.main()
