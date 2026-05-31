extends Node3D

const ACTIONS := ["idle", "look_at_user", "wave", "sit_chair", "stand_up", "hold_cup"]
const EXPRESSIONS := ["neutral", "smile", "surprised"]
const PROPS := ["none", "cup"]
const GAZES := ["none", "look_at_user"]
const CAMERAS := ["front_medium", "front_full", "close_face"]

const INBOX_PATH := "res://runtime/inbox/command.json"
const OUTBOX_PATH := "res://runtime/outbox/state.json"
const SCREENSHOT_DIR := "res://outputs/screenshots"
const LOG_PATH := "res://outputs/logs/runtime.jsonl"

@onready var body: Node3D = $PlaceholderBody
@onready var body_mesh: MeshInstance3D = $PlaceholderBody/BodyMesh
@onready var head_mesh: MeshInstance3D = $PlaceholderBody/HeadMesh
@onready var left_arm: MeshInstance3D = $PlaceholderBody/LeftArmMesh
@onready var right_arm: MeshInstance3D = $PlaceholderBody/RightArmMesh
@onready var left_leg: MeshInstance3D = $PlaceholderBody/LeftLegMesh
@onready var right_leg: MeshInstance3D = $PlaceholderBody/RightLegMesh
@onready var right_hand_socket: Marker3D = $PlaceholderBody/RightHandSocket
@onready var cup: MeshInstance3D = $TestRoom/Cup
@onready var user_anchor: Marker3D = $TestRoom/UserAnchor
@onready var front_medium_camera: Camera3D = $Cameras/FrontMedium
@onready var front_full_camera: Camera3D = $Cameras/FrontFull
@onready var close_face_camera: Camera3D = $Cameras/CloseFace

var is_busy := false
var last_command_hash := 0
var current_state := {
	"pose": "standing",
	"action": "idle",
	"expression": "neutral",
	"holding": "none",
	"gaze": "none",
	"camera": "front_medium",
	"is_busy": false,
	"last_action_status": "success"
}

var body_start_transform: Transform3D
var head_start_transform: Transform3D
var left_arm_start_transform: Transform3D
var right_arm_start_transform: Transform3D
var left_leg_start_transform: Transform3D
var right_leg_start_transform: Transform3D
var cup_table_transform: Transform3D
var neutral_head_material: Material
var smile_head_material: StandardMaterial3D
var surprised_head_material: StandardMaterial3D


func _ready() -> void:
	body_start_transform = body.transform
	head_start_transform = head_mesh.transform
	left_arm_start_transform = left_arm.transform
	right_arm_start_transform = right_arm.transform
	left_leg_start_transform = left_leg.transform
	right_leg_start_transform = right_leg.transform
	cup_table_transform = cup.transform
	neutral_head_material = head_mesh.get_active_material(0)
	smile_head_material = _make_material(Color(0.95, 0.76, 0.58, 1.0))
	surprised_head_material = _make_material(Color(0.95, 0.86, 0.62, 1.0))
	_configure_camera_presets()
	_ensure_runtime_dirs()
	_write_state_atomic("startup", true, "", [])
	print("AI Body Runtime ready. Watching ", INBOX_PATH)


func _process(_delta: float) -> void:
	_poll_command_file()


func _poll_command_file() -> void:
	if is_busy or not FileAccess.file_exists(INBOX_PATH):
		return
	var text := FileAccess.get_file_as_string(INBOX_PATH)
	var command_hash := text.hash()
	if command_hash == last_command_hash:
		return
	last_command_hash = command_hash
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_handle_invalid_command("unknown", ["invalid_json"])
		return
	await _execute_command(parsed)


func _execute_command(command: Dictionary) -> void:
	if is_busy:
		_write_busy_state(str(command.get("id", "unknown")))
		return
	is_busy = true
	current_state["is_busy"] = true

	var id := str(command.get("id", ""))
	var errors: Array[String] = []
	if id.is_empty():
		id = "unknown"
		errors.append("missing_id")

	var intent = command.get("intent", {})
	if typeof(intent) != TYPE_DICTIONARY:
		intent = {}
		errors.append("missing_intent")

	var normalized := _normalize_intent(intent, errors)
	await _apply_action(normalized["action"])
	_apply_expression(normalized["expression"])
	_apply_prop(normalized["prop"])
	_apply_gaze(normalized["gaze"])
	_apply_camera(normalized["camera"])

	var screenshot_path := ""
	if normalized["screenshot"]:
		screenshot_path = await _capture_screenshot(id, errors)

	current_state["action"] = normalized["action"]
	current_state["expression"] = normalized["expression"]
	current_state["holding"] = "cup" if normalized["prop"] == "cup" or normalized["action"] == "hold_cup" else "none"
	current_state["gaze"] = "user" if normalized["gaze"] == "look_at_user" or normalized["action"] == "look_at_user" else "none"
	current_state["camera"] = normalized["camera"]
	current_state["is_busy"] = false
	current_state["last_action_status"] = "success" if errors.is_empty() else "invalid_intent"
	is_busy = false

	_write_state_atomic(id, errors.is_empty(), screenshot_path, errors)


