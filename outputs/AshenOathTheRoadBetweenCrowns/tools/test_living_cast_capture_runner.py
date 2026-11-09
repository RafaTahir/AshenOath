"""Guard isolated observation setup independently of native visual acceptance."""
import json
import copy
from pathlib import Path
import tempfile
import unittest

from run_living_cast_capture import observation_state, isolated_configuration, validate_behavior, compare_performance


class ObservationSetup(unittest.TestCase):
    def read_state(self, data):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "observation.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            return observation_state(path)

    def test_scalar_flags_preserve_values_without_quest_state(self):
        value = {"flags":{"senn_fate":"testimony", "final_choice_completed":False, "campaign_revision":1}}
        self.assertEqual(self.read_state(value), value)
        for invalid in ({"quests":{}}, {"flags":{}, "quests":{}}, {"flags":{"x":[1]}}, {"flags":{"x":float("nan")}}):
            with self.assertRaises(ValueError): self.read_state(invalid)

    def test_existing_isolation_is_replaced_before_renderer_starts(self):
        for newline in ("\n", "\r\n"):
            source = newline.join(['config_version=5', '[application]', 'config/name="Ashen Oath"',
                                   'config/use_custom_user_dir=false', 'config/custom_user_dir_name="campaign"',
                                   '[display]', 'window/size/viewport_width=1280', '']).encode()
            result = isolated_configuration(source, "AshenOathCapture/regional-fixture").decode()
            self.assertEqual(result.count("config/use_custom_user_dir="), 1)
            self.assertEqual(result.count("config/custom_user_dir_name="), 1)
            self.assertIn('config/custom_user_dir_name="AshenOathCapture/regional-fixture"', result)
            self.assertIn('window/size/viewport_width=1280', result)

    def test_focus_flags_are_set_before_any_native_window_exists(self):
        for newline in ("\n", "\r\n"):
            source = newline.join(['[application]', 'config/name="Ashen Oath"', '[display]',
                                   'window/size/no_focus=false', 'window/size/no_focus.windows=false',
                                   'window/size/mode=3', 'window/size/mode.windows=2',
                                   'window/stretch/mode="canvas_items"', '[rendering]',
                                   'renderer/rendering_method="gl_compatibility"', '']).encode()
            result = isolated_configuration(source,"AshenOathCapture/background-fixture").decode()
            self.assertEqual(result.count('window/size/no_focus='),1)
            self.assertIn('window/size/no_focus=true',result)
            self.assertIn('window/size/mode=0',result)
            self.assertNotIn('window/size/no_focus.windows',result)
            self.assertNotIn('window/size/mode.windows',result)
            self.assertIn('window/stretch/mode="canvas_items"',result)
            self.assertIn('[rendering]'+newline+'renderer/rendering_method="gl_compatibility"',result)

    def test_background_display_section_is_added_without_duplicate_sections(self):
        result=isolated_configuration(b'[application]\nconfig/name="Ashen Oath"\n',"AshenOathCapture/background-fixture")
        self.assertEqual(result.count(b'[display]'),1)
        self.assertIn(b'window/size/no_focus=true',result)
        with self.assertRaises(ValueError):
            isolated_configuration(b'[application]\n[display]\n[display]\n',"AshenOathCapture/background-fixture")


