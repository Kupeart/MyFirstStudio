class_name TimelinePanel
extends PanelContainer
## חלון ציר הזמן בתחתית המסך: פס כלים (הקלטה, ניגון, מעבר בין פריימים)
## ורצועת פריימים (filmstrip) אופקית שגוללת.
##
## החלון לא מכיל את ההיגיון של האנימציה - הוא רק מציג ושולח הודעות
## (signals) לשורש הסטודיו, שמוסר אותן ל-TimelineManager. כך אפשר לבדוק
## את הלוגיקה של הציר בלי ממשק.
##
## כל הכיתובים בעברית בלבד: לפונט המובנה של גודו אין סמלים ואמוג'י,
## וסמלים היו מוצגים כמלבנים ריקים.

## המשתמש ביקש להקליט את הפריים הנוכחי.
signal capture_requested()
## ניהול הניגון.
signal play_requested()
signal stop_requested()
## מעבר לפריים הבא או הקודם.
signal next_frame_requested()
signal previous_frame_requested()
## בחירה ידנית של פריים ברצועה (הפריימים סופרים מ-1).
signal frame_selected(frame_index: int)
## שינוי קצב הניגון.
signal fps_changed(fps: int)
## Placeholder: מצב האינטרפולציה (Stepped / Spline) - עדיין לא פעיל.
signal interpolation_toggled(spline: bool)
## Placeholder: בצל (Onion Skin) - עדיין לא פעיל.
signal onion_toggled(enabled: bool)

## גובה החלון - השורש מזיז לפיו את מה שיושב בתחתית המסך.
const PANEL_HEIGHT := 186.0
## מספר הפריימים ברצועה.
const FRAME_COUNT := 24
## גודל משבצת פריים ברצועה.
const FRAME_CELL_SIZE := Vector2(104, 76)

## צבעי משבצת הפריים: רגיל, ריחוף, הפריים הנוכחי, וסימן "מוקלט".
const CELL_BG := Color(0.16, 0.18, 0.21, 0.95)
const CELL_HOVER := Color(0.23, 0.27, 0.32, 0.95)
const CELL_CURRENT_BG := Color(0.27, 0.23, 0.12, 0.98)
const GOLD := Color(0.98, 0.78, 0.25)
const RECORDED_COLOR := Color(0.32, 0.85, 0.45)

@onready var _capture_button: Button = $Layout/Controls/CaptureButton
@onready var _previous_button: Button = $Layout/Controls/PreviousButton
@onready var _play_button: Button = $Layout/Controls/PlayButton
@onready var _stop_button: Button = $Layout/Controls/StopButton
@onready var _next_button: Button = $Layout/Controls/NextButton
@onready var _interpolation_button: Button = $Layout/Controls/InterpolationButton
@onready var _onion_button: Button = $Layout/Controls/OnionButton
@onready var _fps_option: OptionButton = $Layout/Controls/FpsOption
@onready var _frames_box: HBoxContainer = $Layout/Filmstrip/Frames

## הכפתור של כל פריים ברצועה.
var _cells: Array[Button] = []
## הסימן הקטן שמראה שהפריים הוקלט.
var _record_marks: Array[Panel] = []
## אילו פריימים הוקלטו.
var _recorded: Array[bool] = []
## הפריים הנוכחי (1 עד FRAME_COUNT).
var _current_frame := 1
## Placeholder: מתגי המצב שעדיין לא משפיעים על הניגון.
var _spline := false
var _onion := false


func _ready() -> void:
	_build_fps_choices()
	_build_frames()
	_connect_buttons()
	set_current_frame(1)
	set_playing(false)
	_refresh_texts()


# ------------------------------------------------------------------ בנייה

func _connect_buttons() -> void:
	_capture_button.pressed.connect(func() -> void: capture_requested.emit())
	_previous_button.pressed.connect(func() -> void: previous_frame_requested.emit())
	_play_button.pressed.connect(func() -> void: play_requested.emit())
	_stop_button.pressed.connect(func() -> void: stop_requested.emit())
	_next_button.pressed.connect(func() -> void: next_frame_requested.emit())
	_interpolation_button.pressed.connect(_on_interpolation_pressed)
	_onion_button.pressed.connect(_on_onion_pressed)
	_fps_option.item_selected.connect(_on_fps_selected)


## ממלא את רשימת קצבי הניגון ובוחר את ברירת המחדל (12 פריימים בשנייה).
func _build_fps_choices() -> void:
	_fps_option.clear()
	for value in TimelineManager.FPS_CHOICES:
		_fps_option.add_item("%d פריימים בשנייה" % value, value)
	var index := TimelineManager.FPS_CHOICES.find(TimelineManager.DEFAULT_FPS)
	if index >= 0:
		_fps_option.select(index)