func _normalize_intent(intent: Dictionary, errors: Array[String]) -> Dictionary:
	var action := _normalize_enum(intent, "action", ACTIONS, "idle", errors)
	var expression := _normalize_enum(intent, "expression", EXPRESSIONS, "neutral", errors)
	var prop := _normalize_enum(intent, "prop", PROPS, "none", errors)
	var gaze := _normalize_enum(intent, "gaze", GAZES, "none", errors)
	var camera := _normalize_enum(intent, "camera", CAMERAS, "front_medium", errors)
	var screenshot = intent.get("screenshot", false)
	if typeof(screenshot) != TYPE_BOOL:
		screenshot = false
		errors.append("invalid_screenshot")
	return {
		"action": action,
		"expression": expression,
		"prop": prop,
		"gaze": gaze,
		"camera": camera,
		"screenshot": screenshot
	}


func _normalize_enum(intent: Dictionary, key: String, allowed: Array, fallback: String, errors: Array[String]) -> String:
	var value := str(intent.get(key, fallback))
	if not allowed.has(value):
		errors.append("invalid_" + key)
		return fallback
	return value


func _apply_action(action: String) -> void:
	match action:
		"idle":
			_reset_body_pose()
			current_state["pose"] = "standing"
		"look_at_user":
			_reset_body_pose()
			_head_look_at_user()
			current_state["pose"] = "looking_at_user"
		"wave":
			_reset_body_pose()
			await _wave()
			current_state["pose"] = "waving"
		"sit_chair":
			_sit_chair()
			current_state["pose"] = "sitting"
			await get_tree().create_timer(0.4).timeout
		"stand_up":
			_reset_body_pose()
			current_state["pose"] = "standing"
			await get_tree().create_timer(0.25).timeout
		"hold_cup":
			_reset_body_pose()
			_attach_cup_to_hand()
			current_state["pose"] = "holding_cup"
			await get_tree().create_timer(0.25).timeout


func _reset_body_pose() -> void:
	body.transform = body_start_transform
	head_mesh.transform = head_start_transform
	left_arm.transform = left_arm_start_transform
	right_arm.transform = right_arm_start_transform
	left_leg.transform = left_leg_start_transform
	right_leg.transform = right_leg_start_transform


func _wave() -> void:
	for i in range(3):
		right_arm.rotation_degrees = Vector3(0, 0, -95)
		right_arm.position = Vector3(0.55, 1.72, 0)
		await get_tree().create_timer(0.16).timeout
		right_arm.rotation_degrees = Vector3(0, 0, -55)
		right_arm.position = Vector3(0.55, 1.72, 0)
		await get_tree().create_timer(0.16).timeout


func _sit_chair() -> void:
	body.position = Vector3(-1.35, -0.32, 0.38)
	body.rotation_degrees = Vector3(0, 180, 0)
	left_leg.rotation_degrees = Vector3(-70, 0, 0)
	right_leg.rotation_degrees = Vector3(-70, 0, 0)
	left_leg.position = Vector3(-0.2, 0.95, -0.25)
	right_leg.position = Vector3(0.2, 0.95, -0.25)


func _apply_expression(expression: String) -> void:
	match expression:
		"neutral":
			head_mesh.set_surface_override_material(0, neutral_head_material)
			head_mesh.scale = Vector3.ONE
		"smile":
			head_mesh.set_surface_override_material(0, smile_head_material)
			head_mesh.scale = Vector3(1.03, 0.98, 1.03)
		"surprised":
			head_mesh.set_surface_override_material(0, surprised_head_material)
			head_mesh.scale = Vector3(1.05, 1.08, 1.05)


