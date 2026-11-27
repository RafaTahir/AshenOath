"""Build the editable north-kitchen strongbox at real scale.

blender -b -P author_strongbox.py -- OUTPUT.blend intermediate.json
To export edits already made in Blender:
blender -b EDITED.blend -P author_strongbox.py -- --export-current intermediate.json
Godot's bake_strongbox.gd consumes this minimal geometry stream.
"""
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

rng = random.Random(34)
# Greyfen's forge-work anvil, iron-group and axe bronze tints.
IRON = (.25, .28, .28)
EDGE = (.33, .34, .32)
RUB = (.41, .42, .39)
STEEL = (.28, .31, .30)
BRONZE = (.45, .38, .27)
PATINA = (.22, .195, .16)
DARK = (.138, .157, .153)
BLACK = (.067, .079, .079)
CLOTH = (.40, .365, .295)
THREAD = (.52, .46, .34)
PAPER = (.64, .565, .445)
PIVOTS = {
    "Case": (0, 0, 0),
    "Lid": (0, -.164, .218),
    "ClerkBarrel": (-.122, .161, .151),
    "HouseholdBarrel": (.122, .161, .151),
    "CoinTray": (0, 0, .132),
    "WrappedVolume": (0, 0, .033),
}
mats = {}


def pigment(name, rgb):
    key = (name, rgb)
    if key in mats:
        return mats[key]
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m["forge_rgb"] = rgb
    m["finish"] = "fabric" if name in {"Cloth", "Paper", "Thread"} else "forge"
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = .48 if m["finish"] == "forge" else 0
    bsdf.inputs["Roughness"].default_value = .78 if m["finish"] == "forge" else .91
    mats[key] = m
    return m


