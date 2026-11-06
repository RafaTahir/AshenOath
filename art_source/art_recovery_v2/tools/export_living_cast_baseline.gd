extends SceneTree
func _initialize():
 call_deferred("run")
func run():
 var output = ProjectSettings.globalize_path("res://").path_join("../../art_source/art_recovery_v2/evidence/living_cast_20261107").simplify_path()
 DirAccess.make_dir_recursive_absolute(output)
 var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/prepared_actors.json"))
 for id in ["C01","C04","C03","C02"]:
  if FileAccess.file_exists(output.path_join(id+"_baseline.glb")):
   print("LIFE_BASELINE retained ", id, " ", FileAccess.get_sha256(output.path_join(id+"_baseline.glb")))
   continue
  var path = ""
  for key in catalog:
   if ("/"+id+"_") in str(catalog[key].source):
    path = catalog[key].path
    break
  var actor = load(path).instantiate()
  var player = preload("res://scripts/character_animation_fusion.gd").attach_shared_library(actor)
  if player == null:
   push_error("Missing baseline animation player: "+id)
   quit(1)
   return
  for library_name in player.get_animation_library_list():
   var library = player.get_animation_library(library_name).duplicate(true)
   for clip in library.get_animation_list():
    if clip != "Idle":
     library.remove_animation(clip)
   player.remove_animation_library(library_name)
   player.add_animation_library(library_name, library)
  var document = GLTFDocument.new()
  var state = GLTFState.new()
  var error = document.append_from_scene(actor, state)
  if error == OK:
   error = document.write_to_filesystem(state, output.path_join(id+"_baseline.glb"))
  print("LIFE_BASELINE ",id," error=",error," clips=",player.get_animation_list())
  actor.free()
  if error != OK:
   quit(1)
   return
 quit(0)
