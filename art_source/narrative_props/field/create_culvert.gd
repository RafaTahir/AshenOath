extends SceneTree
## Bake the culvert set in Godot 4.6.3. From the project use
## godot --headless --path . --script <repository>/art_source/narrative_props/field/create_culvert.gd
## Each mesh has one indexed surface. All parts share one embedded detail atlas.
const OUT := "res://assets/narrative_props/field/"
const OAK := Color("#775139")
const EDGE := Color("#ae865c")
const IRON := Color("#403d36")
const STONE := Color("#77776a")
const LINEN := Color("#d5c9a6")
const CORD := Color("#a48b59")
const WOOL := Color("#755041")
const SEAM := Color("#bc915c")
const WILLOW := Color("#716d50")
const COAL := Color("#34322e")
enum Surface { WOOD, CLOTH, STONEWORK, METAL }
var tool: SurfaceTool
var mat: StandardMaterial3D

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_make_finish()
	var parts := ["cart", "bank", "litter", "ward", "wreck", "lever"]
	for part: String in parts:
		tool = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		match part:
			"cart": _cart()
			"bank": _bank()
			"litter": _litter()
			"ward": _ward()
			"wreck": _wreck()
			"lever": _lever()
		tool.index()
		var mesh := tool.commit()
		mesh.surface_set_material(0, mat)
		mesh.resource_name = "Culvert_" + part
		_save(mesh, part, 0x59f00a002d401110 + parts.find(part))
	quit()

func _save(resource: Resource, part: String, uid: int) -> void:
	var path := OUT + "culvert_" + part + ".res"
	assert(ResourceSaver.save(resource,path,ResourceSaver.FLAG_COMPRESS) == OK)
	assert(ResourceSaver.set_uid(path,uid) == OK)

