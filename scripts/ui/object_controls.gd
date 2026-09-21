class_name ObjectControls
extends Control
## כל כפתורי העריכה של העצם הנבחר, כאייקונים קטנים משני צדדיו:
##
##   צד ימין (מעל האובייקט ומעט ימינה ממנו):
##     [ ✗ מחיקה ]  [ ✓ אישור ]        <- סמלים צבעוניים בלי רקע
##     [ שכפול ]
##     [ הזזה ]  [ סיבוב ]  [ קנה מידה ] <- כפתורי מצב הגיזמו
##
##   צד שמאל: אייקון ארגז כלים (בהמשך יפתח חלון עיצוב וחומרים).
##
## הקבוצה עוקבת אחרי העצם הנבחר (או מרכז הקבוצה בבחירה מרובה), ומתחבאת
## כשאין שום בחירה.

const GizmoScript := preload("res://scripts/core/move_gizmo.gd")
const ModelBoundsScript := preload("res://scripts/core/model_bounds.gd")
const IconButtonScript := preload("res://scripts/ui/icon_button.gd")

signal confirmed()
signal duplicate_requested()
signal delete_requested()
## נשלח כשלוחצים על ארגז הכלים - פותח את חלון החומריות של העצם.
signal materials_requested()

## רווח מהאובייקט, הרמה מעל קצהו העליון, ומרווח מינימלי מקצות המסך.
const GAP_SIDE := 26.0
const VERTICAL_LIFT := 22.0
const EDGE_MARGIN := 8.0
## רווח בין האייקונים.
const SEPARATION := 6.0

var _gizmo: GizmoScript = null
var _camera: Camera3D = null
var _selection: StudioSelection = null

var _right_box: VBoxContainer = null
var _mode_column: VBoxContainer = null
var _toolbox: IconButton = null
## מצב גיזמו -> כפתור, כדי להדליק את הנכון.
var _mode_buttons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false


## מחבר את הכפתורים לגיזמו, למצלמה ולמנוע הבחירה.
func setup(gizmo: GizmoScript, camera: Camera3D, selection: StudioSelection) -> void:
	_gizmo = gizmo
	_camera = camera
	_selection = selection
	if _gizmo != null and _gizmo.has_signal("mode_changed"):
		if not _gizmo.mode_changed.is_connected(_on_gizmo_mode_changed):
			_gizmo.mode_changed.connect(_on_gizmo_mode_changed)
	_refresh_mode_buttons()


func _build() -> void:
	# ארגז הכלים - בצד שמאל של האובייקט.
	_toolbox = IconButtonScript.new()
	_toolbox.name = "Toolbox"
	_toolbox.configure(
		IconButtonScript.Kind.TOOLBOX,
		"עיצוב וחומרים",
		IconButtonScript.PLAIN_COLOR,
		true,
		false
	)
	_toolbox.pressed.connect(func() -> void: materials_requested.emit())
	add_child(_toolbox)

	# העמודה הימנית: פעולות למעלה, מצבי הגיזמו מתחתיהן.
	_right_box = VBoxContainer.new()
	_right_box.name = "RightBox"
	_right_box.add_theme_constant_override("separation", int(SEPARATION))
	add_child(_right_box)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", int(SEPARATION))
	actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_right_box.add_child(actions)

	var delete_button := IconButtonScript.new()
	delete_button.configure(
		IconButtonScript.Kind.DELETE, "מחיקה (Delete)", IconButtonScript.DELETE_COLOR, false, false
	)
	delete_button.pressed.connect(func() -> void: delete_requested.emit())
	actions.add_child(delete_button)

	var confirm_button := IconButtonScript.new()
	confirm_button.configure(
		IconButtonScript.Kind.CONFIRM, "סיום העריכה (✓)", IconButtonScript.CONFIRM_COLOR, false, false
	)
	confirm_button.pressed.connect(func() -> void: confirmed.emit())
	actions.add_child(confirm_button)

	_mode_column = VBoxContainer.new()
	_mode_column.name = "Modes"
	_mode_column.add_theme_constant_override("separation", int(SEPARATION))
	_right_box.add_child(_mode_column)

	# שכפול - פעולה חד-פעמית, מוצגת כמו כפתור רגיל (לא מצב).
	var duplicate_button := IconButtonScript.new()
	duplicate_button.configure(
		IconButtonScript.Kind.DUPLICATE, "שכפול (Ctrl+D)", IconButtonScript.ICON_COLOR, true, false
	)
	duplicate_button.pressed.connect(func() -> void: duplicate_requested.emit())
	_mode_column.add_child(duplicate_button)

	_add_mode_button(GizmoScript.GizmoMode.TRANSLATE, IconButtonScript.Kind.MOVE, "הזזה - חצים צבעוניים")
	_add_mode_button(GizmoScript.GizmoMode.ROTATE, IconButtonScript.Kind.ROTATE, "סיבוב - טבעות סביב הצירים")
	_add_mode_button(GizmoScript.GizmoMode.SCALE, IconButtonScript.Kind.SCALE, "קנה מידה - הגדלה והקטנה")


