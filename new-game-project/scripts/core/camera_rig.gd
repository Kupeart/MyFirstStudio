class_name CameraRig
extends Node3D
## מצלמה מסתובבת בסטייל תוכנות תלת-ממד (בלנדר / סימס).
##
## שליטה למשתמש (כמו בבלנדר):
##   גלגלת אמצעית בגרירה  = סיבוב במעגל סביב נקודת המיקוד
##   Shift + גלגלת אמצעית = הזזת נקודת המיקוד (Pan)
##   Ctrl + גלגלת אמצעית  = זום פנימה / החוצה
##   גלגלת                = זום פנימה / החוצה
##   W/A/S/D + Q/E        = תנועה חופשית בעולם
##   Shift (לחוץ)         = תנועה מהירה יותר
##   F                    = מיקוד חזרה למרכז (או על העצם הנבחר)
##
## המקש הימני אינו מזיז את המצלמה כלל - הוא שייך למנוע הבחירה
## (ביטול בחירה / ביטול גרירת גיזמו).

## מרחק מינימלי ומקסימלי מהמצלמה לנקודת המיקוד, במטרים.
const MIN_DISTANCE := 1.0
const MAX_DISTANCE := 80.0
## גבולות זווית ההסתכלות - לא נותנים למצלמה להתהפך.
const MIN_PITCH := -85.0
const MAX_PITCH := 85.0
## המרחק ההתחלתי של הסטודיו.
const START_DISTANCE := 13.0

@export_group("מהירויות")
## מעלות סיבוב לכל פיקסל של תנועת עכבר.
@export var orbit_speed := 0.22
## רגישות ההזזה (מוכפלת במרחק המצלמה).
@export var pan_speed := 0.0022
## כמה זום בכל מדרגת גלגלת (1.15 = 15% למדרגה).
@export var zoom_step := 1.15
## רגישות הזום בגרירה (Ctrl + גלגלת אמצעית). גבוה = זום מהיר יותר.
@export var zoom_drag_speed := 0.006
## מהירות תנועה חופשית, במטרים לשנייה.
@export var move_speed := 9.0
## מכפיל מהירות כשמחזיקים Shift.
@export var fast_multiplier := 2.5
## כמה מהר המצלמה "מדביקה" את היעד (גבוה = חד יותר).
@export var smoothing := 14.0

enum DragMode { NONE, ORBIT, PAN, ZOOM }

var _drag_mode: DragMode = DragMode.NONE
## הכפתור שהתחיל את הגרירה הנוכחית - משחררים רק אותו.
var _drag_button: int = MOUSE_BUTTON_NONE
var _yaw := deg_to_rad(-40.0)
var _pitch := deg_to_rad(-26.0)
var _distance := START_DISTANCE
var _target_distance := START_DISTANCE
var _pivot := Vector3(0.0, 0.8, 0.0)
var _target_pivot := Vector3(0.0, 0.8, 0.0)

@onready var yaw_node: Node3D = $Yaw
@onready var pitch_node: Node3D = $Yaw/Pitch
@onready var camera: Camera3D = $Yaw/Pitch/Camera3D


func _ready() -> void:
	camera.make_current()
	_apply_transform()


func _process(delta: float) -> void:
	_handle_keyboard_movement(delta)
	var t := 1.0 - exp(-smoothing * delta)
	_distance = lerpf(_distance, _target_distance, t)
	_pivot = _pivot.lerp(_target_pivot, t)
	_apply_transform()


func _input(event: InputEvent) -> void:
	# תנועת עכבר מטופלת כאן ולא ב-_unhandled_input, כדי שגרירה לא תיפסק
	# אם סמן העכבר עובר מעל חלון ממשק בדרך.
	var motion := event as InputEventMouseMotion
	if motion == null or _drag_mode == DragMode.NONE:
		return

	match _drag_mode:
		DragMode.ORBIT:
			_yaw -= motion.relative.x * orbit_speed * 0.0175
			_pitch = clampf(
				_pitch - motion.relative.y * orbit_speed * 0.0175,
				deg_to_rad(MIN_PITCH),
				deg_to_rad(MAX_PITCH)
			)
		DragMode.PAN:
			_pan(motion.relative)
		DragMode.ZOOM:
			_zoom_by_drag(motion.relative)


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		if _is_camera_button(button.button_index):
			if button.pressed:
				_begin_drag(button)
			elif button.button_index == _drag_button:
				_drag_button = MOUSE_BUTTON_NONE
				_drag_mode = DragMode.NONE
			return
		if not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = maxf(_target_distance / zoom_step, MIN_DISTANCE)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = minf(_target_distance * zoom_step, MAX_DISTANCE)
		return

	if event.is_action_pressed("cam_focus"):
		focus_on(_target_pivot)


