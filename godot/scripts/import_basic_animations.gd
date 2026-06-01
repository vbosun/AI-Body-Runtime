extends SceneTree

const LOCAL_ANIMATION_DIR := "res://assets_local/animations/basic"
const OUTPUT_LIBRARY_PATH := "res://assets/generated/real_model/basic_animation_library.tres"
const OUTPUT_DEBUG_PATH := "res://outputs/logs/animation_debug.json"
const ACTION_SOURCES := {
	"idle": {
		"animation_name": "Idle",
		"file_name": "Idle.fbx",
		"length": 1.2
	},
	"run": {
		"animation_name": "Run",
		"file_name": "Run.fbx",
		"length": 0.9
	},
	"jump": {
		"animation_name": "Jump",
		"file_name": "Jump.fbx",
		"length": 0.8
	},
	"interact": {
		"animation_name": "Interact",
		"file_name": "Interact.fbx",
		"length": 1.0
	},
	"wave": {
		"animation_name": "wave",
		"file_name": "wave.bvh",
		"length": 1.4
	},
	"sit_chair": {
		"animation_name": "sit_stand",
		"file_name": "sit_stand.bvh",
		"length": 1.6
	}
}


func _initialize() -> void:
	var report := build_basic_animation_library()
	print(JSON.stringify(report, "\t"))
	quit(0 if report["generated_animations"].size() > 0 else 1)


func build_basic_animation_library() -> Dictionary:
	_ensure_output_dirs()
	var library := AnimationLibrary.new()
	var debug_entries := []
	var generated: Array[String] = []
	for action in ACTION_SOURCES.keys():
		var source: Dictionary = ACTION_SOURCES[action]
		var file_name := str(source["file_name"])
		var source_path := "%s/%s" % [LOCAL_ANIMATION_DIR, file_name]
		var exists := FileAccess.file_exists(source_path)
		var animation_name := str(source["animation_name"])
		if exists:
			var animation := _make_animation_clip(action, float(source["length"]))
			library.add_animation(animation_name, animation)
			generated.append(animation_name)
		debug_entries.append({
			"action": action,
			"animation_name": animation_name,
			"source_path": source_path,
			"source_exists": exists,
			"status": "generated_test_clip" if exists else "missing_source"
		})
	var save_error := ResourceSaver.save(library, OUTPUT_LIBRARY_PATH)
	var report := {
		"generated_at": Time.get_datetime_string_from_system(false, true),
		"source_dir": LOCAL_ANIMATION_DIR,
		"output_library": OUTPUT_LIBRARY_PATH,
		"save_error": save_error,
		"available_animations": generated,
		"generated_animations": generated,
		"sources": debug_entries,
		"note": "V0.6 creates a local AnimationLibrary integration fixture from gitignored FBX/BVH sources. It does not embed or commit third-party animation data."
	}
	_write_json(OUTPUT_DEBUG_PATH, report)
	return report


func _make_animation_clip(action: String, length: float) -> Animation:
	var animation := Animation.new()
	animation.length = length
	match action:
		"idle":
			_add_position_track(animation, "ModelRoot:position", [0.0, length], [Vector3.ZERO, Vector3(0, 0.02, 0)])
		"run":
			_add_position_track(animation, "ModelRoot:position", [0.0, length * 0.5, length], [Vector3.ZERO, Vector3(0, 0, -0.08), Vector3.ZERO])
		"jump":
			_add_position_track(animation, "ModelRoot:position", [0.0, length * 0.5, length], [Vector3.ZERO, Vector3(0, 0.16, 0), Vector3.ZERO])
		"interact":
			_add_rotation_track(animation, "ModelRoot:rotation_degrees", [0.0, length * 0.5, length], [Vector3.ZERO, Vector3(0, 0, -5), Vector3.ZERO])
		"wave":
			_add_rotation_track(animation, "ModelRoot:rotation_degrees", [0.0, length * 0.25, length * 0.5, length * 0.75, length], [Vector3.ZERO, Vector3(0, 0, -7), Vector3(0, 0, 7), Vector3(0, 0, -7), Vector3.ZERO])
		"sit_chair":
			_add_position_track(animation, "ModelRoot:position", [0.0, length * 0.5, length], [Vector3.ZERO, Vector3(0, -0.12, 0.05), Vector3.ZERO])
	return animation


func _add_position_track(animation: Animation, path: String, times: Array, values: Array) -> void:
	var track_index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, NodePath(path))
	for i in range(times.size()):
		animation.track_insert_key(track_index, float(times[i]), values[i])


func _add_rotation_track(animation: Animation, path: String, times: Array, values: Array) -> void:
	var track_index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, NodePath(path))
	for i in range(times.size()):
		animation.track_insert_key(track_index, float(times[i]), values[i])


func _ensure_output_dirs() -> void:
	for path in [
		"res://assets/generated/real_model",
		"res://outputs/logs"
	]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open %s for writing." % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
