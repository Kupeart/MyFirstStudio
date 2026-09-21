class_name KadorRegel
extends Kador
## כדור רגל (Soccer Ball) - יש shape keys של לחיצה ומתיחה.

const GLB := "res://assets/models/Accesories/SoccerBall.glb"
const TEXTURE := preload("res://assets/generated/soccer_ball_texture.png")


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
	return "כדור רגל"


func get_ball_kind() -> StringName:
	return &"soccer"


## קוטר ברירת המחדל של כדור רגל - רבע מטר (כדור רגל אמיתי).
func get_default_diameter() -> float:
	return 0.25