func _apply_prop(prop: String) -> void:
	if prop == "cup":
		_attach_cup_to_hand()
	else:
		_restore_cup_to_table()


func _attach_cup_to_hand() -> void:
	if cup.get_parent() != right_hand_socket:
		cup.reparent(right_hand_socket, false)
	cup.transform = Transform3D(Basis(), Vector3(0, -0.08, 0))


func _restore_cup_to_table() -> void:
	if cup.get_parent() != $TestRoom:
		cup.reparent($TestRoom, false)
	cup.transform = cup_table_transform


func _apply_gaze(gaze: String) -> void:
	if gaze == "look_at_user":
		_head_look_at_user()
	else:
		head_mesh.transform = head_start_transform


func _head_look_at_user() -> void:
	var target := user_anchor.global_position
	head_mesh.look_at(target, Vector3.UP, true)


func _apply_camera(camera: String) -> void:
	front_medium_camera.current = camera == "front_medium"
	front_full_camera.current = camera == "front_full"
	close_face_camera.current = camera == "close_face"


func _configure_camera_presets() -> void:
	_set_camera_view(front_medium_camera, Vector3(0, 1.65, 5.9), Vector3(0, 1.35, 0), 48.0)
	_set_camera_view(front_full_camera, Vector3(0, 1.85, 7.4), Vector3(0, 1.15, 0), 52.0)
	_set_camera_view(close_face_camera, Vector3(0, 2.2, 3.1), Vector3(0, 2.05, 0), 34.0)
	front_medium_camera.current = true


func _set_camera_view(camera: Camera3D, position: Vector3, target: Vector3, fov: float) -> void:
	camera.global_position = position
	camera.look_at(target, Vector3.UP)
	camera.fov = fov


func _capture_screenshot(id: String, errors: Array[String]) -> String:
	await get_tree().process_frame
	var texture := get_viewport().get_texture()
	var image: Image
	if texture == null:
		image = _make_headless_screenshot()
	else:
		image = texture.get_image()
		if image == null:
			image = _make_headless_screenshot()
	var final_rel := "outputs/screenshots/%s.png" % id
	var temp_abs := ProjectSettings.globalize_path("res://outputs/screenshots/%s.tmp.png" % id)
	var final_abs := ProjectSettings.globalize_path("res://" + final_rel)
	var save_err := image.save_png(temp_abs)
	if save_err != OK:
		errors.append("screenshot_save_failed")
		return ""
	_rename_absolute(temp_abs, final_abs)
	return final_rel


func _write_state_atomic(id: String, ok: bool, screenshot_path: String, errors: Array) -> void:
	var response := {
		"id": id,
		"ok": ok,
		"state": current_state.duplicate(true),
		"screenshot_path": screenshot_path,
		"errors": errors
	}
	var text := JSON.stringify(response, "\t")
	var temp_abs := ProjectSettings.globalize_path("res://runtime/outbox/state.tmp.json")
	var final_abs := ProjectSettings.globalize_path(OUTBOX_PATH)
	var file := FileAccess.open(temp_abs, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	_rename_absolute(temp_abs, final_abs)
	_append_log(response)


func _write_busy_state(id: String) -> void:
	current_state["is_busy"] = true
	current_state["last_action_status"] = "busy"
	_write_state_atomic(id, false, "", ["runtime_busy"])


func _handle_invalid_command(id: String, errors: Array[String]) -> void:
	current_state["is_busy"] = false
	current_state["last_action_status"] = "invalid_intent"
	_write_state_atomic(id, false, "", errors)


func _append_log(response: Dictionary) -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	else:
		file.seek_end()
	var entry := {
		"time": Time.get_datetime_string_from_system(false, true),
		"response": response
	}
	file.store_line(JSON.stringify(entry))
	file.close()


func _ensure_runtime_dirs() -> void:
	for path in [
		"res://runtime/inbox",
		"res://runtime/outbox",
		"res://outputs/screenshots",
		"res://outputs/logs"
	]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _rename_absolute(from_path: String, to_path: String) -> void:
	if FileAccess.file_exists(to_path):
		DirAccess.remove_absolute(to_path)
	var err := DirAccess.rename_absolute(from_path, to_path)
	if err != OK:
		push_error("Failed to rename %s to %s: %s" % [from_path, to_path, err])


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	return material


func _make_headless_screenshot() -> Image:
	var image := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.16, 0.2, 0.24, 1.0))
	return image
