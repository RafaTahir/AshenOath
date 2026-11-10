"""Authoring-only transport of Godot 4.6.3's actual uint16 skin weights.

The engine normalizes glTF weights and then truncates float32 * 65535. Raw
ArrayMesh readback values cannot simply be normalized without changing skin.
Encode inside each original truncation cell, and prove the actual stored integer
after both normalization passes. This never changes the comparison reference.
"""
from __future__ import annotations

import math
import struct

MAX_WEIGHT = 65535


def f32(value: float) -> float:
    return struct.unpack('<f', struct.pack('<f', value))[0]


def normalize_f32(values: list[float]) -> list[float]:
    total = f32(0.0)
    for value in values:
        total = f32(total + value)
    return [f32(value / total) for value in values] if total > 0 else list(values)


def pack_f32(values: list[float]) -> list[int]:
    return [int(min(MAX_WEIGHT, max(0, f32(value * MAX_WEIGHT)))) for value in values]


def readback_q(values: list[float]) -> list[int]:
    """Require exact float32 readback of the renderer's uint16 values."""
    if len(values) not in (4, 8):
        raise ValueError('Expected exactly four or eight retained weights')
    result = []
    for value in values:
        if not isinstance(value, (int, float)) or isinstance(value, bool) or not math.isfinite(value) or not 0 <= value <= 1:
            raise ValueError('Invalid retained skin weight')
        quantized = round(value * MAX_WEIGHT)
        if f32(quantized / MAX_WEIGHT) != f32(value):
            raise ValueError('Weight is not an exact native uint16 readback')
        result.append(quantized)
    return result


def encode_q(quantized: list[int]) -> list[float]:
    """Return F32 glTF values with exactly the original packed skin weights.

    Zero slots are kept literally zero whenever feasible. In the rare case that
    they are needed for a sum-one representation, their values stay inside the
    zero quantization cell. This preserves their actual GPU weight as zero.
    Infeasible inputs fail closed; there is no nearest-weight approximation.
    """
    if len(quantized) not in (4, 8) or any(type(q) is not int or not 0 <= q <= MAX_WEIGHT for q in quantized):
        raise ValueError('Invalid four/eight-slot uint16 skin vector')
    deficit = MAX_WEIGHT - sum(quantized)
    if not 0 <= deficit < len(quantized):
        raise ValueError('No normalized representation inside retained quantization cells')
    nonzero = [i for i, q in enumerate(quantized) if q]
    for slots in (nonzero, list(range(len(quantized)))):
        if not slots or deficit >= len(slots):
            continue
        bump = deficit / len(slots)
        encoded = [f32((q + (bump if i in slots else 0.0)) / MAX_WEIGHT) for i, q in enumerate(quantized)]
        once = normalize_f32(encoded)
        twice = normalize_f32(once)
        if pack_f32(encoded) == quantized and pack_f32(once) == quantized and pack_f32(twice) == quantized:
            return encoded
    raise ValueError('F32 normalization cannot preserve the exact retained quantization cells')


def encode_readback(values: list[float]) -> dict:
    quantized = readback_q(values)
    encoded = encode_q(quantized)
    return {'verified': True, 'retained_q': quantized, 'encoded_f32': encoded,
            'packed_after_two_normalizations': pack_f32(normalize_f32(normalize_f32(encoded))),
            'literal_zero_slots_preserved': all(value == 0 for q, value in zip(quantized, encoded) if q == 0),
            'native_verified': False, 'blender_skin_verified': False}