func _add_mode_button(mode: int, kind: int, tip: String) -> void:
	var button := IconButtonScript.new()
	button.name = "Mode%d" % mode
	button.configure(kind, tip)
	button.pressed.connect(_on_mode_pressed.bind(mode))
	_mode_column.add_child(button)
	_mode_buttons[mode] = button


func _on_mode_pressed(mode: int) -> void:
	if _gizmo != null:
		_gizmo.set_mode(mode as GizmoScript.GizmoMode)
	_refresh_mode_buttons()


func _on_gizmo_mode_changed(_new_mode: int) -> void:
	_refresh_mode_buttons()


## מדליק את כפתור המצב הנוכחי ומכבה את האחרים.
func _refresh_mode_buttons() -> void:
	var current := int(GizmoScript.GizmoMode.TRANSLATE)
	if _gizmo != null:
		current = int(_gizmo.get_mode())
	for mode in _mode_buttons:
		var button := _mode_buttons[mode] as IconButton
		if button != null:
			button.set_active(mode == current)


## האם העצם הנבחר תומך בשינוי גודל פרוצדורלי (כרגע: שולחן).
func _selection_supports_resize() -> bool:
	if _selection == null or _selection.selection_count() != 1:
		return false
	var prop: Node3D = _selection.get_selected()
	if prop == null or not prop.has_method("get_model"):
		return false
	var model: Node3D = prop.get_model()
	if model == null or not is_instance_valid(model):
		return false
	# לכדור יש עיגול קנה מידה אחיד, לא שינוי הגודל של השולחן.
	if _is_ball(model):
		return false
	return model.has_method("set_dimensions")


## האם הצומת הוא כדור (שעבורו אין עריכת חומרים ואין שינוי גודל פרוצדורלי).
static func _is_ball(node: Node3D) -> bool:
	return (
		node != null
		and (node.has_method("has_shape_keys") or node.has_method("get_ball_kind"))
	)


## האם העצם הנבחר הוא כדור.
func _selection_is_ball() -> bool:
	if _selection == null or _selection.selection_count() != 1:
		return false
	var prop: Node3D = _selection.get_selected()
	if prop == null:
		return false
	if prop.has_method("get_model"):
		var model: Node3D = prop.get_model()
		if _is_ball(model):
			return true
	return _is_ball(prop)


## כפתור מצב קנה המידה מציג שלושה חצים מרובעים כשיש שולחן
## (שינוי גודל פרוצדורלי), וגיזמו קוביות בכל עצם אחר.
func _refresh_scale_mode_button(resizable: bool) -> void:
	var button := _mode_buttons.get(GizmoScript.GizmoMode.SCALE) as IconButton
	if button == null:
		return
	var wanted_kind: int = IconButtonScript.Kind.RESIZE if resizable else IconButtonScript.Kind.SCALE
	if button.icon_kind == wanted_kind:
		return
	button.configure(
		wanted_kind,
		"שינוי גודל - רוחב, אורך וגובה" if resizable else "קנה מידה - הגדלה והקטנה"
	)


## ממקם את האייקונים משני צדי העצם הנבחר בכל פריים.
func _process(_delta: float) -> void:
	if _selection == null or _camera == null or _selection.selection_count() == 0:
		visible = false
		return

	# האייקון של מצב קנה המידה מתאים את עצמו לסוג העצם הנבחר.
	_refresh_scale_mode_button(_selection_supports_resize())

	# לכדור אין עריכת חומרים - אייקון ארגז הכלים מוסתר לגמרי.
	var is_ball := _selection_is_ball()
	_toolbox.visible = not is_ball

	var center := _selection.get_selection_center()
	if _camera.is_position_behind(center):
		visible = false
		return

	var box := ModelBoundsScript.screen_box(_camera, center, _selection.get_selection_size())
	var view := get_viewport_rect().size
	var right_size := _right_box.get_combined_minimum_size()

	# ימין: מימין לאובייקט, מעט מעל קצהו העליון.
	var right_pos := Vector2(box.end.x + GAP_SIDE, box.position.y - VERTICAL_LIFT)
	if right_pos.x + right_size.x > view.x - EDGE_MARGIN:
		right_pos.x = box.position.x - GAP_SIDE - right_size.x
	right_pos.x = clampf(right_pos.x, EDGE_MARGIN, maxf(EDGE_MARGIN, view.x - right_size.x - EDGE_MARGIN))
	right_pos.y = clampf(right_pos.y, EDGE_MARGIN, maxf(EDGE_MARGIN, view.y - right_size.y - EDGE_MARGIN))
	_right_box.position = right_pos

	# שמאל: ארגז הכלים מול אמצע גובה האובייקט (לא לכדור).
	if not is_ball:
		var left_size := _toolbox.get_combined_minimum_size()
		var left_pos := Vector2(box.position.x - GAP_SIDE - left_size.x, box.get_center().y - left_size.y * 0.5)
		left_pos.x = clampf(left_pos.x, EDGE_MARGIN, maxf(EDGE_MARGIN, view.x - left_size.x - EDGE_MARGIN))
		left_pos.y = clampf(left_pos.y, EDGE_MARGIN, maxf(EDGE_MARGIN, view.y - left_size.y - EDGE_MARGIN))
		_toolbox.position = left_pos

	visible = true