## האם הכפתור הזה מתחיל גרירת מצלמה.
## רק המקש האמצעי מזיז מצלמה - המקש הימני שייך לביטול בחירה וביטול גרירה.
static func _is_camera_button(index: int) -> bool:
	return index == MOUSE_BUTTON_MIDDLE


## בוחר מה תעשה הגרירה לפי המקשים שמוחזקים בזמן הלחיצה.
func _begin_drag(button: InputEventMouseButton) -> void:
	_drag_button = button.button_index
	if button.shift_pressed:
		_drag_mode = DragMode.PAN
	elif button.ctrl_pressed:
		_drag_mode = DragMode.ZOOM
	else:
		_drag_mode = DragMode.ORBIT


## ממקד את המצלמה על נקודה בעולם (למשל אובייקט שנבחר) ומתקרב אליה.
func focus_on(point: Vector3, radius := 3.0) -> void:
	_target_pivot = point
	_target_distance = clampf(radius * 3.0, MIN_DISTANCE, MAX_DISTANCE)


## קובע את נקודת המיקוד בלי לשנות את המרחק - כך הסיבוב ייעשה סביב העצם
## שנבחר בלי שהמצלמה תזנק למקום אחר.
func set_pivot(point: Vector3, immediate := false) -> void:
	_target_pivot = point
	if immediate:
		_pivot = point


## נקודת המיקוד הנוכחית של המצלמה.
func get_pivot() -> Vector3:
	return _pivot


func _pan(relative: Vector2) -> void:
	var cam_basis := camera.global_transform.basis
	var factor := _distance * pan_speed
	_target_pivot += cam_basis.x * -relative.x * factor
	_target_pivot += cam_basis.y * relative.y * factor


## זום בגרירה: ימינה או למעלה = להתקרב, שמאלה או למטה = להתרחק.
func _zoom_by_drag(relative: Vector2) -> void:
	var amount := (relative.x - relative.y) * zoom_drag_speed
	_target_distance = clampf(_target_distance * exp(-amount), MIN_DISTANCE, MAX_DISTANCE)


func _handle_keyboard_movement(delta: float) -> void:
	if _is_typing():
		return

	var input := Vector2(
		Input.get_action_strength("cam_right") - Input.get_action_strength("cam_left"),
		Input.get_action_strength("cam_back") - Input.get_action_strength("cam_forward")
	)
	var vertical := Input.get_action_strength("cam_up") - Input.get_action_strength("cam_down")
	if input.is_zero_approx() and is_zero_approx(vertical):
		return

	var speed := move_speed * clampf(_distance / START_DISTANCE, 0.25, 3.0)
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= fast_multiplier

	# תנועה קדימה/אחורה לפי כיוון ההסתכלות האופקי בלבד (כמו בסימס).
	var yaw_basis := yaw_node.global_transform.basis
	var forward := Vector3(-yaw_basis.z.x, 0.0, -yaw_basis.z.z).normalized()
	var right := Vector3(yaw_basis.x.x, 0.0, yaw_basis.x.z).normalized()
	var direction := -forward * input.y + right * input.x + Vector3.UP * vertical
	if direction.is_zero_approx():
		return

	_target_pivot += direction.normalized() * speed * delta
	# תנועה אנכית מיידית, כדי שלא תיווצר תחושת גומי
	if not is_zero_approx(vertical):
		_pivot.y = _target_pivot.y


func _apply_transform() -> void:
	yaw_node.rotation = Vector3(0.0, _yaw, 0.0)
	pitch_node.rotation = Vector3(_pitch, 0.0, 0.0)
	camera.position = Vector3(0.0, 0.0, _distance)
	yaw_node.global_position = _pivot


## האם המשתמש מקליד כרגע בשדה טקסט? אם כן - לא מזיזים את המצלמה במקלדת.
func _is_typing() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null:
		return false
	return focus is LineEdit or focus is TextEdit or focus is SpinBox
