extends Node3D
## סצנת תצוגה ידנית לכדורים - כדי לראות בעין את ידיות הגיזמו.
## לא חלק מהמשחק: פותחים את tests/ball_preview.tscn ולוחצים Play.
##
## משמאל: כדור ים במצב הזזה - הגיזמו במרכז הכדור, והידית הצהובה במרכז
## מזיזה את הכדור בכל הצירים.
## במרכז: כדור סליים במצב קנה מידה - עיגול טורקיז במרכז הכדור שמגדיל את
## כולו, ומעליו חץ אדום של לחיצה/מתיחה.
## מימין: כדור ברזל במצב קנה מידה - רק עיגול הקנה מידה (אין shape keys).

const YamScript := preload("res://scripts/core/kador_yam.gd")
const SlimeScript := preload("res://scripts/core/kador_slime.gd")
const BarzelScript := preload("res://scripts/core/kador_barzel.gd")
const GizmoScript := preload("res://scripts/core/move_gizmo.gd")


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	light.shadow_enabled = true
	add_child(light)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 6.0, 18.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.7, 0.0))
	camera.make_current()

	var beach: Node3D = YamScript.new()
	beach.position = Vector3(-6.0, 0.0, 0.0)
	add_child(beach)

	var slime: Node3D = SlimeScript.new()
	slime.position = Vector3(0.0, 0.0, 0.0)
	add_child(slime)

	var barzel: Node3D = BarzelScript.new()
	barzel.position = Vector3(6.0, 0.0, 0.0)
	add_child(barzel)

	_attach_gizmo(camera, beach, GizmoScript.GizmoMode.TRANSLATE)
	_attach_gizmo(camera, slime, GizmoScript.GizmoMode.SCALE)
	_attach_gizmo(camera, barzel, GizmoScript.GizmoMode.SCALE)


func _attach_gizmo(camera: Camera3D, ball: Node3D, mode: int) -> void:
	var gizmo := GizmoScript.new()
	add_child(gizmo)
	gizmo.setup(camera)
	gizmo.set_mode(mode as GizmoScript.GizmoMode)
	gizmo.attach_to(ball)


