"""Neutral full-orbit source inspection; no selective camera hiding."""
import bpy,math,argparse,sys
from pathlib import Path
from mathutils import Vector
here=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--source',default='C01_anwen_reconstruction_v002.blend')
parser.add_argument('--output',default='exports/turntable')
parser.add_argument('--samples',default=12,type=int)
parser.add_argument('--frames',default=36,type=int)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
source=(here/'models'/args.source).resolve();out=(here/args.output).resolve()
assert source.is_relative_to((here/'models').resolve()) and out.is_relative_to(here)
assert 4<=args.frames<=120
bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=args.samples
scene.render.resolution_x=480;scene.render.resolution_y=600
scene.render.resolution_percentage=100
camera=scene.camera;camera.data.ortho_scale=2.15
out.mkdir(parents=True,exist_ok=True)
for i in range(args.frames):
    angle=i*math.tau/args.frames
    camera.location=(4*math.sin(angle),-4*math.cos(angle),1.35)
    camera.rotation_euler=(Vector((0,0,.94))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/f'{i:02}.png');bpy.ops.render.render(write_still=True)
