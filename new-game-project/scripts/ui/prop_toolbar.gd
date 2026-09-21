## הקובץ אינו בשימוש עוד - הוחלף ב-ObjectControls (scripts/ui/object_controls.gd)
## שהפך את כפתורי הפעולה לאייקונים משני צדי העצם הנבחר.
extends PanelContainer
## סרגל צף קטן שמופיע מעל העצם הנבחר - כפתורי פעולה בלבד:
##   [ ✓ הנח ]  [ + שכפול ]  [ × מחיקה ]
##
## החלפת מצב הזזה/סיבוב עברה למתג שמוצמד לצד האובייקט הנבחר
## (gizmo_mode_toggle) - מופיע רק כשיש בחירה. הסרגל עוקב אחרי העצם
## על המסך, מתחבא כשאין בחירה או בזמן גרירת גיזמו, ונשאר בתוך המסך
## גם כשהעצם בקצה.

const SelectionScript := preload("res://scripts/core/selection.gd")

signal confirmed()
signal duplicate_requested()
signal delete_requested()

const BUTTON_SIZE := Vector2(84.0, 44.0)
const FONT_SIZE := 18
const GAP_ABOVE := 22.0

var _camera: Camera3D = null
var _selection: SelectionScript = null
var _row: HBoxContainer = null


func _ready() -> void:
	_build()
	visible = false


func setup(camera: Camera3D, selection: SelectionScript) -> void:
	_camera = camera
	_selection = selection


func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.14, 0.94)
	style.set_corner_radius_all(14)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1, 1, 1, 0.15)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	add_child(_row)

	# כפתורי פעולה - הסמלים ✓ + × נתמכים בכל הגופנים, ולכן מוצגים תמיד.
	_add_action_button("✓", "סיום", Color(0.45, 0.95, 0.5), "סיום העריכה וסגירת הבחירה", _on_confirm)
	_add_action_button("+", "שכפול", Color(0.6, 0.8, 1.0), "שכפול העצם (Ctrl+D)", _on_duplicate)
	_add_action_button("×", "מחיקה", Color(1.0, 0.55, 0.5), "מחיקת העצם (Delete)", _on_delete)


func _add_action_button(symbol: String, word: String, color: Color, tip: String, action: Callable) -> void:
	var button := Button.new()
	button.text = _pick_label(symbol, word)
	button.tooltip_text = tip
	button.custom_minimum_size = BUTTON_SIZE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.12)
	normal.set_corner_radius_all(10)
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.28)
	hover.set_corner_radius_all(10)
	button.add_theme_stylebox_override("hover", hover)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(1, 1, 1, 0.42)
	pressed_style.set_corner_radius_all(10)
	button.add_theme_stylebox_override("pressed", pressed_style)

	button.pressed.connect(action)
	_row.add_child(button)


func _pick_label(symbol: String, word: String) -> String:
	var code := symbol.unicode_at(0)
	var font := get_theme_font("font")
	if font != null and font.has_char(code):
		return symbol + " " + word
	var fallback := ThemeDB.fallback_font
	if fallback != null and fallback.has_char(code):
		return symbol + " " + word
	return word


func _process(_delta: float) -> void:
	if _selection == null or _camera == null or _selection.selection_count() == 0:
		visible = false
		return
	if _selection.is_dragging_gizmo():
		visible = false
		return

	# הסרגל מרחף מעל כל הקבוצה הנבחרת - מעל מרכז התיבה התוחמת שלה.
	var top := _selection.get_selection_center()
	top += Vector3(0.0, _selection.get_selection_size().y * 0.5 + 0.1, 0.0)

	if _camera.is_position_behind(top):
		visible = false
		return

	var screen := _camera.unproject_position(top)
	var view := get_viewport_rect().size
	var target := screen - Vector2(size.x * 0.5, size.y + GAP_ABOVE)
	target.x = clampf(target.x, 8.0, maxf(8.0, view.x - size.x - 8.0))
	target.y = clampf(target.y, 8.0, maxf(8.0, view.y - size.y - 8.0))
	position = target
	visible = true


func _on_confirm() -> void:
	confirmed.emit()


func _on_duplicate() -> void:
	duplicate_requested.emit()


func _on_delete() -> void:
	delete_requested.emit()
