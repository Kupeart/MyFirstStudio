## הקובץ אינו בשימוש עוד - הוחלף ב-ObjectControls (scripts/ui/object_controls.gd)
## שגם מוסיף את כפתור קנה המידה ואת אייקוני הפעולה.
extends VBoxContainer
## מתג מצב הזזה/סיבוב שמוצג לצד האובייקט הנבחר:
## הזזה (חצים) למעלה, סיבוב (טבעות) למטה.
##
## המתג עוקב אחרי האובייקט על המסך - ממוקם בצד ימין שלו (ומיושר לחלקו
## העליון), ואם אין מקום מימין הוא עובר אוטומטית לצד שמאל. הוא מופיע
## רק כשיש אובייקט נבחר, ונעלם כשאין.
##
## האייקונים מצוירים בקוד (draw_line / draw_arc) ולא בתווי טקסט - הסמלים
## ⤧ ו-↻ לא הופיעו בגופנים העבריים ולכן נשארו רק מילים. ציור עצמי עובד
## על כל מחשבה.
##
## מצב פעיל: רקע כחול מלא + מסגרת + אייקון בהיר.
## מצב כבוי: רקע כהה שקוף + אייקון עמום.

const GizmoScript := preload("res://scripts/core/move_gizmo.gd")
const ModelBoundsScript := preload("res://scripts/core/model_bounds.gd")

## גודל כל כפתור אייקון.
const BUTTON_SIZE := Vector2(46.0, 46.0)
## רווח בין שני הכפתורים.
const SEPARATION := 6.0
## עיגול פינות הכפתור.
const CORNER_RADIUS := 11
## רווח אופקי בין האובייקט למתג, הרמה מעל קצה האובייקט העליון,
## ומרווח מינימלי מקצות המסך.
const GAP_SIDE := 26.0
const VERTICAL_LIFT := 22.0
const EDGE_MARGIN := 8.0

## צבע האייקון - כחול-ציאן כמו בסקיצה.
const ICON_COLOR := Color(0.42, 0.72, 1.0)
## שקיפות האייקון כשהמצב כבוי.
const IDLE_ALPHA := 0.38
## רקע הכפתור: פעיל / רגיל / ריחוף / לחוץ.
const ACTIVE_BG := Color(0.12, 0.30, 0.50, 0.90)
const IDLE_BG := Color(0.08, 0.09, 0.12, 0.55)
const HOVER_BG := Color(0.15, 0.38, 0.62, 0.90)
const PRESSED_BG := Color(0.42, 0.72, 1.0, 0.45)

var _gizmo: GizmoScript = null
var _camera: Camera3D = null
var _selection: StudioSelection = null
var _translate_btn: Button = null
var _rotate_btn: Button = null
## מצב (int של GizmoMode) -> צומת הציור של האייקון שלו.
var _icons: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", int(SEPARATION))
	_translate_btn = _make_mode_button(GizmoScript.GizmoMode.TRANSLATE, "הזזה - חצים צבעוניים")
	_rotate_btn = _make_mode_button(GizmoScript.GizmoMode.ROTATE, "סיבוב - טבעות סביב הצירים")
	visible = false
	_refresh_visuals()


## מחבר את המתג לגיזמו, למצלמה ולמנוע הבחירה:
## מקשיב לשינויי מצב, מחיל מצבים בלחיצה, ועוקב אחרי האובייקט הנבחר.
func setup(gizmo: GizmoScript, camera: Camera3D, selection: StudioSelection) -> void:
	_gizmo = gizmo
	_camera = camera
	_selection = selection
	if _gizmo != null and _gizmo.has_signal("mode_changed"):
		if not _gizmo.mode_changed.is_connected(_on_gizmo_mode_changed):
			_gizmo.mode_changed.connect(_on_gizmo_mode_changed)
	_refresh_visuals()


## מצמיד את המתג לצד הקבוצה הנבחרת. בלי בחירה - המתג מוסתר.
func _process(_delta: float) -> void:
	if _selection == null or _camera == null or _selection.selection_count() == 0:
		visible = false
		return

	var center := _selection.get_selection_center()
	if _camera.is_position_behind(center):
		visible = false
		return

	var box := ModelBoundsScript.screen_box(_camera, center, _selection.get_selection_size())
	var view := get_viewport_rect().size
	var own := get_combined_minimum_size()

	# ברירת מחדל: מימין לאובייקט, מעט מעל קצהו העליון.
	var target := Vector2(box.end.x + GAP_SIDE, box.position.y - VERTICAL_LIFT)
	if target.x + own.x > view.x - EDGE_MARGIN:
		# אין מקום מימין - עוברים לצד שמאל של האובייקט.
		target.x = box.position.x - GAP_SIDE - own.x
	target.x = clampf(target.x, EDGE_MARGIN, maxf(EDGE_MARGIN, view.x - own.x - EDGE_MARGIN))
	target.y = clampf(target.y, EDGE_MARGIN, maxf(EDGE_MARGIN, view.y - own.y - EDGE_MARGIN))

	position = target
	visible = true


