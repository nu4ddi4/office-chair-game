class_name ChaosMissions
extends RefCounted

static func load_all() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://chaos/data/missions.json"))
	if not parsed is Array or parsed.size()!=6:
		push_error("Six office missions are required.")
		return []
	return parsed

static func point(values: Array) -> Vector3:
	return Vector3(values[0],0,values[1])
