class_name TimelinePanel
extends Control
## חלון ציר הזמן בתחתית המסך: פס כלים עליון עם אייקונים, וסרגל פריימים
## שמחלק את רוחב החלון ל-24 פריימים על גבי האריח המצויר.
##
## החלון לא מכיל את ההיגיון של האנימציה - הוא רק מציג ושולח הודעות
## (signals) לשורש הסטודיו, שמוסר אותן ל-TimelineManager. כך אפשר לבדוק
## את הלוגיקה של הציר בלי ממשק.
##
## כל הכיתובים בעברית בלבד, והכפתורים הם אייקונים בלי טקסט בכלל: לפונט
## המובנה של גודו אין סמלים ואמוג'י, וסמלים היו מוצגים כמלבנים ריקים.
## האייקונים יושבים ב-res://assets/2DUI/TimelineIcons.

## המשתמש ביקש להקליט את הפריים הנוכחי.
signal capture_requested()
## ניהול הניגון וחזרה לתחילת הציר.
signal play_requested()
signal stop_requested()
signal reset_requested()
## מעבר לפריים הבא או הקודם.
signal next_frame_requested()
signal previous_frame_requested()
## מעבר ל-Keyframe - הפריים הקרוב שיש בו הקלטה.
signal next_key_requested()
signal previous_key_requested()
## בחירה ידנית של פריים בסרגל (הפריימים סופרים מ-1).
signal frame_selected(frame_index: int)
## שינוי קצב הניגון.
signal fps_changed(fps: int)
## מעבר בין מצב Stepped למצב Spline (מעבר רך בין ההקלטות).
signal interpolation_toggled(spline: bool)
## הדלקה וכיבוי של הבצל (רוח רפאים של הפריים הקודם והבא).
signal onion_toggled(enabled: bool)
## הדלקה וכיבוי של צילום אוטומטי (סיום גרירה נקלט לפריים הנוכחי).
signal auto_frame_toggled(enabled: bool)

## גובה החלון: הפס המצויר שמחזיק את הכפתורים (86) ועוד גובה הסרגל (201).
const PANEL_HEIGHT := 287.0
## גובה הפס העליון המצויר - שם יושבים הכפתורים.
const TOP_BAR_HEIGHT := 86.0
## מספר הפריימים בסרגל.
const FRAME_COUNT := 24
## הרוחב שאליו צויר אריח הסרגל: 24 פריימים של 12 פיקסלים.
const RULER_TILE_WIDTH := 288.0
## גובה רצועת השנתות שבראש הסרגל, מתוך הציור עצמו.
const RULER_BAND_HEIGHT := 28.0

## צבעי הפריים בסרגל: מסגרת הפריים הנוכחי, סימן ההקלטה, וריחוף עדין.
const GOLD := Color(0.98, 0.78, 0.25)
const RECORDED_COLOR := Color(0.11, 0.53, 0.4)
const CELL_HOVER := Color(1.0, 1.0, 1.0, 0.16)
const CELL_CURRENT := Color(0.98, 0.78, 0.25, 0.32)

## האייקון של כל מצב במתגים. המצב ההתחלתי יושב בסצנה, והסקריפט מחליף
## לאייקון של המצב השני בכל לחיצה.
const ICON_STEPPED := "res://assets/2DUI/TimelineIcons/ToggleStepped.png"
const ICON_SPLINE := "res://assets/2DUI/TimelineIcons/ToggleSpline.png"
const ICON_ONION_OFF := "res://assets/2DUI/TimelineIcons/OnionSkinOff.png"
const ICON_ONION_ON := "res://assets/2DUI/TimelineIcons/OnionSkinOn.png"
const ICON_AUTO_OFF := "res://assets/2DUI/TimelineIcons/Autoframe_Disabled.png"
const ICON_AUTO_ON := "res://assets/2DUI/TimelineIcons/Autoframe_Enabled.png"

@onready var _reset_button: TextureButton = $TopBar/ResetButton
@onready var _previous_key_button: TextureButton = $TopBar/PreviousKeyButton
@onready var _previous_button: TextureButton = $TopBar/PreviousButton
@onready var _play_button: TextureButton = $TopBar/PlayButton
@onready var _stop_button: TextureButton = $TopBar/StopButton
@onready var _next_button: TextureButton = $TopBar/NextButton
@onready var _next_key_button: TextureButton = $TopBar/NextKeyButton
@onready var _capture_button: TextureButton = $TopBar/CaptureButton
@onready var _interpolation_button: TextureButton = $TopBar/InterpolationButton
@onready var _onion_button: TextureButton = $TopBar/OnionButton
@onready var _auto_frame_button: TextureButton = $TopBar/AutoFrameButton
@onready var _fps_option: OptionButton = $TopBar/FpsOption
@onready var _frames_area: Control = $Frames

