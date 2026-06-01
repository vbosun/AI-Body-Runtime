extends Node3D

const REAL_MODEL_PATH := "res://assets/characters/real_model/body.glb"
const TEXTURE_DIR := "res://assets/characters/real_model/textures"
const BASIC_ANIMATION_LIBRARY_PATH := "res://assets/generated/real_model/basic_animation_library.tres"
const ANIMATION_DEBUG_PATH := "res://outputs/logs/animation_debug.json"
const SKELETON_DEBUG_PATH := "res://outputs/logs/skeleton_debug.json"
const BODY_MODES := ["placeholder", "real_model"]
const BASE_COLOR_TEXTURES := {
	"face": "Scarlet_Face_D.png",
	"ears": "Scarlet_Face_D.png",
	"torso": "Scarlet_Torso_D.png",
	"arms": "Scarlet_Arms_D.png",
	"legs": "Scarlet_Legs_D.png",
	"lips": "Scarlet_Mouth_D.png",
	"mouth": "Scarlet_Mouth_D.png",
	"teeth": "Scarlet_Mouth_D.png",
	"hair": "Hair_D.png",
	"eyebrows": "Brows_O.png",
	"eyelashes": "G8FBaseEyelashes_1006.jpg",
	"pupils": "Scarlet_Eyes_D.jpg",
	"irises": "Scarlet_Eyes_D.jpg",
	"sclera": "Scarlet_Eyes_D.jpg",
	"cornea": "Scarlet_Eyes_D.jpg",
	"eyemoisture": "Scarlet_Eyes_D.jpg",
	"eyesocket": "Scarlet_Eyes_D.jpg"
}
const ACTION_ANIMATION_CANDIDATES := {
	"idle": ["Idle", "idle"],
	"run": ["Run", "run"],
	"jump": ["Jump", "jump"],
	"interact": ["Interact", "interact"],
	"wave": ["wave", "Wave", "waving", "Waving"],
	"sit_chair": ["sit_stand", "sit_chair", "sit_down", "Sit", "SitDown", "Sitting"],
	"stand_up": ["stand_up", "StandUp", "standing_up"],
	"hold_cup": ["hold_cup", "HoldCup"]
}

var model_root: Node3D
var animation_player: AnimationPlayer
var texture_cache := {}


func _ready() -> void:
	if _resolve_body_mode() != "real_model":
		return
	if not FileAccess.file_exists(REAL_MODEL_PATH):
		push_warning("Real model GLB not found at %s. RealBody sockets are available, but no mesh was loaded." % REAL_MODEL_PATH)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_file(REAL_MODEL_PATH, state)
	if err != OK:
		push_warning("Failed to load real model GLB at %s. Error: %s" % [REAL_MODEL_PATH, err])
		return
	var generated_scene := document.generate_scene(state)
	if generated_scene is Node3D:
		model_root = generated_scene
		model_root.name = "ModelRoot"
		add_child(model_root)
		animation_player = _find_animation_player(model_root)
		_ensure_animation_player()
		_load_basic_animation_library()
		_apply_material_textures(model_root)
		_write_animation_debug()
		_write_skeleton_debug()
	else:
		push_warning("Real model GLB at %s did not generate a Node3D scene." % REAL_MODEL_PATH)


func has_model() -> bool:
	return model_root != null


func get_animation_names() -> Array[String]:
	var names: Array[String] = []
	if animation_player == null:
		return names
	for animation_name in animation_player.get_animation_list():
		names.append(str(animation_name))
	return names


func get_skeleton_paths() -> Array[String]:
	var paths: Array[String] = []
	for skeleton in _get_skeletons():
		paths.append(str(skeleton.get_path()))
	return paths


func get_primary_skeleton() -> Skeleton3D:
	var skeletons := _get_skeletons()
	if skeletons.is_empty():
		return null
	return skeletons[0]


func get_bone_names() -> Array[String]:
	var skeleton := get_primary_skeleton()
	if skeleton == null:
		return []
	return _get_bone_names_for_skeleton(skeleton)


func get_bone_count() -> int:
	var skeleton := get_primary_skeleton()
	if skeleton == null:
		return 0
	return skeleton.get_bone_count()


func has_animation(action_name: String) -> bool:
	return not get_action_animation_name(action_name).is_empty()


func get_action_animation_info(action_name: String) -> Dictionary:
	var animation_name := get_action_animation_name(action_name)
	if animation_name.is_empty() or animation_player == null:
		return {
			"exists": false,
			"animation_name": "none",
			"length": 0.0
		}
	var animation := animation_player.get_animation(animation_name)
	var length := 0.0
	if animation != null:
		length = animation.length
	return {
		"exists": true,
		"animation_name": animation_name,
		"length": length
	}


