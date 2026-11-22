extends SceneTree

# Godot 4.6.3 tokenizer-buffer version 101, decoded with the engine's own
# Variant and Zstandard routines. Temporary read-only package audit only.
func _initialize() -> void:
	var directory := "D:/Temp/AshenOath/h1_retry_pack_source_audit/root"
	var reports := []
	for relative: String in ["scripts/mobile_touch_controls.gdc","scripts/input_router.gdc","scripts/player_controller.gdc","scripts/hud/hud_input.gdc","scripts/hud/hud_lifecycle.gdc","scripts/systems/hud_coordinator.gdc","scripts/zone_runtime_coordinator.gdc"]:
		var file := directory.path_join(relative)
		var raw := FileAccess.get_file_as_bytes(file)
		assert(raw.slice(0,4).get_string_from_ascii() == "GDSC")
		assert(raw.decode_u32(4) == 101)
		var expected := raw.decode_u32(8)
		var data := raw.slice(12).decompress(expected,FileAccess.COMPRESSION_ZSTD) if expected else raw.slice(12)
		var identifier_count := data.decode_u32(0)
		var constant_count := data.decode_u32(4)
		var line_count := data.decode_u32(8)
		var token_count := data.decode_u32(12)
		var position := 16
		var identifiers: Array[String] = []
		for index in identifier_count:
			var length := data.decode_u32(position)
			position += 4
			var value := ""
			for character in length:
				value += String.chr(data.decode_u32(position) ^ 0xb6b6b6b6)
				position += 4
			identifiers.append(value)
		var constants: Array[String] = []
		for index in constant_count:
			var value: Variant = bytes_to_var(data.slice(position))
			position += var_to_bytes(value).size()
			constants.append(var_to_str(value))
		var line_map := {}
		var column_map := {}
		for index in line_count:
			line_map[int(data.decode_u32(position))] = int(data.decode_u32(position + 4))
			position += 8
		for index in line_count:
			column_map[int(data.decode_u32(position))] = int(data.decode_u32(position + 4))
			position += 8
		var line_boundaries := []
		for token_index: int in line_map:
			line_boundaries.append({"token_index":token_index,"line":line_map[token_index],"column":column_map[token_index]})
		var tokens := []
		for index in token_count:
			var code := data.decode_u32(position) if data[position] & 0x80 else int(data[position])
			position += 4 if data[position] & 0x80 else 1
			var line := data.decode_u32(position)
			position += 4
			var type := code & 0x7f
			var value: String = identifiers[code >> 8] if type in [1,2] else (constants[code >> 8] if type in [3,99] else "")
			tokens.append({"index":index,"line":line,"type":type,"value":value})
		assert(position == data.size(), "Tokenizer decode must consume the entire buffer")
		var output := file + ".tokens.json"
		FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(tokens,"\t",true)+"\n")
		reports.append({"path":relative,"compiled_sha256":FileAccess.get_sha256(file),"version":101,"tokens":token_count,
			"decoded_bytes":data.size(),"consumed_bytes":position,"tokens_json":output,"line_boundaries":line_boundaries})
	FileAccess.open(directory.path_join("token_decode.json"),FileAccess.WRITE).store_string(JSON.stringify(reports,"\t",true)+"\n")
	print("COMPILED TOKEN DECODE: PASS; seven packed scripts, all token bytes consumed")
	quit()
