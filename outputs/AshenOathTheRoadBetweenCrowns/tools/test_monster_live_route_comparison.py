"""Pure invalid-fixture coverage; this does not launch Godot or claim gameplay."""
import copy
import math
import unittest

from compare_monster_live_route import CHECKPOINTS, INPUT_PAIRS, ROUTE_ID, compare, validate_pilot_pair


def matrix():
    observations = []
    for viewport in ([1280, 720], [960, 540]):
        for version in ("baseline", "candidate"):
            for repeat in range(3):
                config = {"viewport": viewport, "frame_limit": 0, "vsync": 0, "physics_hz": 30,
                          "time_scale": 1., "paused": False, "day_locked": False, "quality": "balanced",
                          "resolution_scale": 1., "shadow_quality": 0, "foliage_density": 1,
                          "visual_density": 1, "renderer": "gl_compatibility", "adapter": "synthetic_fixture",
                          "window_client_size":viewport,"internal_viewport":[1280,720],"raw_render_size":[1280,720],
                          "coordinate_contract_valid":True,"coordinate_policy":"production_internal_canvas_with_native_window_stretch"}
                rows = []
                for zone in ("greyfen", "wychwood"):
                    positions = ([[0., 1., 0.], [0., 1., -5.], [0., 1., -5.], [0., 1., 0.], [-3., 1., 0.], [0., 1., 0.]]
                                 if zone == "greyfen" else [[0., 1., 11.], [0., 1., 8.], [0., 1., 8.], [0., 1., 11.], [0., 1., 8.], [0., 1., 8.], [0., 1., 11.]])
                    rows.append({"zone": zone, "configuration": copy.deepcopy(config), "configuration_end": copy.deepcopy(config),
                                 "frames": [[10., 1., 1., 2., 0., 50] for _ in range(100)],
                                 "roster_start": [{"identity": "ghoulkin", "active": True, "dead": False, "physics": True}],
                                 "roster_end": [{"identity": "ghoulkin", "active": True, "dead": False, "physics": True}],
                                 "checkpoints": [{"label": label, "player": position, "camera": [position[0], 3., position[2]+6.],
                                                  "camera_rotation": [0., 0., 0.], "health": 125., "input_context": "gameplay",
                                                  "player_physics": True, "world_minutes": 610., "weather": "clear"} for label, position in zip(CHECKPOINTS[zone],positions)]})
                events = []
                tick = 1000
                for action, duration in INPUT_PAIRS:
                    events.extend([{"action": action, "pressed": True, "tick": tick, "touch": viewport[0]==960},
                                   {"action": action, "pressed": False, "tick": tick+duration, "touch": viewport[0]==960}])
                    tick += duration + 100
                observations.append({"version": version, "repeat": repeat, "qa_script_sha256": "same_qa_hash",
                                     "source_snapshot_sha256": version + "_source_hash", "report": {
                                         "kind": "live_route_performance", "route_id": ROUTE_ID, "viewport": viewport,
                                         "passed": True, "failures": [], "engine_errors": [], "segments": rows, "inputs": events,
                                         "physical_device_coverage": False, "frozen_export_acceptance": False}})
    return observations


