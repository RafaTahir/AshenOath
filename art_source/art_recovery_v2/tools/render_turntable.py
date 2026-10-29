"""Neutral full-orbit source inspection; no selective camera hiding."""
import bpy,math
from pathlib import Path
from mathutils import Vector
here=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(here/'models/C01_anwen_reconstruction_v002.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=4
scene.render.resolution_x=480;scene.render.resolution_y=600
camera=scene.camera;camera.data.ortho_scale=2.15
out=here/'exports/turntable';out.mkdir(exist_ok=True)
for i in range(36):
    angle=i*math.tau/36
    camera.location=(4*math.sin(angle),-4*math.cos(angle),1.35)
    camera.rotation_euler=(Vector((0,0,.94))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/f'{i:02}.png');bpy.ops.render.render(write_still=True)
