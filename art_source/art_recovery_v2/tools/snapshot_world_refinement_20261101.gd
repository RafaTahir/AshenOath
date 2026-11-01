extends SceneTree
## Read-only semantic snapshot of authored world resources; no scene/journey.
func encode(value: Variant) -> Variant:
 if value is Vector3: return {"type":"Vector3","values":[value.x,value.y,value.z]}
 if value is Vector2: return {"type":"Vector2","values":[value.x,value.y]}
 if value is Color: return {"type":"Color","values":[value.r,value.g,value.b,value.a]}
 if value is AABB: return {"type":"AABB","position":encode(value.position),"size":encode(value.size)}
 if value is Transform3D: return {"type":"Transform3D","values":[encode(value.basis.x),encode(value.basis.y),encode(value.basis.z),encode(value.origin)]}
 if value is Array or value is PackedFloat32Array or value is PackedVector3Array or value is PackedStringArray:
  var result := []
  for item in value: result.append(encode(item))
  return result
 if value is Dictionary:
  var result := {}
  for key in value: result[str(key)] = encode(value[key])
  return result
 if value is Resource: return {"type":value.get_class(),"path":value.resource_path}
 return value
func _initialize() -> void:
 var list_path := ""
 var output_path := ""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--list="): list_path = arg.trim_prefix("--list=")
  if arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
 assert(list_path != "" and output_path != "")
 var paths: Array = JSON.parse_string(FileAccess.get_file_as_string(list_path))
 var records := []
 for path: String in paths:
  var resource := ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
  assert(resource != null,path)
  var row := {"path":path,"class":resource.get_class(),"meta":{},"source_sha256":resource.get_meta("source_sha256",{})}
  for key in resource.get_meta_list():
   if str(key) != "source_sha256": row.meta[str(key)] = encode(resource.get_meta(key))
  if resource is ArrayMesh:
   row.bounds = encode(resource.get_aabb())
   row.surfaces = []
   row.triangles = 0
   for part in resource.get_surface_count():
    var count: int = resource.surface_get_array_index_len(part)
    if count == 0: count = resource.surface_get_array_len(part)
    var triangles := count / 3 if resource.surface_get_primitive_type(part) == Mesh.PRIMITIVE_TRIANGLES else 0
    var material: Material = resource.surface_get_material(part)
    var surface := {"name":resource.surface_get_name(part),"vertices":resource.surface_get_array_len(part),"indices":resource.surface_get_array_index_len(part),"triangles":triangles,"material_class":material.get_class() if material != null else "","material_name":material.resource_name if material != null else ""}
    if material is BaseMaterial3D:
     surface.material_response = {"albedo":encode(material.albedo_color),"roughness":material.roughness,"metallic":material.metallic,"vertex_color":material.vertex_color_use_as_albedo,"emission":encode(material.emission),"emission_enabled":material.emission_enabled,"emission_energy":material.emission_energy_multiplier}
    row.surfaces.append(surface)
    row.triangles += triangles
  elif resource is ConcavePolygonShape3D:
   row.collision_faces_sha256 = var_to_bytes(resource.get_faces()).hex_encode().sha256_text()
   row.collision_vertices = resource.get_faces().size()
  records.append(row)
 var output := FileAccess.open(output_path,FileAccess.WRITE)
 assert(output != null)
 output.store_string(JSON.stringify(records,"\t"));output.close()
 print("WORLD_RESOURCE_SNAPSHOT_OK ",records.size())
 quit()
