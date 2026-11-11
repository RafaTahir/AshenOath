extends RefCounted

## Packaging consumes the pure source comparison's exact admission. The source
## helper is rerun before compilation, and every admitted byte is checked again.
const GAME := "outputs/AshenOathTheRoadBetweenCrowns/"
const ART := "art_source/art_recovery_v2/"
const HELPER := ART + "tools/face_repair_provenance.py"
const KIND := "lower_face_repair_v1"

static func resolve(repository: String, asset: String, model: String, prepared: String,
		baseline_model_sha: String = "", baseline_prepared_sha: String = "") -> Dictionary:
	var registry: Variant = _read(repository.path_join(GAME + "data/design_pack_assets.json"))
	if not registry is Dictionary or not registry.get("assets") is Dictionary:
		return _error("Missing design asset registry")
	var record: Variant = registry.assets.get(asset)
	if not record is Dictionary or not record.has("face_repair_certificate"):
		return {}
	var pointer: Variant = record.face_repair_certificate
	if not pointer is Dictionary:
		return _error("Malformed face repair certificate pointer")
	var certificate_path := _art_path(repository, pointer.get("path"))
	var certificate_sha := _digest(certificate_path)
	var admission_path := _art_path(repository, pointer.get("admission_path"))
	if certificate_sha.is_empty() or certificate_sha != pointer.get("sha256") or admission_path.is_empty():
		return _error("Face repair certificate identity differs")
	var certificate: Variant = _read(certificate_path)
	var admission: Variant = _read(admission_path)
	if not certificate is Dictionary or certificate.get("schema_version") != 1 \
			or certificate.get("certificate_kind") != KIND or certificate.get("asset") != asset \
			or certificate.get("baseline_commit") != "b4b52e4":
		return _error("Face repair certificate has a different scope")
	if not admission is Dictionary or admission.get("schema_version") != 1 \
			or admission.get("certificate_kind") != KIND or admission.get("accepted") != true \
			or admission.get("helper_sha256") != _digest(repository.path_join(HELPER)) \
			or not admission.get("assets") is Dictionary:
		return _error("Face repair source comparison is missing or stale")
	var checked: Variant = admission.assets.get(asset)
	if not checked is Dictionary or checked.get("certificate_path") != pointer.path \
			or checked.get("certificate_sha256") != certificate_sha:
		return _error("Face repair admission does not bind this certificate")
	for field: String in ["model", "baseline_model", "prepared", "life_library"]:
		if not certificate.get(field) is Dictionary:
			return _error("Face repair certificate is incomplete: " + field)
	var old_model: String = str(certificate.model.get("baseline_sha256", ""))
	var old_prepared: String = str(certificate.prepared.get("baseline_sha256", ""))
	var new_model: String = str(certificate.model.get("sha256", ""))
	var new_prepared: String = str(certificate.prepared.get("sha256", ""))
	if (not baseline_model_sha.is_empty() and old_model != baseline_model_sha) \
			or (not baseline_prepared_sha.is_empty() and old_prepared != baseline_prepared_sha):
		return _error("Face repair does not succeed the measured source")
	if model != record.get("path") or model != certificate.model.get("path") \
			or model != checked.get("model_path") or prepared != certificate.prepared.get("path") \
			or prepared != checked.get("prepared_path"):
		return _error("Face repair resource identity differs")
	var baseline_path := _art_path(repository, certificate.baseline_model.get("path"), ".glb")
	if old_model != certificate.baseline_model.get("sha256") or _digest(baseline_path) != old_model \
			or old_model != checked.get("baseline_model_sha256") or old_prepared != checked.get("baseline_prepared_sha256"):
		return _error("Face repair baseline bytes differ")
	if new_model.is_empty() or new_model != record.get("sha256") or new_model != _digest(model) \
			or new_model != checked.get("model_sha256") or new_prepared.is_empty() \
			or new_prepared != _digest(prepared) or new_prepared != checked.get("prepared_sha256") \
			or certificate.prepared.get("source_sha256") != new_model \
			or checked.get("prepared_source_sha256") != new_model \
			or certificate.prepared.get("compiler_sha256") != _digest("res://tools/build_prepared_actors.gd"):
		return _error("Face repair model or compiled scene bytes differ")
	var catalog: Variant = _read("res://data/prepared_actors.json")
	if not catalog is Dictionary:
		return _error("Face repair has no prepared source catalog")
	var matched := 0
	for item: Variant in catalog.values():
		if not item is Dictionary or item.get("source") != model:
			continue
		matched += 1
		if item.get("path") != prepared or item.get("compiled_sha256") != new_prepared \
				or item.get("source_sha256") != new_model:
			return _error("Prepared actor aliases do not bind the repaired source")
	if matched == 0:
		return _error("Face repair has no compiled actor")
	var library := "res://assets_external/characters_prepared/animations/life_" + asset + ".res"
	var library_sha := _digest(library)
	if library_sha.is_empty() or certificate.life_library.get("path") != library \
			or certificate.life_library.get("sha256") != library_sha \
			or checked.get("life_library_path") != library or checked.get("life_library_sha256") != library_sha:
		return _error("Face repair changed its retained life library")
	return {"certificate_sha256": certificate_sha, "baseline_model_sha256": old_model,
		"baseline_prepared_sha256": old_prepared, "model_sha256": new_model,
		"prepared_sha256": new_prepared, "life_library_sha256": library_sha}

static func reuse_library(repository: String, asset: String, source: String, model: String,
		prepared: String, authoring: Dictionary) -> Dictionary:
	var successor := resolve(repository, asset, model, prepared, str(authoring.get("production_sha256", "")))
	if successor.is_empty() or successor.has("error"):
		return successor
	var folder := source.get_base_dir().get_base_dir()
	var source_sha := _digest(source)
	var library := "res://assets_external/characters_prepared/animations/life_" + asset + ".res"
	for filename: String in DirAccess.get_files_at(folder):
		if not filename.begins_with("library_compile_") or filename.begins_with("library_compile_face_repair_") \
				or not filename.ends_with(".json"):
			continue
		var document: Variant = _read(folder.path_join(filename))
		if not document is Dictionary or document.get("status") != "compiled" or not document.get("libraries") is Array:
			continue
		for row: Variant in document.libraries:
			if not row is Dictionary or row.get("asset") != asset or row.get("path") != library \
					or row.get("sha256") != successor.life_library_sha256 or row.get("model") != model \
					or row.get("model_sha256") != successor.baseline_model_sha256 or row.get("source_sha256") != source_sha:
				continue
			var result: Dictionary = row.duplicate(true)
			result["reused_face_repair"] = true
			result["face_repair_certificate_sha256"] = successor.certificate_sha256
			result["current_model_sha256"] = successor.model_sha256
			result["current_prepared_sha256"] = successor.prepared_sha256
			return {"row": result}
	return _error("Face repair has no matching original life compiler receipt")

static func _art_path(repository: String, raw: Variant, extension: String = ".json") -> String:
	if not raw is String or not raw.begins_with(ART) or not raw.ends_with(extension) or "\\" in raw:
		return ""
	for segment: String in raw.split("/"):
		if segment in ["", ".", ".."]:
			return ""
	return repository.path_join(raw)

static func _read(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null

static func _digest(path: String) -> String:
	return FileAccess.get_sha256(path) if not path.is_empty() and FileAccess.file_exists(path) else ""

static func _error(message: String) -> Dictionary:
	return {"error": "Face repair provenance: " + message}
