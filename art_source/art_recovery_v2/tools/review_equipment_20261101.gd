extends SceneTree
## Native material/geometry staging, without a journey or saved game.
const Presentation = preload("res://scripts/character_presentation.gd")
const Props = preload("res://scripts/held_prop_geometry.gd")
const OUTPUT := "D:/Projects/AshenOath/art_source/art_recovery_v2/evidence/refinement_20261101/equipment/native"
var stage: Node3D
var camera: Camera3D
func _initialize() -> void:
 root.content_scale_size = Vector2i(640,640)
 run.call_deferred()
func raw_glb(path: String) -> Node3D:
 var document := GLTFDocument.new()
 var state := GLTFState.new()
 assert(document.append_from_file(path,state) == OK)
 return document.generate_scene(state)
func all_meshes(node: Node, found: Array[MeshInstance3D]) -> void:
 if node is MeshInstance3D: found.append(node)
 for child in node.get_children(): all_meshes(child,found)
func capture(id: String, prop: Node3D) -> void:
 stage.add_child(prop)
 await process_frame
 var meshes: Array[MeshInstance3D] = []
 all_meshes(prop,meshes)
 var bounds := AABB()
 var first := true
 for mesh in meshes:
  if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
  var box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
  bounds = box if first else bounds.merge(box)
  first = false
 assert(not first)
 var center := bounds.get_center()
 var span := maxf(maxf(bounds.size.x,bounds.size.y),bounds.size.z)
 camera.size = span * 1.32
 for view in ["quarter","front","rear"]:
  var direction := Vector3(1.3,1.1,2.0) if view == "quarter" else Vector3(.05,.20,3.0 if view == "front" else -3.0)
  camera.position = center + direction.normalized()*maxf(span*3.0,.5)
  camera.look_at(center)
  await process_frame
  await process_frame
  await RenderingServer.frame_post_draw
  var image := root.get_texture().get_image()
  assert(image.save_png(OUTPUT+"/"+id+"_"+view+".png") == OK)
 prop.queue_free()
 await process_frame
func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 stage = Node3D.new()
 stage.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
 root.add_child(stage)
 var world := WorldEnvironment.new()
 world.environment = Environment.new()
 world.environment.background_mode = Environment.BG_COLOR
 world.environment.background_color = Color(.055,.065,.075)
 world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 world.environment.ambient_light_color = Color(.70,.77,.82)
 world.environment.ambient_light_energy = .65
 stage.add_child(world)
 var key := DirectionalLight3D.new()
 key.rotation_degrees = Vector3(-45,-35,0)
 key.light_energy = 1.25
 stage.add_child(key)
 camera = Camera3D.new()
 camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.near = .01
 camera.far = 100
 stage.add_child(camera)
 camera.make_current()
 await capture("staff",raw_glb("D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns/assets_external/design_pack_v1/C01_ash_staff.glb"))
 await capture("arrow",raw_glb("D:/Projects/AshenOath/outputs/AshenOathTheRoadBetweenCrowns/assets/characters/kael_arrow.glb"))
 await capture("hammer",load("res://assets/characters/forge_hammer.tscn").instantiate())
 for style in ["bowl","bread","cloth","rope"]:
  var actor := Node3D.new()
  stage.add_child(actor)
  var skeleton := Skeleton3D.new()
  actor.add_child(skeleton)
  skeleton.add_bone("hand_r")
  Presentation.attach_activity_tool(actor,style)
  stage.remove_child(actor)
  await capture(style,actor)
 for kind in ["spear","shield","book","steward_book"]:
  var prop := Node3D.new()
  if kind == "spear": Presentation._add_spear(prop)
  elif kind == "shield": Presentation._add_shield(prop)
  else: Presentation._add_record_book(prop,kind == "steward_book")
  await capture(kind,prop)
 var quiver := MeshInstance3D.new()
 quiver.mesh = Props.vessel(.08,.06,.6)
 quiver.material_override = Presentation._mat(Color(.12,.07,.035),.86)
 await capture("quiver",quiver)
 var player = load("res://scripts/player_controller.gd").new()
 var sword := Node3D.new()
 assert(player._attach_modeled_sword(sword,"oathblade"))
 await capture("oathblade",sword)
 player.free()
 stage.queue_free()
 await process_frame
 print("NATIVE_EQUIPMENT_CAPTURE_COMPLETE")
 quit()