class CaptureAcceptance(unittest.TestCase):
    def work(self, identity="mira", activity="sort_herbs"):
        native = {"clip":"life/Life_Work","phase":.50,"contact_fraction":.50,"cycle":2}
        sides = {"right":"hammer"} if identity=="tor" else {"left":"cloth"} if identity=="anwen" else {"left":"palm","right":"palm"}
        probes = {side:{"kind":kind,"cycle":2,"error":.01,"actual":[.1,1,.1],"target":[.1,1,.11]} for side,kind in sides.items()}
        sample = {"activity_active":True,"activity":activity,"native_life":native,"contact_probes":probes}
        return {"actor":identity,"identity":identity,"environment":"day","scenario":"work","initial":copy.deepcopy(sample),"samples":[sample],"final":copy.deepcopy(sample),"contacts":[{"event":"contact","state":copy.deepcopy(sample)}]}

    def check_row(self, row, mode="candidate"):
        return validate_behavior({"scenarios":[row]},mode)

    def test_native_physical_contact_accepts_only_measured_sides(self):
        for identity,activity in [("mira","sort_herbs"),("tor","forge"),("anwen","care")]:
            self.assertTrue(self.check_row(self.work(identity,activity))["candidate_behavior_accepted"])
        row=self.work()
        del row["contacts"][0]["state"]["contact_probes"]["left"]
        self.assertTrue(self.check_row(row)["errors"])

    def test_waiting_in_idle_does_not_count_as_occupation(self):
        row=self.work()
        row["samples"][0]["native_life"]["clip"]="life/Life_Idle_A"
        row["contacts"]=[]
        result=self.check_row(row)
        self.assertEqual(len(result["errors"]),2)
        self.assertFalse(result["candidate_behavior_accepted"])

    def test_old_cycle_and_forged_reported_error_fail(self):
        for mutation in ("cycle","position","nonfinite","wrist","phase"):
            row=self.work()
            probe=row["contacts"][0]["state"]["contact_probes"]["right"]
            if mutation=="cycle": probe["cycle"]=1
            elif mutation=="position": probe["actual"][1]=1.2; probe["error"]=0.0
            elif mutation=="nonfinite": probe["actual"][0]=float("nan")
            elif mutation=="wrist": probe["kind"]="wrist"
            else: row["contacts"][0]["state"]["native_life"]["phase"]=.8
            self.assertTrue(self.check_row(row)["errors"],mutation)

    def test_senn_watch_does_not_require_fabricated_contact(self):
        row=self.work("senn","watch")
        row["contacts"]=[]
        self.assertTrue(self.check_row(row)["candidate_behavior_accepted"])

    def test_daytime_rest_cannot_stand_in_for_occupation(self):
        row=self.work()
        row["initial"]["activity"]="rest"
        self.assertTrue(self.check_row(row)["errors"])

    def test_supported_sleep_and_standing_fallback_are_explicit(self):
        row=self.work()
        row["environment"]="night"
        row["initial"]["activity"]="sleep"
        row["contacts"]=[]
        self.assertTrue(self.check_row(row)["errors"])
        row["samples"][0].update(attention="sleep",rest_supported=True,presentation="life:sleep")
        self.assertTrue(self.check_row(row)["candidate_behavior_accepted"])
        row["samples"][0].update(attention="neutral",rest_supported=False,presentation="life:rest")
        self.assertTrue(self.check_row(row)["candidate_behavior_accepted"])

    def test_historical_missing_behavior_is_a_limitation_not_acceptance(self):
        row=self.work()
        row["samples"][0]["native_life"]={}
        row["contacts"]=[]
        result=self.check_row(row,"baseline-observation")
        self.assertFalse(result["errors"])
        self.assertTrue(result["limitations"])
        self.assertFalse(result["candidate_behavior_accepted"])

    def test_idle_requires_both_native_variations(self):
        row=self.work()
        row["scenario"]="idle"
        row["samples"]=[{"native_life":{"clip":"life/Life_Idle_A"}}]
        self.assertTrue(self.check_row(row)["errors"])
        row["samples"].append({"native_life":{"clip":"life/Life_Idle_B"}})
        self.assertTrue(self.check_row(row)["candidate_behavior_accepted"])

    def test_plain_observation_never_claims_candidate_behavior(self):
        row=self.work()
        row["scenario"]="observe"
        self.assertFalse(self.check_row(row)["candidate_behavior_accepted"])


class PerformanceAcceptance(unittest.TestCase):
    def baseline(self):
        anchors=[{"view":index} for index in range(3)]
        rows=[{"anchor":anchor,"repeat":repeat,"samples":100,"p50_ms":10.0,"p95_ms":20.0} for anchor in anchors for repeat in range(3)]
        return {"status":"pass","acceptance_mode":"baseline-observation","viewport":[1280,720],"zone":"greyfen",
                "configuration":{"quality":"balanced","renderer":"gl_compatibility","physics_ticks_per_second":60,"window_mode":"background-rendered"},
                "performance_preflight":anchors,"performance":rows}

    def test_exact_ten_percent_boundary_passes(self):
        baseline=self.baseline()
        candidate=copy.deepcopy(baseline)
        for row in candidate["performance"]: row["p50_ms"]*=1.1; row["p95_ms"]*=1.1
        self.assertTrue(compare_performance(candidate,baseline)["accepted"])

    def test_matching_camera_cannot_hide_frame_time_regression(self):
        baseline=self.baseline()
        candidate=copy.deepcopy(baseline)
        for row in candidate["performance"]: row["p95_ms"]*=1.1001
        self.assertFalse(compare_performance(candidate,baseline)["accepted"])

    def test_missing_repeats_or_changed_viewport_fail(self):
        baseline=self.baseline()
        candidate=copy.deepcopy(baseline)
        candidate["performance"].pop()
        self.assertFalse(compare_performance(candidate,baseline)["accepted"])
        candidate=copy.deepcopy(baseline)
        candidate["viewport"]=[960,540]
        self.assertFalse(compare_performance(candidate,baseline)["accepted"])

    def test_foreground_or_unlabelled_performance_is_not_comparable(self):
        baseline=self.baseline()
        candidate=copy.deepcopy(baseline)
        baseline["configuration"].pop("window_mode")
        self.assertFalse(compare_performance(candidate,baseline)["accepted"])
        candidate["configuration"].pop("window_mode")
        self.assertFalse(compare_performance(candidate,baseline)["accepted"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
