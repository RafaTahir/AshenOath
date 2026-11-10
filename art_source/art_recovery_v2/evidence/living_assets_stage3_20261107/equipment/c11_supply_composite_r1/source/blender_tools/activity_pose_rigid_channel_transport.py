"""Pure F32 oracle for Godot 4.6.3's uncompressed octahedral channels.

This does not edit assets or authorize a carrier. Native ArrayMesh packing and
the existing full rigid equivalence gate remain the final tests.
"""
from __future__ import annotations

import math
import struct


def f32(value: float) -> float:
    return struct.unpack('<f', struct.pack('<f', value))[0]


def normalized(values):
    x, y, z = map(f32, values[:3])
    length = f32(math.sqrt(f32(f32(f32(x*x)+f32(y*y))+f32(z*z))))
    if not math.isfinite(length) or length == 0:
        raise ValueError('Nonfinite or zero channel direction')
    return [f32(v/length) for v in (x, y, z)]


def decode_coordinate(p, tangent=False):
    x, y = map(f32, p)
    sign = 1.0
    if tangent:
        y = f32(f32(y*2)-1)
        sign = 1.0 if y >= 0 else -1.0
        y = abs(y)
    x, y = f32(f32(x*2)-1), f32(f32(y*2)-1)
    z = f32(f32(1-abs(x))-abs(y))
    t = min(max(-z, 0.0), 1.0)
    result = normalized([f32(x+(-t if x>=0 else t)), f32(y+(-t if y>=0 else t)), z])
    return result+[sign] if tangent else result


def decode_q(q, tangent=False):
    return decode_coordinate([f32(v/65535) for v in q], tangent)


def pack(values, tangent=False):
    if len(values) != (4 if tangent else 3) or not all(math.isfinite(v) for v in values):
        raise ValueError('Nonfinite or malformed channel')
    x,y,z = map(f32, values[:3])
    total=f32(f32(abs(x)+abs(y))+abs(z))
    if total == 0: raise ValueError('Zero channel direction')
    x,y,z=[f32(v/total) for v in (x,y,z)]
    if z<0:
        x,y=f32(f32(1-abs(y))*(1 if x>=0 else -1)),f32(f32(1-abs(x))*(1 if y>=0 else -1))
    x,y=f32(f32(x*.5)+.5),f32(f32(y*.5)+.5)
    if tangent:
        y=max(y,f32(1/32767))
        y=f32(f32(y*.5)+.5)
        if values[3]<0:y=f32(1-y)
    result=[int(min(max(f32(v*65535),0),65535)) for v in (x,y)]
    # Pinned rendering_server.cpp646: reserve the compression-detection code.
    if tangent and result==[0,65535]:result[0]=65535
    return result


def encode_q(q, tangent=False):
    if len(q)!=2 or any(type(v) is not int or not 0<=v<=65535 for v in q):
        raise ValueError('Invalid exact packed cells')
    if tangent and q==[0,65535]:
        raise ValueError('Native tangent sanitation makes this cell unreachable')
    expected_sign = decode_q(q, True)[3] if tangent else None
    # Search a small deterministic interior grid. End cells at 65535 have a
    # single admissible coordinate, exactly 1; never cross the sign seam.
    for sx in (.5,.25,.75,.125,.875,0):
        for sy in (.5,.25,.75,.125,.875,0):
            p=[f32((v+s)/65535) if v<65535 else 1.0 for v,s in zip(q,(sx,sy))]
            decoded=decode_coordinate(p,tangent)
            # At the folded boundary decode can erase a negative-zero sign.
            # Probe only that zero component's original octant, then prove the
            # exact original cells again. No channel tolerance is introduced.
            oct_y=abs(f32(f32(p[1]*2)-1)) if tangent else p[1]
            signs=[-1 if p[0]<.5 else 1,-1 if oct_y<.5 else 1]
            for epsilon in (0,2**-28,2**-26,2**-24):
                vector=decoded[:3].copy()
                for axis in range(2):
                    if vector[axis]==0:vector[axis]=f32(signs[axis]*epsilon)
                encoded=normalized(vector)+([decoded[3]] if tangent else [])
                if tangent and encoded[3]!=expected_sign:continue
                if pack(encoded,tangent)!=q:continue
                if not tangent and pack(normalized(encoded))!=q:continue
                return encoded
    raise ValueError(f'No verified F32 representative for {q}, tangent={tangent}')