def object_at(group, name, points, faces, mat, bevel=0):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.materials.append(mat)
    mesh.validate()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.data.collections[group].objects.link(obj)
    if bevel >= .0012:
        mod = obj.modifiers.new("Peened edges", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.harden_normals = True
    return obj


def block(group, name, at, dims, mat, bevel=0):
    x, y, z = (v * .5 for v in dims)
    points = [(i*x, j*y, k*z) for k in (-1,1) for j in (-1,1) for i in (-1,1)]
    faces = [(0,2,3,1),(4,5,7,6),(0,1,5,4),(1,3,7,5),(3,2,6,7),(2,0,4,6)]
    obj = object_at(group, name, points, faces, mat, bevel)
    obj.location = at
    return obj


def cylinder(group, name, a, b, radius, mat, sides=10, r_end=None):
    if radius < .0055: sides = min(sides, 7)
    start, end = Vector(a), Vector(b)
    normal = (end-start).normalized()
    u = normal.cross(Vector((0,0,1)))
    if u.length < .1:
        u = normal.cross(Vector((0,1,0)))
    u.normalize()
    v = normal.cross(u)
    points = []
    for center, ring_r in [(start,radius),(end, r_end if r_end is not None else radius)]:
        for i in range(sides):
            ang = 2*math.pi*i/sides
            points.append(center + ring_r * (u*math.cos(ang) + v*math.sin(ang)))
    faces = [tuple(reversed(range(sides))),tuple(range(sides,sides*2))]
    faces.extend((i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides))
    return object_at(group,name,points,faces,mat)


def plate(group, name, pos, profile, thickness, mat):
    # Mounted on a vertical front or rear surface: polygon in the X/Z plane.
    x, y, z = pos
    points = [(x+dx,y+dy,z+dz) for dy in (0,thickness) for dx,dz in profile]
    n = len(profile)
    faces = [tuple(range(n)),tuple(reversed(range(n,n*2)))]
    faces.extend((i,i+n,(i+1)%n+n,(i+1)%n) for i in range(n))
    return object_at(group,name,points,faces,mat,.0008)


def outline(w,d,cut):
    return [(-w+cut,-d),(w-cut,-d),(w,-d+cut),(w,d-cut),
            (w-cut,d),(-w+cut,d),(-w,d-cut),(-w,-d+cut)]


def shell(group, name, rings, mat):
    # From lower outer edge up the lip and back to the inside floor.
    points = [(x,y,h) for w,d,cut,h in rings for x,y in outline(w,d,cut)]
    indices = list(range(8))
    faces=[tuple(reversed(indices))]
    for band in range(len(rings)-1):
        for i in indices:
            j=(i+1)%8
            faces.append((band*8+i,band*8+j,(band+1)*8+j,(band+1)*8+i))
    faces.append(tuple((len(rings)-1)*8+i for i in indices))
    return object_at(group,name,points,faces,mat,.001)


def hammered_sheet(group, name, center, half_u, half_v, outward, mat, nu, nv):
    # Shallow hammer depressions and oxide left in the worn sheet. The corners,
    # locks and narrow lips are separate pieces, with their own material finish.
    pts, colors, faces = [], [], []
    center, half_u, half_v, normal = map(Vector, (center, half_u, half_v, outward))
    winding = half_u.cross(half_v).dot(normal) > 0
    for j in range(nv+1):
        for i in range(nu+1):
            u, v = 2*i/nu - 1, 2*j/nv - 1
            edge = max(abs(u), abs(v))
            if i not in (0, nu): u += rng.uniform(-.32, .32)/nu
            if j not in (0, nv): v += rng.uniform(-.32, .32)/nv
            wave = .55*math.sin(u*8.3 + v*3.6) + .28*math.cos(v*9.2 - u*3.3)
            pit = wave + rng.uniform(-.32, .32)
            pts.append(center+half_u*u+half_v*v+normal*(.00050*pit))
            strength = .98 + .105*pit + (.09 if edge > .97 else 0)
            oxide = .045*max(0, -pit-.18)
            colors.append((IRON[0]*strength+oxide, IRON[1]*strength-oxide*.17, IRON[2]*strength-oxide*.4, 1))
    for j in range(nv):
        for i in range(nu):
            k = j*(nu+1)+i
            q = (k,k+1,k+nu+2,k+nu+1)
            faces.append(q if winding else tuple(reversed(q)))
    obj = object_at(group, name, pts, faces, mat)
    col = obj.data.color_attributes.new(name="ForgePigment", type="FLOAT_COLOR", domain="POINT")
    for i,c in enumerate(colors): col.data[i].color = c
    for poly in obj.data.polygons: poly.use_smooth = True


def make_model():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.unit_settings.system="METRIC"
    scene.unit_settings.scale_length=1
    for name in PIVOTS:
        scene.collection.children.link(bpy.data.collections.new(name))
    iron=pigment("Iron",IRON)
    steel=pigment("Forged strap",STEEL)
    lip=pigment("Polished edges",EDGE)
    rub=pigment("Rivet wear",RUB)
    bronze=pigment("Bronze",BRONZE)
    dark=pigment("Oiled iron",DARK)
    rust=pigment("Old scale",PATINA)
    shadow=pigment("Warded throat",BLACK)
    shell("Case","Folded cash coffer",[(.248,.148,.010,.008),(.256,.154,.012,.017),
          (.256,.154,.012,.195),(.259,.157,.014,.201),(.259,.157,.014,.209),
          (.245,.144,.012,.209),(.245,.144,.012,.024)],iron)
    shell("Lid","Shallow pressed lid",[(.259,.157,.014,.209),(.261,.159,.014,.213),
          (.261,.159,.014,.221),(.252,.15,.014,.231)],steel)
    hammered_sheet("Lid","Hammered iron top",(0,0,.2319),(.242,0,0),(0,.142,0),(0,0,1),iron,19,11)
    for sign in (-1,1):
        hammered_sheet("Case","Hammered face plate",(0,sign*.1548,.113),(.239,0,0),(0,0,.064),(0,sign,0),iron,18,7)
        hammered_sheet("Case","Peened end plate",(sign*.2568,0,.112),(0,.135,0),(0,0,.072),(sign,0,0),iron,11,7)
    for x in (-.19,.19):
        for y in (-.117,.117):
            block("Case","Bolt-down foot",(x,y,.007),(.156,.044,.014),dark,.0025)
            side=-1 if x<0 else 1
            xx=x+side*.065
            cylinder("Case","Washer",(xx,y,.014),(xx,y,.017),.012,rust,12)
            cylinder("Case","Floor bolt",(xx,y,.017),(xx,y,.022),.0085,rub,6)
    for x in (-.18,.18):
        block("Lid","Wrought lid band",(x,0,.233),(.028,.303,.006),lip,.002)
        for y in (-.153,.153):
            block("Lid","Folded band end",(x,y,.223),(.028,.008,.018),steel,.0015)
        for y in (-.105,.104):
            cylinder("Lid","Peened band rivet",(x,y,.235),(x,y,.238),.0048,rub,8,.0037)
    for y in (-.155,.155):
        block("Case","Seam across plate",(0,y,.043),(.49,.003,.012),dark,.001)
        for x in (-.207,-.15,-.057,.057,.15,.207):
            for h in (.043,.186):
                side=-1 if y<0 else 1
                cylinder("Case","Plate rivet",(x,y,h),(x,y+.004*side,h),.0045,lip,9,.0030)
    for side in (-1,1):
        x=.257*side
        # Fold-down side bail with broad forged mounting ears.
        for y in (-.061,.061):
            block("Case","Handle lugs",(x+.003*side,y,.133),(.010,.022,.032),lip,.0018)
            cylinder("Case","Bail pin",(x+.006*side,y,.139),(x+.012*side,y,.139),.0065,dark,10)
        path=[(x+.009*side,-.061,.139),(x+.014*side,-.052,.121),
              (x+.014*side,-.047,.101),(x+.014*side,-.038,.097),
              (x+.014*side,.038,.097),(x+.014*side,.047,.101),
              (x+.014*side,.052,.121),(x+.009*side,.061,.139)]
        for a,b in zip(path,path[1:]):
            cylinder("Case","Hammered carrying bail",a,b,.0045,steel,8)
    # The book can be recovered around a weak hinge; the locks stay on the front.
    for x in (-.166,.166):
        block("Case","Lower hinge leaf",(x,-.155,.183),(.038,.006,.050),dark,.0025)
        block("Lid","Upper hinge leaf",(x,-.156,.225),(.038,.01,.014),steel,.002)
        for a,b,owner in [(-.026,-.011,"Case"),(-.009,.009,"Lid"),(.011,.026,"Case")]:
            cylinder(owner,"Old rolled hinge",(x+a,-.164,.218),(x+b,-.164,.218),.008,lip,12)
        cylinder("Case","Staked pin",(x-.028,-.164,.218),(x+.028,-.164,.218),.0038,rust,8)
    for x,group,small in [(-.122,"ClerkBarrel",True),(.122,"HouseholdBarrel",False)]:
        profile=([(-.024,-.024),(.024,-.024),(.024,.017),(.017,.025),(-.017,.025),(-.024,.017)] if small
                 else [(-.029,-.018),(0,-.039),(.029,-.018),(.029,.019),(.019,.028),(-.019,.028),(-.029,.019)])
        plate("Case","Clerk lock plate" if small else "Household lock plate",(x,.154,.151),profile,.006,steel if small else dark)
        for dx in (-.017,.017):
            cylinder("Case","Escutcheon stud",(x+dx,.160,.166),(x+dx,.163,.166),.0026,lip,8,.002)
        cylinder(group,"Key cylinder",(x,.160,.150),(x,.165,.150),.010 if small else .0135,lip if small else bronze,16)
        if not small:
            cylinder(group,"Warded key throat",(x,.165,.150),(x,.166,.150),.0063,shadow,12)
        block(group,"Keyway",(x,.1665,.148),(.0028,.001,.009 if small else .013),shadow,.00055)
        for dx in (-1,1):
            cylinder(group,"Bolt scratch",(x+dx*.010,.162,.143),(x+dx*.011,.162,.14),.0006,rust,5)
        tongue=[(-.013,-.009),(0,-.016),(.013,-.009),(.013,.022),(-.013,.022)]
        plate("Lid","Lock tongue",(x,.156,.194),tongue,.005,steel)
        cylinder("Lid","Tongue rivet",(x,.162,.194),(x,.164,.194),.0032,rub,9)
    # A shallow removable counting tray, leaving space below for the narrow volume.
    shell("CoinTray","Tray pan",[(.232,.133,.012,.136),(.238,.139,.012,.139),
          (.238,.139,.012,.154),(.233,.134,.012,.154),(.230,.131,.012,.142)],dark)
    for x in (-.223,.223):
        block("CoinTray","Lift tab",(x,0,.156),(.016,.054,.008),lip,.002)
    placements=[(-.15,-.04,2),(-.12,-.02,3),(-.13,.008,1),(-.06,.016,1),(.105,-.035,2),
                (.08,-.062,1),(.14,.05,1),(-.09,-.072,1),(.014,.045,1)]
    for x,y,n in placements:
        radius=rng.uniform(.011,.015)
        for i in range(n):
            z=.1422+.0022*i
            xx=x+rng.uniform(-.0017,.0017)
            mat = bronze if rng.random()<.6 else lip
            cylinder("CoinTray","Worn count coin",(xx,y,z),(xx,y,z+.0022),radius,mat,14)
        cylinder("CoinTray","Struck face",(xx,y,z+.0022),(xx,y,z+.0027),radius*.52,mat,10)
    block("WrappedVolume","Narrow page block",(0,0,.054),(.137,.221,.028),pigment("Paper",PAPER),.002)
    cloth=pigment("Cloth",CLOTH)
    for z in (.036,.072):
        block("WrappedVolume","Worn cover",(0,0,z),(.143,.227,.008),cloth,.003)
    block("WrappedVolume","Cloth spine",(-.070,0,.054),(.012,.227,.039),cloth,.004)
    # Folded fabric crosses the plain upper cover; no lettering or magical seal.
    block("WrappedVolume","Loose wrapping",(0,-.027,.076),(.14,.077,.0028),pigment("Thread",THREAD),.0015)
    for i in range(3):
        xx=-.032+i*.025
        obj=block("WrappedVolume","Falling fold",(xx,-.027,.077),(.002,.071,.0018),cloth,.0005)
        obj.rotation_euler.z=.055*(i-1)
    for x in (-.210,.205):
        for z in (.089,.098,.111):
            block("Case","Old file strokes",(x+rng.uniform(-.01,.01),.1548,z),
                  (rng.uniform(.009,.021),.001,.0008),rub,.0002).rotation_euler.y=rng.uniform(-.24,.24)
    for obj in bpy.context.scene.objects:
        obj.select_set(False)


def export_meshes(target):
    graph = bpy.context.evaluated_depsgraph_get()
    parts = {}
    for group, pivot in PIVOTS.items():
        surfaces = {}
        for obj in bpy.data.collections[group].objects:
            evaluated = obj.evaluated_get(graph)
            mesh = evaluated.to_mesh()
            mesh.calc_loop_triangles()
            basis = evaluated.matrix_world
            normal_basis = basis.to_3x3().inverted().transposed()
            for face in mesh.loop_triangles:
                mat = mesh.materials[face.material_index]
                surface = surfaces.setdefault(mat["finish"], [])
                # Retain custom/smooth split normals, reverse to Godot winding.
                for corner in reversed(face.loops):
                    loop = mesh.loops[corner]
                    at = basis @ mesh.vertices[loop.vertex_index].co - Vector(pivot)
                    norm = (normal_basis @ mesh.corner_normals[corner].vector).normalized()
                    attr = mesh.color_attributes.get("ForgePigment")
                    color = attr.data[loop.vertex_index].color[:3] if attr is not None else mat["forge_rgb"]
                    surface.append([round(v,6) for v in (at.x,at.z,-at.y,norm.x,norm.z,-norm.y,*color)])
            evaluated.to_mesh_clear()
        parts[group] = surfaces
    target.write_text(json.dumps(parts,separators=(",",":")))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--")+1:]
    if args[0] == "--export-current":
        export_meshes(Path(args[1]))
    else:
        make_model()
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(Path(args[0]).resolve()), compress=True)
        export_meshes(Path(args[1]))