func _make_finish() -> void:
	var im := Image.create(128,512,false,Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 7191
	noise.frequency = .045
	for row in 512:
		var y := row % 128
		for x in 128:
			var field := noise.get_noise_2d(x,y)
			var shade := .88
			match floori(row/128.0):
				Surface.WOOD:
					var fibre := sin(y*.41+noise.get_noise_2d(x*.46,y*1.1)*4.6)
					shade = .83 + .084*fibre + .08*field + .035*sin(y*2.3+field)
				Surface.CLOTH:
					shade = .85+.035*sin(x*PI/2)+.043*sin(y*PI/2)+.036*field
				Surface.STONEWORK: shade = .83+.14*field+.035*noise.get_noise_2d(x*9.0,y*9.0)
				Surface.METAL: shade = .86+.09*field+.015*sin(y*1.7)
			im.set_pixel(x,row,Color(shade,shade,shade))
	im.generate_mipmaps()
	var tex := PortableCompressedTexture2D.new()
	tex.set_keep_compressed_buffer(true)
	tex.resource_scene_unique_id = "Texture_CulvertFinish"
	tex.create_from_image(im,PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY,false,.83)
	mat = StandardMaterial3D.new()
	mat.resource_name = "Rain-dark oak, twill, mortar and worked iron"
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.albedo_texture = tex
	mat.roughness = .86
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_save(mat,"finish",0x59f00a002d40111f)
	mat = load(OUT+"culvert_finish.res")

func _vertex(p: Vector3, n: Vector3, uv: Vector2, col: Color, surface: int) -> void:
	tool.set_normal(n)
	tool.set_uv(Vector2(.008+uv.x*.984,(surface+.008+uv.y*.984)/4.0))
	tool.set_color(col)
	tool.add_vertex(p)

func _face(a: Vector3,b: Vector3,c: Vector3,d: Vector3,col: Color,surface: int) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.length_squared() < .5: return
	_vertex(a,normal,Vector2(0,0),col,surface)
	_vertex(c,normal,Vector2(1,1),col,surface)
	_vertex(b,normal,Vector2(1,0),col,surface)
	_vertex(a,normal,Vector2(0,0),col,surface)
	_vertex(d,normal,Vector2(0,1),col,surface)
	_vertex(c,normal,Vector2(1,1),col,surface)

func _board(a: Vector3,b: Vector3,width: float,depth: float,col: Color,surface: int=Surface.WOOD) -> void:
	var dir := a.direction_to(b)
	var side := dir.cross(Vector3.UP)
	if side.length_squared()<.001: side = dir.cross(Vector3.BACK)
	side = side.normalized()*width*.5
	var top := side.normalized().cross(dir)*depth*.5
	var sides := [top-side,top+side,side-top,-top-side]
	for i in 4:
		var j := (i+1)%4
		_face(a+sides[i],a+sides[j],b+sides[j],b+sides[i],col.lightened(.018*(i%2)),surface)
	_face(a+sides[0],a+sides[3],a+sides[2],a+sides[1],col.darkened(.15),surface)
	_face(b+sides[0],b+sides[1],b+sides[2],b+sides[3],col.darkened(.1),surface)

func _bar(a: Vector3,b: Vector3,r0: float,r1: float,col: Color,surface: int,segments: int=9) -> void:
	var axis := a.direction_to(b)
	var u := axis.cross(Vector3.UP)
	if u.length_squared() < .001: u=axis.cross(Vector3.RIGHT)
	u=u.normalized()
	var v := axis.cross(u)
	var p: Vector3
	var q: Vector3
	for i in segments:
		var t := TAU*i/segments
		var t1 := TAU*(i+1)/segments
		p = u*cos(t)+v*sin(t)
		q = u*cos(t1)+v*sin(t1)
		_face(a+p*r0,a+q*r0,b+q*r1,b+p*r1,col.lightened(.028*(i%3)),surface)
		_face(a,a+q*r0,a+p*r0,a,col.darkened(.1),surface)
		_face(b,b+p*r1,b+q*r1,b,col.darkened(.09),surface)

func _loop(center: Vector3,axis: Vector3,r: float,thick: float,col: Color,surf: int,n: int) -> void:
	var u := axis.cross(Vector3.UP)
	if u.length_squared() < .001: u = axis.cross(Vector3.RIGHT)
	u=u.normalized(); var v:=axis.cross(u)
	for i in n:
		var a := TAU*i/n
		var b := TAU*(i+1)/n
		_bar(center+(u*cos(a)+v*sin(a))*r,center+(u*cos(b)+v*sin(b))*r,thick,thick,col,surf,6)

func _wheel(c: Vector3) -> void:
	var radius := .49
	_loop(c,Vector3.RIGHT,radius,.045,EDGE,Surface.WOOD,18)
	_loop(c,Vector3.RIGHT,radius+.025,.022,IRON,Surface.METAL,18)
	for i in 10:
		var a := TAU*i/10
		_board(c,c+Vector3(0,cos(a),sin(a))*(radius-.018),.052,.039,OAK)
	_bar(c-Vector3(.12,0,0),c+Vector3(.13,0,0),.095,.073,EDGE,Surface.WOOD,10)
	_bar(c-Vector3(.15,0,0),c-Vector3(.13,0,0),.061,.066,IRON,Surface.METAL)

func _sack(c: Vector3,rot: float,size: Vector3,col: Color) -> void:
	var profile := [Vector2(.78,0),Vector2(.98,.11),Vector2(1,.45),Vector2(.88,.66),Vector2(.33,.84),Vector2(.10,.9),Vector2(.29,1)]
	var n := 14
	for j in profile.size()-1:
		for i in n:
			var points := PackedVector3Array()
			for pair: Vector2i in [Vector2i(i,j),Vector2i(i,j+1),Vector2i(i+1,j+1),Vector2i(i+1,j)]:
				var a := TAU*pair.x/n
				var r: Vector2=profile[pair.y]
				var wobble := 1.+.075*cos(3*a+.55*pair.y)
				var local := Vector3(r.x*cos(a)*size.x*wobble,r.y*size.y,r.x*sin(a)*size.z)
				points.append(c+local.rotated(Vector3.UP,rot))
			_face(points[0],points[1],points[2],points[3],col,Surface.CLOTH)
	_loop(c+Vector3.UP*size.y*.90,Vector3.UP,size.x*.13,.014,CORD,Surface.CLOTH,10)

func _cart() -> void:
	_wheel(Vector3(-.70,.52,-.04))
	_wheel(Vector3(.70,.52,-.04))
	_bar(Vector3(-.84,.52,-.04),Vector3(.84,.52,-.04),.059,.06,IRON,Surface.METAL)
	for i in 7:
		var x := (i-3)*.157
		_board(Vector3(x,.64,-.87),Vector3(x,.64,.82),.153,.079,OAK.lightened(.021*(i%3)))
	for x in [-.575,.575]:
		_board(Vector3(x,.56,-.91),Vector3(x*.73,.66,2.09),.084,.12,EDGE)
		for z in [-.795,.02,.74]:
			_bar(Vector3(x,.61,z),Vector3(x,.99,z),.033,.034,IRON,Surface.METAL,6)
		for y in [.75,.924]:
			_board(Vector3(x,y,-.84),Vector3(x,y,.80),.064,.113,OAK)
	for y in [.75,.924]:
		_board(Vector3(-.60,y,-.81),Vector3(.60,y,-.81),.064,.113,OAK.darkened(.08))
	_board(Vector3(-.575,.80,.80),Vector3(.575,.80,.80),.08,.26,OAK)
	_sack(Vector3(-.18,.685,-.40),.22,Vector3(.31,.53,.25),LINEN)
	_sack(Vector3(.20,.685,.16),-.50,Vector3(.25,.48,.30),LINEN.darkened(.12))
	_sack(Vector3(-.28,.685,.42),.38,Vector3(.235,.40,.22),Color("#b09e74"))
	# Relief bedding is rolled along the rail and lashed at both ends.
	_bar(Vector3(-.45,1.04,-.67),Vector3(-.45,1.04,.27),.122,.119,Color("#716b61"),Surface.CLOTH,14)
	for z in [-.52,.10]:
		_bar(Vector3(-.45,1.04,z),Vector3(-.45,1.04,z+.028),.128,.129,CORD,Surface.CLOTH,12)
	for j in 12:
		var a:=j*.72
		var b:=(j+1)*.72
		_bar(Vector3(-.45+cos(a)*(.019+.011*a),1.04+sin(a)*(.019+.011*a),.276),
			Vector3(-.45+cos(b)*(.019+.011*b),1.04+sin(b)*(.019+.011*b),.276),.006,.006,Color("#4b4c43"),Surface.CLOTH,5)
	# The Vargan order is pinned to the side of the transport, facing the road.
	_face(Vector3(-.27,.94,.84),Vector3(.25,.93,.84),Vector3(.26,.677,.86),Vector3(-.24,.67,.864),Color("#d2c29e"),Surface.CLOTH)
	for j in 5:
		_board(Vector3(-.19,.886-.029*j,.867),Vector3(.13+.015*(j%2),.882-.029*j,.867),.012,.005,IRON,Surface.METAL)
	_bar(Vector3(.178,.72,.865),Vector3(.178,.72,.88),.039,.036,Color("#9b4032"),Surface.CLOTH,9)

func _lever() -> void:
	_bar(Vector3(-.40,0,0),Vector3(1.47,.28,.34),.045,.045,OAK,Surface.WOOD,9)
	_bar(Vector3(-.43,-.004,-.003),Vector3(-.26,.022,.03),.038,.055,IRON,Surface.METAL,8)
	for i in 10:
		var c:=Vector3(.92+i*.038,.198+i*.005,.24+i*.007)
		_bar(c,c+Vector3(.029,.004,.008),.048,.048,CORD,Surface.CLOTH,8)

func _stone(a: Vector3,b: Vector3,w: float,h: float,shade: float=0.0) -> void:
	_board(a,b,w,h,STONE.darkened(shade),Surface.STONEWORK)

func _bank() -> void:
	# The masonry arch is open at the centre, leaving the casualty's arm and the wheel legible.
	for i in 9:
		var t0:=i*PI/9+.012
		var t1:=(i+1)*PI/9-.012
		var corners:=PackedVector3Array()
		for pair: Vector2 in [Vector2(t0,.66),Vector2(t1,.66),Vector2(t1,1.0),Vector2(t0,1.0)]:
			corners.append(Vector3(cos(pair.x)*pair.y,sin(pair.x)*pair.y*.78,-.14))
		var offset:=Vector3(0,0,-.58)
		_face(corners[0],corners[1],corners[2],corners[3],STONE.lightened(.045*(i%3)),Surface.STONEWORK)
		_face(corners[3]+offset,corners[2]+offset,corners[1]+offset,corners[0]+offset,STONE,Surface.STONEWORK)
		for face in 4:
			var next:=(face+1)%4
			_face(corners[face],corners[next],corners[next]+offset,corners[face]+offset,STONE.darkened(.10),Surface.STONEWORK)
	for side in [-1,1]:
		for i in 3:
			var x:float=side*(1.06+i*.22)
			_stone(Vector3(x,.18,-.76),Vector3(x+.055,.19,-.09),.26,.35,.06*(i%2))
	# The man's loose sleeve folds under the axle at the stone lip. Its torn cloth remains in the wreck.
	var snag := [Vector3(-.88,.586,.055),Vector3(-.87,.52,-.055),Vector3(-.80,.40,-.18),Vector3(-.72,.36,-.22)]
	for j in snag.size()-1:
		var a:Vector3=snag[j]
		var b:Vector3=snag[j+1]
		_face(a-Vector3(.044,0,0),a+Vector3(.044,.012,0),b+Vector3(.044,.012,0),b-Vector3(.044,0,0),Color("#806849"),Surface.CLOTH)
		_face(a+Vector3(.025,.014,0),a+Vector3(.043,.014,0),b+Vector3(.043,.014,0),b+Vector3(.025,.014,0),Color("#b39748"),Surface.CLOTH)
	# Pollarded willow, splayed wet roots and the height marker beside it.
	_bar(Vector3(1.19,0,-.54),Vector3(1.28,.89,-.69),.20,.14,WILLOW,Surface.WOOD,10)
	_bar(Vector3(1.28,.89,-.69),Vector3(1.13,1.62,-.79),.14,.096,WILLOW,Surface.WOOD,9)
	_bar(Vector3(1.16,1.5,-.77),Vector3(1.46,2.00,-.81),.075,.039,WILLOW,Surface.WOOD,7)
	_bar(Vector3(1.13,1.62,-.79),Vector3(.78,1.87,-.85),.073,.04,WILLOW,Surface.WOOD,7)
	for k in 7:
		var s:= -1.0 if k%2==0 else 1.0
		var fork:=Vector3(1.11+s*.30,1.81+.15*(k%2),-.81)
		var crown:=fork+Vector3(s*(.24+.058*(k%3)),.30+.12*cos(k*2.3),.18*sin(k*1.91))
		var tail:=crown+Vector3(.14*s,-.27-.055*(k%4),.09*cos(k))
		_bar(fork,crown,.028,.015,WILLOW,Surface.WOOD,7)
		_bar(crown,tail,.014,.004,WILLOW,Surface.WOOD,6)
		for j in 4:
			var mid:=crown.lerp(tail,j/4.0)
			var outward:=Vector3(.073*s,-.10,.055*(1-j%2))
			_face(mid,mid+outward*.45+Vector3(.02,.006,.021),mid+outward,mid+outward*.45-Vector3(.02,.006,.021),Color("#686f47"),Surface.CLOTH)
	for i in 5:
		var a:=i*1.45
		_bar(Vector3(1.20,.16,-.54),Vector3(1.20+cos(a)*.50,.036,-.54+sin(a)*.52),.085,.017,WILLOW,Surface.WOOD)
	_stone(Vector3(2.51,.39,-.91),Vector3(2.51,.39,-.58),.37,.78,.08)
	_stone(Vector3(2.51,.80,-.91),Vector3(2.51,.80,-.58),.36,.06)
	_stone(Vector3(2.20,.175,-.92),Vector3(2.20,.175,-.34),.55,.35,.04)
	for level in [.40,.47,.54]:
		_board(Vector3(2.40,level,-.572),Vector3(2.54,level,-.572),.012,.015,COAL,Surface.STONEWORK)
	# The broken earth opens onto a shallow patch of brown runoff and trapped willow sticks.
	for i in 6:
		var x:= -.65+.21*i
		_face(Vector3(x,.018,-.33),Vector3(x,.018,.49+.03*cos(i)),Vector3(x+.23,.016,.55),Vector3(x+.23,.016,-.33),Color("#564b36").lightened(.033*(i%3)),Surface.METAL)
	for i in 8:
		var x:=-.69+.16*i
		_bar(Vector3(x,.04,.37),Vector3(x-.16,.13,-.03),.022,.009,WILLOW,Surface.WOOD,6)

func _litter() -> void:
	# Local origin between the front grips. The back half of the litter trails along +Z.
	for side in [-1,1]:
		var x:float=side*.355
		var points:=[Vector3(x*.94,-.018,0),Vector3(x,.007,.35),Vector3(x+.012*side,.013,1.24),Vector3(x-.013*side,.027,2.10),Vector3(x*1.03,.012,2.55)]
		for j in points.size()-1: _bar(points[j],points[j+1],.035-.002*j,.034-.002*j,WILLOW.lightened(.09*(j%2)),Surface.WOOD,9)
		for z in [.29,.38,2.13,2.22]:
			_bar(Vector3(x,0,z),Vector3(x,0,z+.023),.038,.037,CORD,Surface.CLOTH,9)
		_bar(Vector3(x,.015,2.455),Vector3(x*1.03,.013,2.525),.037,.036,WOOL.lightened(.06),Surface.CLOTH,9)
	for z in [.40,2.12]:
		_bar(Vector3(-.388,-.019,z),Vector3(.388,-.019,z),.026,.032,OAK,Surface.WOOD,8)
	# Elna's coat, including the rolled sleeves passed over the two straight hedge poles.
	for j in 10:
		for i in 8:
			var pts:=PackedVector3Array()
			for ij:Vector2i in [Vector2i(i,j),Vector2i(i,j+1),Vector2i(i+1,j+1),Vector2i(i+1,j)]:
				var u:float=ij.x/8.0; var v:float=ij.y/10.0
				var xx:float=(u-.5)*.73
				var yy:float=-.079+pow(absf(2*u-1),2)*.098+.005*cos(3*PI*v)*absf(2*u-1)
				pts.append(Vector3(xx,yy,.31+1.9*v+.016*sin(2.4*PI*u)*v))
			_face(pts[0],pts[1],pts[2],pts[3],WOOL.lightened(.012*((i+j)%3)),Surface.CLOTH)
	for side in [-1,1]:
		_bar(Vector3(side*.352,.006,.35),Vector3(side*.361,.008,.92),.045,.044,WOOL,Surface.CLOTH,10)
		for z in [.48,.59,.70,.81,1.84,1.95]:
			_bar(Vector3(side*.347,.026,z),Vector3(side*.336,.030,z+.054),.009,.007,SEAM,Surface.CLOTH,6)
	# A turned edge exposes Elna’s warmer lining, fraying at the split cuff.
	for i in 5:
		var x:float=(i-2)*.125
		_face(Vector3(x-.065,-.052,2.02),Vector3(x+.065,-.052,2.02),Vector3(x+.06,-.088,2.27),Vector3(x-.056,-.094,2.29),SEAM,Surface.CLOTH)
	_pillow(Vector3(0,-.043,.48),.24,.16,.096,Color("#ae997a"))
	for side in [-1,1]:
		# The coat's notched collar remains beside the folded head support.
		_face(Vector3(.12*side,-.03,.41),Vector3(.29*side,.012,.38),Vector3(.23*side,-.006,.84),Vector3(.16*side,-.036,.64),SEAM.darkened(.13),Surface.CLOTH)
	for i in 4:
		_bar(Vector3(.043,-.072,.88+i*.22),Vector3(.043,-.065,.88+i*.22),.014,.014,IRON,Surface.METAL,8)

func _wreck() -> void:
	# A torn sack caught on a broken axle leaves a visible trail of pale meal.
	_bar(Vector3(-.55,.06,0),Vector3(.42,.17,-.23),.069,.037,EDGE,Surface.WOOD)
	_sack(Vector3(.19,.038,-.16),-.35,Vector3(.22,.25,.26),LINEN.darkened(.12))
	for i in 17:
		var t:=i/16.
		var c:=Vector3(.26-.92*t,.021,-.18+.38*t+.063*sin(i*4.17))
		var radius:float=.12*(1.-.6*t)
		_face(c+Vector3(-radius,0,-radius*.3),c+Vector3(-radius*.65,0,radius*.33),c+Vector3(radius,.002,radius*.6),c+Vector3(radius*.76,0,-radius*.65),LINEN.lightened(.12),Surface.CLOTH)
	# The sleeve remnant has the Vargan yellow shoulder braid and a torn, uneven end.
	for j in 4:
		var x:float=-.41+.04*j
		_face(Vector3(x,.12,.02),Vector3(x+.04,.12,.02),Vector3(x+.09,.017,.27),Vector3(x+.03,.015,.27+.026*(j%2)),Color("#b39748"),Surface.CLOTH)

func _bed(x: float,z: float) -> void:
	for side in [-1,1]:
		for end in [-1,1]:
			var pos:=Vector3(x+.43*side,.0,z+.94*end)
			_bar(pos,pos+Vector3.UP*.71,.05,.039,OAK,Surface.WOOD,8)
		_board(Vector3(x+.42*side,.38,z-.99),Vector3(x+.42*side,.38,z+.99),.064,.12,OAK)
	for i in 7:
		var zz:=z-.86+i*.29
		_board(Vector3(x-.405,.40,zz),Vector3(x+.405,.40,zz),.14,.04,EDGE)
	for j in 10:
		for i in 6:
			var pts:=PackedVector3Array()
			for ij:Vector2i in [Vector2i(i,j),Vector2i(i,j+1),Vector2i(i+1,j+1),Vector2i(i+1,j)]:
				var u:float=ij.x/6.;var v:float=ij.y/10.
				pts.append(Vector3(x+(u-.5)*.81,.48+.042*sin(PI*u)*sin(PI*v)+.006*cos(v*6)*abs(2*u-1),z+(v-.5)*1.94))
			_face(pts[0],pts[1],pts[2],pts[3],LINEN.darkened(.015*((i+j)%2)),Surface.CLOTH)
	_pillow(Vector3(x,.5,z-.70),.33,.19,.095,LINEN.lightened(.10))
	for side in [-1,1]:
		for j in 8:
			var zz:=z-.97+j*.24
			_face(Vector3(x+.405*side,.48,zz),Vector3(x+.405*side,.48,zz+.24),Vector3(x+.375*side,.402,zz+.24),Vector3(x+.375*side,.402,zz),LINEN.darkened(.1),Surface.CLOTH)
	# Folded heel blanket and its woven selvedge at the foot of each narrow bed.
	for i in 5:
		var xx:=x-.41+i*.164
		_face(Vector3(xx,.525,z+.53),Vector3(xx,.53,z+.90),Vector3(xx+.165,.52,z+.90),Vector3(xx+.165,.526,z+.53),WOOL,Surface.CLOTH)
		_face(Vector3(xx,.526,z+.79),Vector3(xx,.528,z+.82),Vector3(xx+.165,.526,z+.82),Vector3(xx+.165,.525,z+.79),SEAM,Surface.CLOTH)
	for side in [-1,1]:
		_face(Vector3(x+side*.40,.52,z+.52),Vector3(x+side*.40,.52,z+.90),Vector3(x+side*.418,.32,z+.88),Vector3(x+side*.42,.30,z+.54),WOOL,Surface.CLOTH)

func _pillow(c: Vector3,half_x: float,half_z: float,rise: float,col: Color) -> void:
	for j in 6:
		for i in 10:
			var points:=PackedVector3Array()
			for ij:Vector2i in [Vector2i(i,j),Vector2i(i,j+1),Vector2i(i+1,j+1),Vector2i(i+1,j)]:
				var u:=ij.x/5.-1.
				var v:=ij.y/3.-1.
				var fold:=1.+.06*cos(u*5.7)*absf(v)
				var puff:=pow(maxf(0.,(1.-u*u)*(1.-v*v)),.46)
				points.append(c+Vector3(u*half_x*(1.-.105*v*v),.015+rise*puff,v*half_z*fold))
			_face(points[0],points[1],points[2],points[3],col,Surface.CLOTH)

func _ward() -> void:
	_bed(-.66,-.44)
	_bed(.60,-.67)
	# A portable privacy screen makes the patient accessible to Mira from the side.
	# The corridor and Nera's threshold sit on the far side of the screen.
	for i in 3:
		var a:=Vector3(1.12+.055*(i%2),.39,-1.64+.70*i)
		var b:=Vector3(1.12+.055*((i+1)%2),.39,-.94+.70*i)
		for v in [a,b]: _bar(v-Vector3.UP*.39,v+Vector3.UP*1.21,.027,.022,OAK,Surface.WOOD,8)
		for k in 5:
			var t0:=k/5.;var t1:=(k+1)/5.
			var p:=a.lerp(b,t0)+Vector3.RIGHT*.025*sin(t0*TAU)
			var q:=a.lerp(b,t1)+Vector3.RIGHT*.025*sin(t1*TAU)
			_face(p,p+Vector3.UP*1.11,q+Vector3.UP*1.11,q,Color("#948a70"),Surface.CLOTH)
	# Stove is a riveted wash-boiler on three stub feet, with a short black iron flue.
	var c:=Vector3(-1.39,0,-1.29)
	for i in 3:
		var a:=TAU*i/3
		var foot:=c+Vector3(cos(a)*.19,0,sin(a)*.19)
		_bar(foot,foot+Vector3.UP*.16,.042,.036,IRON,Surface.METAL)
	_bar(c+Vector3.UP*.13,c+Vector3.UP*.24,.23,.28,COAL,Surface.METAL,14)
	_bar(c+Vector3.UP*.24,c+Vector3.UP*.75,.28,.245,IRON.darkened(.13),Surface.METAL,14)
	_bar(c+Vector3.UP*.75,c+Vector3.UP*.79,.265,.265,COAL,Surface.METAL,14)
	_bar(c+Vector3(-.09,.79,-.04),c+Vector3(-.09,1.52,-.04),.059,.054,COAL,Surface.METAL,10)
	_bar(c+Vector3(-.09,1.52,-.04),c+Vector3(-.09,1.63,-.21),.056,.053,COAL,Surface.METAL,10)
	for i in 4:
		_board(c+Vector3(-.13,.27+i*.041,.239),c+Vector3(.093,.27+i*.041,.239),.018,.009,Color("#954e2c"),Surface.METAL)
	var table:=Vector3(-1.55,0,-.38)
	for side in [-1,1]:
		for end in [-1,1]:
			var leg:=table+Vector3(.28*side,0,.21*end)
			_bar(leg,leg+Vector3.UP*.62,.031,.029,OAK,Surface.WOOD)
	for i in 4:
		var x:float=(i-1.5)*.168
		_board(table+Vector3(x,.64,-.27),table+Vector3(x,.64,.27),.164,.044,EDGE)
	for i in 4:
		_board(table+Vector3(-.13,.69+i*.032,-.11),table+Vector3(-.11,.69+i*.032,.13),.30,.034,LINEN.lightened(.015*i),Surface.CLOTH)
	_bar(table+Vector3(.18,.67,.01),table+Vector3(.18,.78,.01),.068,.084,Color("#966b46"),Surface.METAL,10)
	_loop(table+Vector3(.18,.78,.01),Vector3.UP,.076,.009,EDGE,Surface.METAL,12)
