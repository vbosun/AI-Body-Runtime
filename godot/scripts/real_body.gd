extends Node3D

const REAL_MODEL_PATH := "res://assets/characters/real_model/body.glb"
const TEXTURE_DIR := "res://assets/characters/real_model/textures"
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
	"idle": ["idle", "Idle"],
	"wave": ["wave", "Wave", "waving", "Waving"],
	"sit_chair": ["sit_chair", "sit_down", "Sit", "SitDown", "Sitting"],
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
		_apply_material_textures(model_root)
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


func play_action_animation(action_name: String) -> bool:
	var animation_name := get_action_animation_name(action_name)
	if animation_name.is_empty():
		return false
	animation_player.play(animation_name)
	return true


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
