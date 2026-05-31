extends Node3D

const REAL_MODEL_PATH := "res://assets/characters/real_model/body.glb"
const BODY_MODES := ["placeholder", "real_model"]

var model_root: Node3D
var animation_player: AnimationPlayer


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
	else:
		push_warning("Real model GLB at %s did not generate a Node3D scene." % REAL_MODEL_PATH)


func has_model() -> bool:
	return model_root != null


func has_animation(action_name: String) -> bool:
	return animation_player != null and animation_player.has_animation(action_name)


func play_action_animation(action_name: String) -> bool:
	if not has_animation(action_name):
		return false
	animation_player.play(action_name)
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