## הכפתור של כל פריים בסרגל.
var _cells: Array[Button] = []
## הסימן הקטן שמראה שהפריים הוקלט.
var _record_marks: Array[Panel] = []
## אילו פריימים הוקלטו.
var _recorded: Array[bool] = []
## הפריים הנוכחי (1 עד FRAME_COUNT).
var _current_frame := 1
## הרוחב של פריים בודד על המסך - מתעדכן בכל שינוי גודל של החלון.
var _frame_width := 0.0
## מצבי התצוגה של הציר. הם נשמרים כאן לתצוגה, ומועברים למנהל ציר הזמן
## דרך האותות (המנהל הוא היחיד שמחליט מה המשמעות שלהם).
var _spline := false
var _onion := false
var _auto_frame := false


func _ready() -> void:
	_build_fps_choices()
	_build_frames()
	_connect_buttons()
	# פריסת הפריימים מחושבת מהרוחב בפועל, ולכן היא מתעדכנת בכל שינוי גודל.
	_frames_area.resized.connect(_layout_frames)
	set_current_frame(1)
	set_playing(false)
	_refresh_toggle_icons()
	_layout_frames()


# ------------------------------------------------------------------ בנייה

func _connect_buttons() -> void:
	_capture_button.pressed.connect(func() -> void: capture_requested.emit())
	_reset_button.pressed.connect(func() -> void: reset_requested.emit())
	_previous_button.pressed.connect(func() -> void: previous_frame_requested.emit())
	_previous_key_button.pressed.connect(func() -> void: previous_key_requested.emit())
	_play_button.pressed.connect(func() -> void: play_requested.emit())
	_stop_button.pressed.connect(func() -> void: stop_requested.emit())
	_next_button.pressed.connect(func() -> void: next_frame_requested.emit())
	_next_key_button.pressed.connect(func() -> void: next_key_requested.emit())
	_interpolation_button.pressed.connect(_on_interpolation_pressed)
	_onion_button.pressed.connect(_on_onion_pressed)
	_auto_frame_button.pressed.connect(_on_auto_frame_pressed)
	_fps_option.item_selected.connect(_on_fps_selected)


## ממלא את רשימת קצבי הניגון ובוחר את ברירת המחדל (12 פריימים בשנייה).
func _build_fps_choices() -> void:
	_fps_option.clear()
	for value in TimelineManager.FPS_CHOICES:
		_fps_option.add_item("%d פריימים בשנייה" % value, value)
	var index := TimelineManager.FPS_CHOICES.find(TimelineManager.DEFAULT_FPS)
	if index >= 0:
		_fps_option.select(index)


## בונה פריים אחד לכל משבצת: מספר הפריים בתוך רצועת השנתות, וסימן הקלטה
## קטן מעל אזור המסלול. המיקום בפועל נקבע ב-_layout_frames.
func _build_frames() -> void:
	for child in _frames_area.get_children():
		_frames_area.remove_child(child)
		child.queue_free()
	_cells.clear()
	_record_marks.clear()
	_recorded.clear()

	var group := ButtonGroup.new()
	for index in range(1, FRAME_COUNT + 1):
		var cell := Button.new()
		cell.name = "Frame%d" % index
		cell.toggle_mode = true
		cell.button_group = group
		cell.focus_mode = Control.FOCUS_NONE
		cell.tooltip_text = "פריים %d" % index
		cell.pressed.connect(_on_cell_pressed.bind(index))
		_frames_area.add_child(cell)

		var label := Label.new()
		label.name = "Number"
		label.text = str(index)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.09, 0.24, 0.28))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		label.offset_bottom = RULER_BAND_HEIGHT
		cell.add_child(label)

		var mark := Panel.new()
		mark.name = "Recorded"
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.set_anchors_preset(Control.PRESET_CENTER_TOP)
		mark.offset_left = -5.0
		mark.offset_right = 5.0
		mark.offset_top = RULER_BAND_HEIGHT + 4.0
		mark.offset_bottom = RULER_BAND_HEIGHT + 14.0
		var mark_style := StyleBoxFlat.new()
		mark_style.bg_color = RECORDED_COLOR
		mark_style.set_corner_radius_all(5)
		mark.add_theme_stylebox_override("panel", mark_style)
		mark.visible = false
		cell.add_child(mark)

		_cells.append(cell)
		_record_marks.append(mark)
		_recorded.append(false)

	_refresh_all_cells()


## פורס את 24 הפריימים על רוחב הסרגל: הפריים ה-i מתחיל ב-
## (i-1) x frame_width, ורוחבו frame_width בדיוק - כך שהוא חופף לשנתה
## המצוירת של הפריים. נקרא שוב בכל שינוי גודל של החלון.
func _layout_frames() -> void:
	var width := _frames_area.size.x
	if width <= 0.0:
		return
	_frame_width = width / float(FRAME_COUNT)
	for index in _cells.size():
		var cell := _cells[index]
		cell.position = Vector2(frame_x(index + 1, _frame_width), 0.0)
		cell.size = Vector2(_frame_width, _frames_area.size.y)


## המיקום של פריים על הסרגל: x = (frame - 1) x frame_width.
static func frame_x(frame_index: int, frame_width: float) -> float:
	return float(frame_index - 1) * frame_width


