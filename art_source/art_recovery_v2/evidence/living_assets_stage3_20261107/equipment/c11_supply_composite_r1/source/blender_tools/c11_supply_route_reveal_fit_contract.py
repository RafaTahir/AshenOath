"""Match every Blender fitting frame to the actual revealed native socket."""
from inspect_living_activity_carrier import POSITION_TOLERANCE, frame_columns, matrix_error, require

PLACEMENT = "e6b8431e7b03c8569ea4f08935fcf8f4d0b4a38a738ef6a4d0b6918e1f1bf10b"


def check_native_socket(row, candidate):
    from mathutils import Matrix, Vector

    witness = row["socket_witness"]
    require(row["prop_visible"] is True and witness["placement_sha256"] == PLACEMENT and witness["bone"] == "hand_r" and
            witness["anchor_error_m"] <= .001, "Actual native reveal binding differs from the fixed provisional supply grip")
    hand = Matrix(frame_columns(row["hand_frame"]))
    scale = hand.to_3x3().col[0].length
    require(scale > .001, "Native socket hand scale is invalid")
    basis = hand.to_3x3() * (1.0 / scale)
    frame = (basis @ candidate["basis"]).to_4x4()
    frame.translation = hand.translation + basis @ Vector(candidate["translation"])
    error = matrix_error(frame_columns(witness["frame"]), frame)
    require(error <= POSITION_TOLERANCE, "Native fitted socket transform differs from the fixed Blender placement")
    return error
