extends Node3D

const REAL_MODEL_PATH := "res://assets/characters/real_model/body.glb"

var model_root: Node3D


func _ready() -> void:
	if not FileAccess.file_exists(REAL_MODEL_PATH):
		push_warning("Real model GLB not found at %s. RealBody sockets are available, but no mesh was loaded." % REAL_MODEL_PATH)
		return
	var scene := load(REAL_MODEL_PATH)
	if scene is PackedScene:
		model_root = scene.instantiate()
		model_root.name = "ModelRoot"
		add_child(model_root)
	else:
		push_warning("Real model GLB not found at %s. RealBody sockets are available, but no mesh was loaded." % REAL_MODEL_PATH)


func has_model() -> bool:
	return model_root != null