func get_action_animation_name(action_name: String) -> String:
	if animation_player == null:
		return ""
	for animation_name in ACTION_ANIMATION_CANDIDATES.get(action_name, [action_name]):
		if animation_player.has_animation(animation_name):
			return animation_name
	return ""


func play_action_animation(action_name: String) -> Dictionary:
	var info := get_action_animation_info(action_name)
	if not bool(info["exists"]):
		info["played"] = false
		return info
	animation_player.play(str(info["animation_name"]))
	info["played"] = true
	return info


func _resolve_body_mode() -> String:
	var env_mode := OS.get_environment("AI_BODY_RUNTIME_BODY_MODE")
	if BODY_MODES.has(env_mode):
		return env_mode
	var configured_mode := str(ProjectSettings.get_setting("ai_body_runtime/body_mode", "placeholder"))
	if BODY_MODES.has(configured_mode):
		return configured_mode
	return "placeholder"


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _ensure_animation_player() -> void:
	if animation_player != null:
		return
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)


func _load_basic_animation_library() -> void:
	if animation_player == null:
		return
	if not ResourceLoader.exists(BASIC_ANIMATION_LIBRARY_PATH):
		return
	var library := load(BASIC_ANIMATION_LIBRARY_PATH)
	if library is AnimationLibrary:
		if animation_player.has_animation_library(""):
			var target_library := animation_player.get_animation_library("")
			for animation_name in library.get_animation_list():
				target_library.add_animation(animation_name, library.get_animation(animation_name))
		else:
			var err := animation_player.add_animation_library("", library)
			if err != OK:
				push_warning("Failed to attach basic animation library %s. Error: %s" % [BASIC_ANIMATION_LIBRARY_PATH, err])