# ------------------------------------------------------------------ עדכון מהשורש

## מדגיש את הפריים הנוכחי בסרגל.
func set_current_frame(frame_index: int) -> void:
	_current_frame = clampi(frame_index, 1, FRAME_COUNT)
	for index in _cells.size():
		_cells[index].set_pressed_no_signal(index + 1 == _current_frame)
	_refresh_all_cells()


## מסמן או מסיר את הסימן של פריים מוקלט.
func set_frame_recorded(frame_index: int, recorded: bool) -> void:
	var index := clampi(frame_index, 1, FRAME_COUNT) - 1
	_recorded[index] = recorded
	_refresh_cell(index)


## מסיר את כל סימני ההקלטה (למשל אחרי איפוס הציר).
func reset_records() -> void:
	for index in _recorded.size():
		_recorded[index] = false
	_refresh_all_cells()


## מעדכן את כפתורי הניגון לפי המצב, ומעמעם את זה שאי אפשר ללחוץ עליו.
func set_playing(playing: bool) -> void:
	_play_button.disabled = playing
	_stop_button.disabled = not playing
	_play_button.modulate = Color(1.0, 1.0, 1.0, 0.4) if playing else Color.WHITE
	_stop_button.modulate = Color.WHITE if playing else Color(1.0, 1.0, 1.0, 0.4)


## קצב הניגון שנבחר כרגע.
func get_fps() -> int:
	if _fps_option.selected < 0:
		return TimelineManager.DEFAULT_FPS
	return _fps_option.get_item_id(_fps_option.selected)


## הפריים הנוכחי שמוצג בסרגל.
func get_current_frame() -> int:
	return _current_frame


## הרוחב של פריים בודד על המסך (0 עד שהחלון מחושב).
func get_frame_width() -> float:
	return _frame_width


## מספר הפריימים שנבנו בסרגל.
func get_cell_count() -> int:
	return _cells.size()


## האם הפריים מסומן כמוקלט.
func is_frame_recorded(frame_index: int) -> bool:
	return _recorded[clampi(frame_index, 1, FRAME_COUNT) - 1]


## האם מצב האינטרפולציה הוא Spline (מעבר רך בין ההקלטות).
func is_spline_mode() -> bool:
	return _spline


## האם הבצל דלוק (רוחות רפאים של הפריים הקודם והבא).
func is_onion_skin() -> bool:
	return _onion


## האם הצילום האוטומטי דלוק.
func is_auto_frame() -> bool:
	return _auto_frame


# ------------------------------------------------------------------ פנימי

func _on_cell_pressed(frame_index: int) -> void:
	set_current_frame(frame_index)
	frame_selected.emit(frame_index)


func _on_fps_selected(index: int) -> void:
	fps_changed.emit(_fps_option.get_item_id(index))


func _on_interpolation_pressed() -> void:
	_spline = not _spline
	_refresh_toggle_icons()
	interpolation_toggled.emit(_spline)


func _on_onion_pressed() -> void:
	_onion = not _onion
	_refresh_toggle_icons()
	onion_toggled.emit(_onion)


func _on_auto_frame_pressed() -> void:
	_auto_frame = not _auto_frame
	_refresh_toggle_icons()
	auto_frame_toggled.emit(_auto_frame)


## מעדכן את האייקון של שלושת המתגים לפי המצב שלהם: לכל אחד יש ציור
## נפרד למצב מופעל ולמצב כבוי.
func _refresh_toggle_icons() -> void:
	_interpolation_button.texture_normal = load(ICON_SPLINE if _spline else ICON_STEPPED)
	_onion_button.texture_normal = load(ICON_ONION_ON if _onion else ICON_ONION_OFF)
	_auto_frame_button.texture_normal = load(ICON_AUTO_ON if _auto_frame else ICON_AUTO_OFF)


func _refresh_all_cells() -> void:
	for index in _cells.size():
		_refresh_cell(index)


## צובע משבצת: מסגרת מוזהבת לפריים הנוכחי, וסימן ירוק לפריים מוקלט.
func _refresh_cell(index: int) -> void:
	var cell := _cells[index]
	var is_current := index + 1 == _current_frame
	cell.add_theme_stylebox_override("normal", _make_cell_style(is_current, false))
	cell.add_theme_stylebox_override("hover", _make_cell_style(is_current, true))
	cell.add_theme_stylebox_override("pressed", _make_cell_style(is_current, false))
	cell.add_theme_stylebox_override("checked", _make_cell_style(true, false))
	_record_marks[index].visible = _recorded[index]


## הרקע של פריים: שקוף כברירת מחדל, ריחוף עדין, ולפריים הנוכחי רקע מוזהב
## עם מסגרת דקה לשני הצדדים - כך רואים מיד איפה עומדים.
func _make_cell_style(current: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if current:
		style.bg_color = CELL_CURRENT
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_color = GOLD
	elif hover:
		style.bg_color = CELL_HOVER
	return style