## בונה משבצת אחת לכל פריים ברצועה, עם סימן קטן לפריים מוקלט.
func _build_frames() -> void:
	for child in _frames_box.get_children():
		_frames_box.remove_child(child)
		child.queue_free()
	_cells.clear()
	_record_marks.clear()
	_recorded.clear()

	var group := ButtonGroup.new()
	for index in range(1, FRAME_COUNT + 1):
		var cell := Button.new()
		cell.name = "Frame%d" % index
		cell.custom_minimum_size = FRAME_CELL_SIZE
		cell.toggle_mode = true
		cell.button_group = group
		cell.focus_mode = Control.FOCUS_NONE
		cell.text = str(index)
		cell.add_theme_font_size_override("font_size", 18)
		cell.tooltip_text = "פריים %d" % index
		cell.pressed.connect(_on_cell_pressed.bind(index))
		_frames_box.add_child(cell)

		var mark := Panel.new()
		mark.name = "Recorded"
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		mark.offset_left = -20.0
		mark.offset_top = 6.0
		mark.offset_right = -6.0
		mark.offset_bottom = 20.0
		var mark_style := StyleBoxFlat.new()
		mark_style.bg_color = RECORDED_COLOR
		mark_style.set_corner_radius_all(7)
		mark.add_theme_stylebox_override("panel", mark_style)
		mark.visible = false
		cell.add_child(mark)

		_cells.append(cell)
		_record_marks.append(mark)
		_recorded.append(false)

	_refresh_all_cells()


# ------------------------------------------------------------------ עדכון מהשורש

## מדגיש את הפריים הנוכחי ברצועה וגולל אליו.
func set_current_frame(frame_index: int) -> void:
	_current_frame = clampi(frame_index, 1, FRAME_COUNT)
	for index in _cells.size():
		_cells[index].set_pressed_no_signal(index + 1 == _current_frame)
	_refresh_all_cells()
	_scroll_to_current()


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


## מעדכן את כפתורי הניגון לפי המצב.
func set_playing(playing: bool) -> void:
	_play_button.disabled = playing
	_stop_button.disabled = not playing


## קצב הניגון שנבחר כרגע.
func get_fps() -> int:
	if _fps_option.selected < 0:
		return TimelineManager.DEFAULT_FPS
	return _fps_option.get_item_id(_fps_option.selected)


## הפריים הנוכחי שמוצג ברצועה.
func get_current_frame() -> int:
	return _current_frame


## מספר המשבצות שנבנו ברצועה.
func get_cell_count() -> int:
	return _cells.size()


## האם הפריים מסומן כמוקלט.
func is_frame_recorded(frame_index: int) -> bool:
	return _recorded[clampi(frame_index, 1, FRAME_COUNT) - 1]


## Placeholder: האם מצב האינטרפולציה הוא Spline.
func is_spline_mode() -> bool:
	return _spline


## Placeholder: האם הבצל דלוק.
func is_onion_skin() -> bool:
	return _onion


# ------------------------------------------------------------------ פנימי

func _on_cell_pressed(frame_index: int) -> void:
	set_current_frame(frame_index)
	frame_selected.emit(frame_index)


func _on_fps_selected(index: int) -> void:
	fps_changed.emit(_fps_option.get_item_id(index))


func _on_interpolation_pressed() -> void:
	_spline = not _spline
	_refresh_texts()
	interpolation_toggled.emit(_spline)


func _on_onion_pressed() -> void:
	_onion = not _onion
	_refresh_texts()
	onion_toggled.emit(_onion)


## מעדכן את הכיתוב של מתגי ה-Placeholder בלבד (שאר הכפתורים קבועים).
func _refresh_texts() -> void:
	_interpolation_button.text = "אינטרפולציה: Spline" if _spline else "אינטרפולציה: Stepped"
	_onion_button.text = "בצל: פועל" if _onion else "בצל: כבוי"


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


func _make_cell_style(current: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if current:
		style.bg_color = CELL_CURRENT_BG
	elif hover:
		style.bg_color = CELL_HOVER
	else:
		style.bg_color = CELL_BG
	style.set_corner_radius_all(8)
	style.content_margin_left = 6.0
	style.content_margin_top = 6.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 6.0
	if current:
		style.set_border_width_all(3)
		style.border_color = GOLD
	return style


## גולל את הרצועה כך שהפריים הנוכחי יימצא בערך במרכזה.
func _scroll_to_current() -> void:
	if _cells.is_empty():
		return
	var scroll := _frames_box.get_parent() as ScrollContainer
	if scroll == null:
		return
	var cell: Button = _cells[_current_frame - 1]
	var target := cell.position.x - scroll.size.x * 0.5 + cell.size.x * 0.5
	scroll.scroll_horizontal = int(maxf(target, 0.0))