func _write_animation_debug() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://outputs/logs"))
	var file := FileAccess.open(ANIMATION_DEBUG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to write animation debug log at %s." % ANIMATION_DEBUG_PATH)
		return
	file.store_string(JSON.stringify({
		"time": Time.get_datetime_string_from_system(false, true),
		"animation_library": BASIC_ANIMATION_LIBRARY_PATH,
		"available_animations": get_animation_names(),
		"action_candidates": ACTION_ANIMATION_CANDIDATES
	}, "\t"))
	file.close()


func _write_skeleton_debug() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://outputs/logs"))
	var file := FileAccess.open(SKELETON_DEBUG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to write skeleton debug log at %s." % SKELETON_DEBUG_PATH)
		return
	file.store_string(JSON.stringify(_build_skeleton_debug_report(), "\t"))
	file.close()


func _build_skeleton_debug_report() -> Dictionary:
	var diagnosis: Array[String] = []
	var skeleton_entries := _build_skeleton_entries()
	var animation_tracks := _build_animation_track_entries(diagnosis)
	if skeleton_entries.is_empty():
		diagnosis.append("real_model has no Skeleton3D nodes; bone retargeting cannot start yet")
	return {
		"time": Time.get_datetime_string_from_system(false, true),
		"body_mode": "real_model",
		"skeletons": skeleton_entries,
		"available_animations": get_animation_names(),
		"animation_tracks": animation_tracks,
		"diagnosis": diagnosis
	}


func _build_skeleton_entries() -> Array:
	var entries := []
	for skeleton in _get_skeletons():
		entries.append({
			"path": str(skeleton.get_path()),
			"bone_count": skeleton.get_bone_count(),
			"bones": _get_bone_names_for_skeleton(skeleton)
		})
	return entries


func _build_animation_track_entries(diagnosis: Array[String]) -> Dictionary:
	var entries := {}
	if animation_player == null:
		return entries
	var skeleton_path_texts := []
	for skeleton in _get_skeletons():
		skeleton_path_texts.append(str(skeleton.get_path()))
		skeleton_path_texts.append(str(animation_player.get_path_to(skeleton)))
	for animation_name in get_animation_names():
		var animation := animation_player.get_animation(animation_name)
		if animation == null:
			continue
		var tracks := []
		var has_root_track := false
		var has_skeleton_track := false
		for track_index in range(animation.get_track_count()):
			var track_path := animation.track_get_path(track_index)
			var path_text := str(track_path)
			var track_type := animation.track_get_type(track_index)
			var key_count := animation.track_get_key_count(track_index)
			tracks.append({
				"track_index": track_index,
				"type": _track_type_name(track_type),
				"type_id": track_type,
				"path": path_text,
				"path_text": path_text,
				"key_count": key_count
			})
			if _is_root_transform_track(path_text):
				has_root_track = true
			if _is_skeleton_track(path_text, skeleton_path_texts):
				has_skeleton_track = true
		entries[animation_name] = tracks
		if has_skeleton_track:
			diagnosis.append("animation %s has skeleton/bone tracks" % animation_name)
		elif has_root_track:
			diagnosis.append("animation %s affects ModelRoot/root transform only, not skeleton bones" % animation_name)
		elif tracks.is_empty():
			diagnosis.append("animation %s has no tracks" % animation_name)
		else:
			diagnosis.append("animation %s has non-skeleton tracks" % animation_name)
	return entries


func _get_skeletons() -> Array[Skeleton3D]:
	var skeletons: Array[Skeleton3D] = []
	if model_root == null:
		return skeletons
	_collect_skeletons(model_root, skeletons)
	return skeletons


func _collect_skeletons(node: Node, skeletons: Array[Skeleton3D]) -> void:
	if node is Skeleton3D:
		skeletons.append(node)
	for child in node.get_children():
		_collect_skeletons(child, skeletons)


func _get_bone_names_for_skeleton(skeleton: Skeleton3D) -> Array[String]:
	var names: Array[String] = []
	for bone_index in range(skeleton.get_bone_count()):
		names.append(skeleton.get_bone_name(bone_index))
	return names


func _is_root_transform_track(path_text: String) -> bool:
	var normalized := path_text.to_lower()
	return normalized.begins_with("modelroot:") or normalized == "." or normalized.begins_with(".:")


func _is_skeleton_track(path_text: String, skeleton_path_texts: Array) -> bool:
	var normalized := path_text.to_lower()
	if normalized.contains("skeleton") or normalized.contains("bone"):
		return true
	for skeleton_path in skeleton_path_texts:
		var skeleton_text := str(skeleton_path).to_lower()
		if not skeleton_text.is_empty() and normalized.contains(skeleton_text):
			return true
	return false


func _track_type_name(track_type: int) -> String:
	match track_type:
		Animation.TYPE_VALUE:
			return "value"
		Animation.TYPE_POSITION_3D:
			return "position_3d"
		Animation.TYPE_ROTATION_3D:
			return "rotation_3d"
		Animation.TYPE_SCALE_3D:
			return "scale_3d"
		Animation.TYPE_BLEND_SHAPE:
			return "blend_shape"
		Animation.TYPE_METHOD:
			return "method"
		Animation.TYPE_BEZIER:
			return "bezier"
		Animation.TYPE_AUDIO:
			return "audio"
		Animation.TYPE_ANIMATION:
			return "animation"
	return "unknown"


func _apply_material_textures(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_mesh_material_textures(node)
	for child in node.get_children():
		_apply_material_textures(child)


func _apply_mesh_material_textures(mesh_instance: MeshInstance3D) -> void:
	var mesh := mesh_instance.mesh
	if mesh == null:
		return
	for surface_index in range(mesh.get_surface_count()):
		var source_material := mesh_instance.get_active_material(surface_index)
		var material := _material_with_base_color(source_material)
		if material != null:
			mesh_instance.set_surface_override_material(surface_index, material)


func _material_with_base_color(source_material: Material) -> StandardMaterial3D:
	if source_material == null:
		return null
	var texture := _texture_for_material_name(source_material.resource_name)
	if texture == null:
		return null
	var material: StandardMaterial3D
	if source_material is StandardMaterial3D:
		material = source_material.duplicate()
	else:
		material = StandardMaterial3D.new()
		material.albedo_color = Color.WHITE
	material.albedo_texture = texture
	material.roughness = 0.72
	return material


func _texture_for_material_name(material_name: String) -> Texture2D:
	var normalized := material_name.to_lower().replace("_", "").replace("-", "").replace(" ", "")
	for key in BASE_COLOR_TEXTURES.keys():
		if normalized.contains(key):
			return _load_texture(BASE_COLOR_TEXTURES[key])
	return null


func _load_texture(file_name: String) -> Texture2D:
	if texture_cache.has(file_name):
		return texture_cache[file_name]
	var path := "%s/%s" % [TEXTURE_DIR, file_name]
	if not FileAccess.file_exists(path):
		push_warning("Texture not found: %s" % path)
		texture_cache[file_name] = null
		return null
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err == OK:
		var texture := ImageTexture.create_from_image(image)
		texture_cache[file_name] = texture
		return texture
	push_warning("Texture failed to load: %s. Error: %s" % [path, err])
	texture_cache[file_name] = null
	return null
