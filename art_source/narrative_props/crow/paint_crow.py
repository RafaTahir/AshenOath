"""Draw Oren's brush marks, scratched letters and the patinated token face.
Usage: python paint_crow.py BUILD_DIRECTORY  (requires Pillow and NumPy).
Images are packed into the Blender master and the cooked brass mesh.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 512
directory = Path(sys.argv[1])
directory.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(371)
yy, xx = np.mgrid[:SIZE, :SIZE]
u = (xx - 255.5) / 255.5
v = (255.5 - yy) / 255.5
radius = np.hypot(u, v)
grain = rng.normal(0.0, 1.7, (SIZE, SIZE))


def cloud(grid):
    field = rng.integers(0, 256, (grid, grid), dtype=np.uint8)
    return np.asarray(Image.fromarray(field).resize((SIZE, SIZE), Image.Resampling.BICUBIC)) / 255


stain = cloud(15)
small = cloud(66)
hollows = np.exp(-((radius - .872) / .017) ** 2) + .7 * np.exp(-((radius - .911) / .011) ** 2)
patina = np.clip((stain * .67 + small * .33 - .59) * 3.7 + hollows * .72, 0, .88)
light = (stain - .51) * 33 + (small - .5) * 11 + grain
edge = np.exp(-((radius - .955) / .024) ** 2) * 25
brass = np.stack((151 + light + edge, 112 + light + edge, 60 + light + edge), axis=-1)
tarnish = np.stack((61 + light * .45, 95 + light * .43, 74 + light * .49), axis=-1)
surface = brass * (1 - patina[..., None]) + tarnish * patina[..., None]
paint = Image.new("L", (SIZE * 2, SIZE * 2))
pen = ImageDraw.Draw(paint)


def px(pt):
    return tuple(round(x * 2) for x in pt)


def path(points):
    """Smooth a hand-drawn open line without replacing its authored endpoints."""
    p = [points[0], *points, points[-1]]
    samples = []
    for i in range(1, len(p) - 2):
        for step in range(12):
            t = step / 12
            a, b, c, d = map(np.array, p[i - 1:i + 3])
            samples.append(.5 * ((2 * b) + (-a + c) * t + (2*a - 5*b + 4*c - d) * t*t + (-a + 3*b - 3*c + d) * t**3))
    return [*samples, points[-1]]


def line(points, width, strength=255):
    pen.line([px(pt) for pt in path(points)], fill=strength, width=round(2 * width), joint="curve")


def shape(points):
    pen.polygon([px(pt) for pt in points], fill=255)


# Full-bodied crow in profile, tail low, strong short bill, two feet.
shape(path([(137,295),(157,255),(183,217),(204,194),(242,175),(278,158),
            (301,141),(314,113),(335,99),(363,102),(377,112),(389,128)])
      + [(424,143),(391,147),(411,151),(383,153)]
      + path([(383,153),(375,171),(349,189),(336,210),(327,245),(308,265),
              (281,279),(241,288),(209,285),(179,273)])
      + [(127,303),(149,270),(109,290)])
for pts, width in [
    ([(166,255),(142,274),(116,285),(99,298)],6),
    ([(175,261),(157,281),(145,294),(122,308)],5),
    ([(196,270),(186,284),(163,301),(158,305)],4),
    ([(246,279),(241,295),(246,313)],6),
    ([(286,272),(282,290),(288,306)],6),
    ([(225,321),(240,312),(247,313),(267,317)],4),
    ([(257,310),(279,305),(289,305),(307,311)],4)]:
    line(pts,width)
# Four hairline marks in thinning cart paint describe a folded wing.
for pts, width in [
    ([(312,179),(291,174),(267,183),(239,207),(197,244)],3.4),
    ([(289,188),(265,207),(229,235),(200,248)],1.8),
    ([(281,207),(256,228),(217,249)],1.6),
    ([(264,235),(240,248),(221,251)],1.7)]:
    line(pts,width,15)
pen.ellipse((704,226,717,240),fill=0)
mask = np.asarray(paint.resize((SIZE, SIZE), Image.Resampling.LANCZOS)) / 255
# Repeated handling rubs away a small patch at the folded wing tip.
wear = np.exp(-(((xx-215)/33)**2 + ((yy-234)/15)**2)) * np.clip((small-.3)*1.2,0,.65)
mask *= 1-wear
black = np.stack((32 + light*.28, 37 + light*.28, 33 + light*.28),axis=-1)
surface = surface*(1-mask[...,None]) + black*mask[...,None]

# Incised lettering follows the disc's curve; the slight down-right glint is
# a nail catching brass along an old cut, not a typeset label.
letters = {"A":[[(0,1),(.42,0),(.94,1)],[(.2,.59),(.7,.59)]],
           "V":[[(0,0),(.46,1),(.98,-.02)]],
           "E":[[(.79,0),(0,.04),(.03,1),(.83,.96)],[(.05,.49),(.67,.44)]],
           "L":[[(.04,0),(0,1),(.84,.95)]]}
face = Image.fromarray(surface.clip(0,255).astype(np.uint8))
brush = ImageDraw.Draw(face)
for letter,x,y,angle in zip("AVEL",[181,222,264,304],[359,369,371,366],[.19,.07,-.07,-.19]):
    for segment in letters[letter]:
        coords=[]
        for ax,ay in segment:
            ax*=28;ay*=32
            coords.append((x+ax*math.cos(angle)-ay*math.sin(angle),
                           y+ax*math.sin(angle)+ay*math.cos(angle)))
        brush.line(coords,fill=(65,55,39),width=4,joint="curve")
        brush.line([(int(a+1),int(b+1)) for a,b in coords],fill=(213,174,106),width=2,joint="curve")
face.save(directory/"OrenTokenColor.png", optimize=True)
metal = np.clip(228 - 97*patina - 220*mask, 4, 245)
rough = np.clip(113+30*patina+52*mask+light*.45,65,208)
orm = np.stack((np.full_like(rough,255),rough,metal),axis=-1)
Image.fromarray(orm.astype(np.uint8)).save(directory/"OrenTokenORM.png",optimize=True)
