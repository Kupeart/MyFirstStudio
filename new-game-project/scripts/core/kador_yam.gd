class_name KadorYam
extends Kador
## כדור ים (Beach Ball) - יש shape keys של לחיצה ומתיחה.

const GLB := "res://assets/models/Accesories/BeachBall.glb"
const TEXTURE := preload("res://assets/generated/beach_ball_texture.png")


func _glb_path() -> String:
	return GLB


func _apply_material() -> void:
	if _mesh == null:
		return
	var source := _mesh.mesh.surface_get_material(0)
	if source is StandardMaterial3D:
		var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
		material.albedo_texture = TEXTURE
		_mesh.material_override = material


func get_mode_name() -> String:
	return "כדור ים"


func get_ball_kind() -> StringName:
	return &"beach"


## קוטר ברירת המחדל של כדור ים - חצי מטר (כמו כדור ים אמיתי).
func get_default_diameter() -> float:
	return 0.5