class LiveRouteComparison(unittest.TestCase):
    def reject(self, mutate):
        items = matrix()
        mutate(items)
        self.assertFalse(compare(items)["passed"])

    def test_valid_complete_matched_matrix(self):
        result = compare(matrix())
        self.assertTrue(result["passed"], result)
        self.assertEqual(len(result["comparisons"]), 8)

    def test_pilot_pair_rejects_drift_without_claiming_performance(self):
        pair = [item for item in matrix() if item["repeat"]==0 and item["report"]["viewport"]==[1280,720]]
        result = validate_pilot_pair(pair)
        self.assertTrue(result["valid_for_matched_sampling"],result)
        self.assertFalse(result["performance_acceptance"])
        self.assertFalse(compare(pair)["passed"])
        pair[1]["report"]["segments"][0]["checkpoints"][0]["player"][0] += 2
        self.assertFalse(validate_pilot_pair(pair)["valid_for_matched_sampling"])

    def test_single_pair_ratios_are_diagnostic_only(self):
        pair = [item for item in matrix() if item["repeat"]==0 and item["report"]["viewport"]==[960,540]]
        for row in pair[1]["report"]["segments"]:
            for frame in row["frames"]: frame[0]*=2
        result = validate_pilot_pair(pair)
        self.assertTrue(result["valid_for_matched_sampling"],result)
        self.assertFalse(result["performance_acceptance"])

    def test_internal_canvas_cannot_be_mislabelled_physical_window(self):
        self.reject(lambda items: items[-1]["report"]["segments"][0]["configuration"].update(internal_viewport=[960,540]))
        self.reject(lambda items: items[-1]["report"]["segments"][0]["configuration"].update(window_client_size=[1280,720]))
        self.reject(lambda items: items[-1]["report"]["segments"][0]["configuration"].update(raw_render_size=[960,540]))

    def test_ten_percent_inclusive_and_higher_rejected(self):
        for scale, passed in ((1.1, True), (1.10001, False)):
            items = matrix()
            for item in items:
                if item["version"] == "candidate":
                    for row in item["report"]["segments"]:
                        for frame in row["frames"]: frame[0] *= scale
            self.assertEqual(compare(items)["passed"], passed)

    def test_p95_detects_tail_regression(self):
        items = matrix()
        for item in items:
            if item["version"] == "candidate":
                for row in item["report"]["segments"]:
                    for frame in row["frames"][-6:]: frame[0] = 20.
        self.assertFalse(compare(items)["passed"])

    def test_incomplete_duplicate_and_wrong_viewport(self):
        self.reject(lambda items: items.pop())
        self.reject(lambda items: items.append(copy.deepcopy(items[0])))
        self.reject(lambda items: items[0]["report"].update(viewport=[1920, 1080]))

    def test_engine_errors_rejected_even_when_passed_true(self):
        self.reject(lambda items: items[0]["report"]["engine_errors"].append("Freed object typed boundary"))

    def test_unmatched_pacing_or_quality_rejected(self):
        for field, value in (("frame_limit", 60), ("vsync", 1), ("time_scale", 0.), ("paused", True),
                             ("physics_hz", 60), ("day_locked", True), ("quality", "potato"), ("renderer", "forward_plus")):
            self.reject(lambda items: items[0]["report"]["segments"][0]["configuration"].update({field: value}))

    def test_configuration_change_mid_sample_rejected(self):
        self.reject(lambda items: items[0]["report"]["segments"][0]["configuration_end"].update(adapter="different"))

    def test_missing_or_wrong_duration_input_events_rejected(self):
        self.reject(lambda items: items[0]["report"].update(inputs=[]))
        self.reject(lambda items: items[0]["report"]["inputs"][1].update(tick=1003))
        self.reject(lambda items: items[0]["report"]["inputs"][2].update(touch=True))

    def test_route_and_camera_drift_rejected(self):
        for field, value in (("player", [1.01, 1., 0.]), ("camera", [2., 3., 6.]), ("camera_rotation", [.13, 0., 0.])):
            self.reject(lambda items: items[-1]["report"]["segments"][0]["checkpoints"][2].update({field: value}))

    def test_equally_stationary_or_staged_reports_rejected(self):
        items = matrix()
        for item in items:
            for row in item["report"]["segments"]:
                for checkpoint in row["checkpoints"]: checkpoint["player"] = [0.,1.,0.]
        self.assertFalse(compare(items)["passed"])
        self.reject(lambda items: items[0]["report"].update(fixture_pool_scope={"count": 1}))
        self.reject(lambda items: items[0]["report"].update(actors_frozen=True))
        self.reject(lambda items: items[0]["report"]["segments"][0]["configuration"].update(adapter=""))

    def test_workload_safety_environment_and_scope_rejected(self):
        self.reject(lambda items: items[0]["report"]["segments"][1].update(roster_start=[]))
        self.reject(lambda items: items[0]["report"]["segments"][0]["roster_end"][0].update(dead=True))
        for field, value in (("health", 25.), ("input_context", "dialogue"), ("player_physics", False), ("world_minutes", math.nan)):
            self.reject(lambda items: items[0]["report"]["segments"][0]["checkpoints"][0].update({field: value}))
        self.reject(lambda items: items[0]["report"].update(physical_device_coverage=True))

    def test_mismatched_source_or_qa_hash_rejected(self):
        self.reject(lambda items: items[0].update(qa_script_sha256="different"))
        self.reject(lambda items: items[0].update(source_snapshot_sha256="changed"))

    def test_missing_nonfinite_and_invalid_frames_rejected(self):
        for frame in ([0., 0., 0., 0., 0., 0.], [math.nan, 0., 0., 0., 0., 0.], [10., 0.], [True, 0., 0., 0., 0., 0.]):
            self.reject(lambda items: items[0]["report"]["segments"][0]["frames"].__setitem__(0, frame))
        self.reject(lambda items: items[0]["report"]["segments"][0].update(frames=[]))
        self.assertFalse(compare(None)["passed"])
        self.assertFalse(compare([{}])["passed"])

    def test_gpu_zero_is_unavailable_and_does_not_become_fps(self):
        self.assertTrue(compare(matrix())["passed"])


if __name__ == "__main__":
    unittest.main()