func _current_mode() -> int:
	if _gizmo != null:
		return int(_gizmo.get_mode())
	return int(GizmoScript.GizmoMode.TRANSLATE)


## בונה כפתור אייקון אחד - כפתור רגיל ועליו שכבת ציור.
func _make_mode_button(mode: int, tip: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tip
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(_on_mode_pressed.bind(mode))
	_apply_button_style(button, false)

	var icon := Control.new()
	icon.name = "Icon"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_icon.bind(icon, mode))
	button.add_child(icon)
	add_child(button)
	_icons[mode] = icon
	return button


## מדליק את הכפתור של המצב הנוכחי ומכבה את השני.
func _refresh_visuals() -> void:
	var mode := _current_mode()
	if _translate_btn != null:
		_apply_button_style(_translate_btn, mode == int(GizmoScript.GizmoMode.TRANSLATE))
	if _rotate_btn != null:
		_apply_button_style(_rotate_btn, mode == int(GizmoScript.GizmoMode.ROTATE))
	for key in _icons:
		var icon := _icons[key] as Control
		if icon != null:
			icon.queue_redraw()


## סגנון הכפתור לפי מצב פעיל/כבוי.
func _apply_button_style(button: Button, active: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(CORNER_RADIUS)
	normal.bg_color = ACTIVE_BG if active else IDLE_BG
	if active:
		normal.set_border_width_all(2)
		normal.border_color = Color(ICON_COLOR.r, ICON_COLOR.g, ICON_COLOR.b, 0.75)
	button.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ACTIVE_BG if active else HOVER_BG
	button.add_theme_stylebox_override("hover", hover)

	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color = PRESSED_BG
	button.add_theme_stylebox_override("pressed", pressed_style)


# ------------------------------------------------------------------ אייקונים

## בוחר איזה אייקון לצייר על השכבה, ובאיזה בהירות לפי מצב פעיל.
func _draw_icon(canvas: Control, mode: int) -> void:
	var center := canvas.size * 0.5
	var active := _current_mode() == mode
	var color := ICON_COLOR
	color.a = 1.0 if active else IDLE_ALPHA
	var extent := minf(canvas.size.x, canvas.size.y)
	if mode == int(GizmoScript.GizmoMode.TRANSLATE):
		_draw_move_icon(canvas, center, extent * 0.38, color)
	else:
		_draw_rotate_icon(canvas, center, extent * 0.32, color)


## ארבעה חצים מהמרכז לכל הכיוונים - סמל ההזזה.
func _draw_move_icon(canvas: Control, center: Vector2, length: float, color: Color) -> void:
	var head := length * 0.45
	var shaft_end := length - head * 0.55
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var end := center + dir * shaft_end
		canvas.draw_line(center - dir * 2.0, end, color, 4.0, true)
		var side := Vector2(-dir.y, dir.x)
		var tip := center + dir * length
		var base := center + dir * (length - head)
		var points := PackedVector2Array([
			tip,
			base + side * head * 0.62,
			base - side * head * 0.62
		])
		canvas.draw_colored_polygon(points, color)


## שתי קשתות עם ראשי חצים בצורת לולאה - סמל הסיבוב.
func _draw_rotate_icon(canvas: Control, center: Vector2, radius: float, color: Color) -> void:
	var gap := deg_to_rad(60.0)
	for offset: float in [0.0, PI]:
		var start := offset + gap * 0.5
		var end := offset + PI - gap * 0.5
		canvas.draw_arc(center, radius, start, end, 32, color, 4.0, true)
		_draw_arc_head(canvas, center, radius, end, color)


## ראש חץ בקצה קשת - מצביע לכיוון ההתקדמות שלה.
func _draw_arc_head(canvas: Control, center: Vector2, radius: float, angle: float, color: Color) -> void:
	var tip := center + Vector2(cos(angle), sin(angle)) * radius
	var tangent := Vector2(-sin(angle), cos(angle))
	var side := Vector2(-tangent.y, tangent.x)
	var back := tip - tangent * 8.0
	var points := PackedVector2Array([
		tip + tangent * 2.5,
		back + side * 5.0,
		back - side * 5.0
	])
	canvas.draw_colored_polygon(points, color)


# ------------------------------------------------------------------ אירועים

func _on_mode_pressed(mode: int) -> void:
	if _gizmo != null:
		_gizmo.set_mode(mode as GizmoScript.GizmoMode)
	# גם כשהמצב כבר היה זהה - מרעננים כדי שהמקש הלחוץ ירגיש תגובתי.
	_refresh_visuals()


func _on_gizmo_mode_changed(_new_mode: int) -> void:
	_refresh_visuals()
