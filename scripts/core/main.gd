class_name StudioMain
extends Node3D
## השורש של הסטודיו.
##
## כאן תלויים המנועים השונים, כל אחד בשלב שלו:
##   מנוע ההצבה (placement) - גרירת כרטיס מהבנק אל תוך העולם
##   מנוע הבחירה (selection) - בחירת עצם בודד או קבוצה והזזתם בגיזמו
##   בקרות העצם (object_controls) - אייקוני עריכה משני צידי העצם הנבחר
##   חלונות הצד - בנק האסטים וההסבר, נפתחים מכפתורים קטנים בפינות
##   מנוע התאורה (lighting) - שלב מאוחר יותר
##   ציר הזמן ולכידת הפריימים (timeline) - שלב מאוחר יותר
##   שמירה/טעינה (project_io) - שלב מאוחר יותר

const CameraRigScript := preload("res://scripts/core/camera_rig.gd")
const LibraryScript := preload("res://scripts/core/asset_library.gd")
const AssetBankScript := preload("res://scripts/ui/asset_bank.gd")
const PlacementScript := preload("res://scripts/core/placement.gd")
const SelectionScript := preload("res://scripts/core/selection.gd")
const GizmoScript := preload("res://scripts/core/move_gizmo.gd")
const DropAreaScript := preload("res://scripts/ui/world_drop_area.gd")
const ObjectControlsScript := preload("res://scripts/ui/object_controls.gd")
const SidePanelButtonScript := preload("res://scripts/ui/side_panel_button.gd")
const MaterialPanelScript := preload("res://scripts/ui/material_panel.gd")
const TimelineManagerScript := preload("res://scripts/core/timeline_manager.gd")
const TimelinePanelScript := preload("res://scripts/ui/timeline_panel.gd")

## כל האובייקטים שהמשתמש הציב יושבים תחת הצומת הזה.
@onready var props_root: Node3D = $World/Props
## כל גופי התאורה שהמשתמש הציב יושבים תחת הצומת הזה.
@onready var lights_root: Node3D = $World/Lights
## רוחות הרפאים של הבצל (Onion Skin) נולדות תחת הצומת הזה.
@onready var onion_ghosts: Node3D = $World/OnionGhosts
## שורש העולם - כל ההצמדות לגריד מחושבות ממנו.
@onready var build_root: Node3D = $World
@onready var camera_rig: CameraRigScript = $CameraRig
@onready var asset_bank: AssetBankScript = $UI/AssetBank
@onready var drop_area: DropAreaScript = $UI/WorldDropArea
@onready var placement: PlacementScript = $Placement
@onready var selection: SelectionScript = $Selection
@onready var move_gizmo: GizmoScript = $MoveGizmo
@onready var status_label: Label = $UI/StatusLabel
@onready var object_controls: ObjectControlsScript = $UI/ObjectControls
@onready var selection_box: SelectionBox = $UI/SelectionBox
@onready var help_panel: PanelContainer = $UI/HelpPanel
@onready var bank_button: SidePanelButtonScript = $UI/BankButton
@onready var help_button: SidePanelButtonScript = $UI/HelpButton
@onready var world_button: SidePanelButtonScript = $UI/WorldButton
@onready var camera_button: SidePanelButtonScript = $UI/CameraButton
@onready var timeline_button: SidePanelButtonScript = $UI/TimelineButton
@onready var material_panel: MaterialPanelScript = $UI/MaterialPanel
@onready var timeline: TimelineManagerScript = $Timeline
@onready var timeline_panel: TimelinePanelScript = $UI/TimelinePanel

## בנק האסטים של הפרויקט.
var library: LibraryScript = null
## מיקומי הרכיבים שיושבים בתחתית המסך (כפתורי הפינה וקטע המצב) לפני
## שציר הזמן נפתח - כדי להחזיר אותם בדיוק למקומם כשהוא נסגר.
var _bottom_offsets := {}
## האם הגרירה האחרונה של הגיזמו בוטלה (קליק ימני). אם כן - הצילום
## האוטומטי לא נקלט בסוף הגרירה.
var _gizmo_drag_cancelled := false


func _ready() -> void:
	library = LibraryScript.new()
	asset_bank.setup(library)
	placement.setup(library, camera_rig.camera, props_root)
	selection.setup(camera_rig.camera, camera_rig, props_root, move_gizmo, placement)
	selection.set_box(selection_box)
	selection.selection_changed.connect(_on_selection_changed)
	# גרירה מהבנק: כל תזוזה מזיזה את אובייקט הרפאים על הרצפה.
	drop_area.drag_moved.connect(placement.show_ghost_at)
	drop_area.asset_dropped.connect(_on_asset_dropped)
	drop_area.drag_cancelled.connect(placement.cancel_drag)
	# אייקוני העריכה של העצם הנבחר - משני צדדיו.
	object_controls.setup(move_gizmo, camera_rig.camera, selection)
	object_controls.confirmed.connect(_on_toolbar_confirm)
	object_controls.duplicate_requested.connect(_on_toolbar_duplicate)
	object_controls.delete_requested.connect(_on_toolbar_delete)
	object_controls.materials_requested.connect(_on_materials_requested)
	move_gizmo.mode_changed.connect(_on_gizmo_mode_changed)
	# צילום אוטומטי: ברגע שהמשתמש מסיים הזזה או סיבוב של עצם נבחר.
	move_gizmo.drag_cancelled.connect(_on_gizmo_drag_cancelled)
	move_gizmo.drag_finished.connect(_on_gizmo_drag_finished)
	# חלונות הצד סגורים בהתחלה - נפתחים מהכפתורים שבפינות.
	help_panel.visible = false
	asset_bank.visible = false
	material_panel.visible = false
	timeline_panel.visible = false
	_capture_bottom_offsets()
	bank_button.pressed.connect(_on_bank_button)
	help_button.pressed.connect(_on_help_button)
	# כפתורי הפינות: בחירת עולם ומצב מצלמה ייבנו בהמשך - בינתיים הם רק
	# מסבירים מה יקרה. כפתור ציר הזמן כבר פותח את הציר בתחתית המסך.
	world_button.pressed.connect(_on_world_button)
	camera_button.pressed.connect(_on_camera_button)
	timeline_button.pressed.connect(_on_timeline_button)
	_setup_timeline()
	_on_selection_changed([])


## כפתור הכיסא - פותח או סוגר את בנק האסטים.
func _on_bank_button() -> void:
	_toggle_panel(asset_bank)


## כפתור סימן השאלה - פותח או סוגר את חלון ההסבר.
func _on_help_button() -> void:
	_toggle_panel(help_panel)


## כפתור בחירת העולם (שמאל למעלה) - הפיצ'ר ייבנה בהמשך.
func _on_world_button() -> void:
	status_label.text = "בחירת עולם תיפתח בהמשך - בינתיים בונים בעולם הזה"


## כפתור מצב המצלמה (ימין למטה) - הפיצ'ר ייבנה בהמשך.
func _on_camera_button() -> void:
	status_label.text = "מצב מצלמה ייפתח בהמשך - בינתיים המצלמה נשלטת בעכבר ובמקלדת"


## כפתור ציר הזמן (ימין למטה) - פותח או סוגר את הציר בתחתית המסך.
## הסמליל של הכפתור מתחלף (סגור / פתוח) דרך המנגנון הקיים.
func _on_timeline_button() -> void:
	var open := not timeline_button.is_timeline_open()
	timeline_button.set_timeline_open(open)
	_toggle_timeline(open)
	if open:
		status_label.text = "ציר הזמן פתוח - בחרו עצם וצלמו פריים ב'לכידת פריים'"
	else:
		status_label.text = "ציר הזמן סגור"


## מחבר את חלון ציר הזמן למנוע האנימציה ולמנוע הבחירה.
func _setup_timeline() -> void:
	timeline.setup(selection, onion_ghosts)
	timeline_panel.capture_requested.connect(_on_timeline_capture)
	timeline_panel.play_requested.connect(_on_timeline_play)
	timeline_panel.stop_requested.connect(_on_timeline_stop)
	timeline_panel.next_frame_requested.connect(_on_timeline_next_frame)
	timeline_panel.previous_frame_requested.connect(_on_timeline_previous_frame)
	timeline_panel.frame_selected.connect(_on_timeline_frame_selected)
	timeline_panel.reset_requested.connect(_on_timeline_reset)
	timeline_panel.next_key_requested.connect(_on_timeline_next_key)
	timeline_panel.previous_key_requested.connect(_on_timeline_previous_key)
	timeline_panel.fps_changed.connect(_on_timeline_fps_changed)
	timeline_panel.interpolation_toggled.connect(timeline.set_spline_mode)
	timeline_panel.onion_toggled.connect(timeline.set_onion_skin)
	timeline_panel.auto_frame_toggled.connect(timeline.set_auto_frame)
	timeline.frame_changed.connect(_on_timeline_frame_changed)
	timeline.state_changed.connect(_on_timeline_state_changed)
	timeline_panel.set_current_frame(timeline.current_frame)
	timeline_panel.set_playing(timeline.playing)
	timeline.set_fps(timeline_panel.get_fps())


## מציג או מסתיר את חלון ציר הזמן. בזמן שהוא פתוח מזיזים את מה שיושב
## בתחתית המסך כלפי מעלה, כדי שכפתור הסגירה וקטע המצב יישארו נגישים.
func _toggle_timeline(open: bool) -> void:
	_set_bottom_ui_lifted(open)
	if not open:
		timeline.stop()
		timeline_panel.visible = false
		return
	timeline_panel.visible = true
	timeline_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(timeline_panel, "modulate", Color.WHITE, 0.15)


## שומר את מיקומי כפתורי הפינה התחתונים ואת קטע המצב, כדי להחזיר אותם
## בדיוק למקומם כשציר הזמן נסגר.
func _capture_bottom_offsets() -> void:
	_bottom_offsets = {
		"timeline_top": timeline_button.offset_top,
		"timeline_bottom": timeline_button.offset_bottom,
		"camera_top": camera_button.offset_top,
		"camera_bottom": camera_button.offset_bottom,
		"status_top": status_label.offset_top,
		"status_bottom": status_label.offset_bottom,
	}


## מזיז את כפתורי הפינה התחתונים ואת קטע המצב מעל חלון ציר הזמן.
func _set_bottom_ui_lifted(lifted: bool) -> void:
	if _bottom_offsets.is_empty():
		return
	var shift := -(TimelinePanelScript.PANEL_HEIGHT + 8.0) if lifted else 0.0
	timeline_button.offset_top = _bottom_offsets["timeline_top"] + shift
	timeline_button.offset_bottom = _bottom_offsets["timeline_bottom"] + shift
	camera_button.offset_top = _bottom_offsets["camera_top"] + shift
	camera_button.offset_bottom = _bottom_offsets["camera_bottom"] + shift
	status_label.offset_top = _bottom_offsets["status_top"] + shift
	status_label.offset_bottom = _bottom_offsets["status_bottom"] + shift


## מציג או מסתיר חלון צד, עם הופעה חלקה קצרה.
func _toggle_panel(panel: Control) -> void:
	if panel.visible:
		panel.visible = false
		return
	panel.visible = true
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(panel, "modulate", Color.WHITE, 0.15)


## המשתמש שחרר כרטיס מהבנק מעל העולם - העצם נוצר במקום העכבר ונבחר מיד,
## כך שהוא מסומן במתאר צהוב ומוכן להזזה.
func _on_asset_dropped(asset_id: StringName, screen_position: Vector2) -> void:
	var prop := placement.finish_drop(asset_id, screen_position)
	if prop == null:
		return
	selection.select(prop)


## הנח - מניח את העצם במקום ומסיים את הבחירה.
func _on_toolbar_confirm() -> void:
	selection.select(null)


## שכפול - יוצר עותק מוצק של העצם הנבחר.
func _on_toolbar_duplicate() -> void:
	selection.duplicate_selected()


## מחיקה - מוחק את העצם הנבחר.
func _on_toolbar_delete() -> void:
	selection.delete_selected()


## ארגז הכלים - פותח את חלון החומריות של העצם הנבחר (כרגע: שולחנות).
func _on_materials_requested() -> void:
	var prop := selection.get_selected()
	if prop == null:
		return
	if not prop.has_method("get_model"):
		return
	var model: Node3D = prop.get_model()
	if model == null or not is_instance_valid(model) or not model.has_method("get_material_parts"):
		status_label.text = "עיצוב חומרים זמין לשולחנות - בחרו שולחן"
		return
	material_panel.open_for(prop)


## מה שכתוב למטה על המסך - מה נבחר ומה אפשר לעשות איתו.
func _on_selection_changed(items: Array) -> void:
	# חלון החומריות נסגר עם ביטול אם השולחן שנערך כבר לא נבחר.
	if material_panel != null and material_panel.is_open():
		if not items.has(material_panel.get_prop()):
			material_panel.cancel_and_close()
	# שים לב: הבצל מתעדכן לבד - הציר מאזין לשינוי הבחירה בעצמו.
	if items.is_empty():
		status_label.text = "גררו כרטיס מהבנק אל העולם כדי להציב עצם. Shift + קליק או גרירה לבחירת כמה עצמים"
		return
	var mode_text := "חצים להזזה"
	var snap_text := "Shift להצמדה לרשת (0.5 מ')"
	if move_gizmo.get_mode() == GizmoScript.GizmoMode.ROTATE:
		mode_text = "טבעות לסיבוב"
		snap_text = "Shift לסיבוב ב-15 מעלות"
	elif move_gizmo.get_mode() == GizmoScript.GizmoMode.SCALE:
		mode_text = "גרירת הנדל משנה גודל"
		snap_text = "Shift מצמד לרבע מטר"
	if items.size() > 1:
		status_label.text = "נבחרו %d עצמים - %s, %s, קליק ימני לביטול" % [items.size(), mode_text, snap_text]
		return
	var prop: Node3D = items[0]
	status_label.text = "נבחר: %s  -  %s, %s, Shift + קליק לבחירת עוד עצמים" % [prop.display_name, mode_text, snap_text]


func _on_gizmo_mode_changed(_new_mode: int) -> void:
	if selection != null and selection.selection_count() > 0:
		_on_selection_changed(selection.get_selection())


# ------------------------------------------------------------------ ציר הזמן

## לכידת פריים - מקליט את העצים הנבחרים בפריים הנוכחי.
func _on_timeline_capture() -> void:
	var props := selection.get_selection()
	if props.is_empty():
		status_label.text = "בחרו עצם כדי להקליט פריים"
		return
	var recorded := timeline.capture(props)
	if recorded == 0:
		status_label.text = "לא נמצא עצם להקלטה"
		return
	var frame := timeline.current_frame
	timeline_panel.set_frame_recorded(frame, timeline.has_key(frame))
	status_label.text = "נקלט פריים %d (%d עצמים)" % [frame, recorded]


## ניגון הציר מהפריים הראשון.
func _on_timeline_play() -> void:
	if not timeline.has_any_keys():
		status_label.text = "אין עדיין פריימים מוקלטים - בחרו עצם וצלמו פריים"
		return
	timeline.play()
	status_label.text = "מנגן את הציר - עצרו בכל רגע"


## עצירת הניגון.
func _on_timeline_stop() -> void:
	timeline.stop()
	status_label.text = "הניגון נעצר בפריים %d" % timeline.current_frame


## חזרה לפריים הראשון - בלי למחוק שום הקלטה.
func _on_timeline_reset() -> void:
	timeline.stop()
	timeline.set_current_frame(1)
	status_label.text = "חזרה לפריים הראשון"


## מעבר לפריים הבא.
func _on_timeline_next_frame() -> void:
	timeline.stop()
	timeline.next_frame()


## מעבר לפריים הקודם.
func _on_timeline_previous_frame() -> void:
	timeline.stop()
	timeline.previous_frame()


## המשתמש בחר פריים ברצועה - העולם קופץ לתנוחה שהוקלטה בו.
func _on_timeline_frame_selected(frame_index: int) -> void:
	timeline.stop()
	timeline.set_current_frame(frame_index)


func _on_timeline_fps_changed(fps: int) -> void:
	timeline.set_fps(fps)


func _on_timeline_frame_changed(frame_index: int) -> void:
	timeline_panel.set_current_frame(frame_index)


func _on_timeline_state_changed(playing: bool) -> void:
	timeline_panel.set_playing(playing)


# ------------------------------------------------------------------ מקלדת

## קיצורי המקלדת של ציר הזמן. הם מטופלים רק אם שום דבר אחר לא צרך את המקש,
## כדי לא לגנוב מקשים מהממשק.
##   ← / →  פריים קודם / הבא        , / .  Keyframe קודם / הבא
##   I      לכידת פריים             רווח   נגן / עצור
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("timeline_previous_frame"):
		_on_timeline_previous_frame()
	elif event.is_action_pressed("timeline_next_frame"):
		_on_timeline_next_frame()
	elif event.is_action_pressed("timeline_previous_key"):
		_on_timeline_previous_key()
	elif event.is_action_pressed("timeline_next_key"):
		_on_timeline_next_key()
	elif event.is_action_pressed("capture_frame"):
		_on_timeline_capture()
	elif event.is_action_pressed("play_pause"):
		_on_timeline_play_pause()
	else:
		return
	get_viewport().set_input_as_handled()


## מעבר ל-Keyframe הקודם - הפריים הקרוב שיש בו הקלטה.
func _on_timeline_previous_key() -> void:
	if not timeline.has_any_keys():
		status_label.text = "אין עדיין פריימים מוקלטים - בחרו עצם וצלמו פריים"
		return
	timeline.stop()
	var before := timeline.current_frame
	timeline.previous_key()
	if timeline.current_frame == before:
		status_label.text = "אין Keyframe נוסף אחורה"
	else:
		status_label.text = "Keyframe קודם - פריים %d" % timeline.current_frame


## מעבר ל-Keyframe הבא - הפריים הקרוב שיש בו הקלטה.
func _on_timeline_next_key() -> void:
	if not timeline.has_any_keys():
		status_label.text = "אין עדיין פריימים מוקלטים - בחרו עצם וצלמו פריים"
		return
	timeline.stop()
	var before := timeline.current_frame
	timeline.next_key()
	if timeline.current_frame == before:
		status_label.text = "אין Keyframe נוסף קדימה"
	else:
		status_label.text = "Keyframe הבא - פריים %d" % timeline.current_frame


## רווח: מתחיל ניגון, ואם כבר מנגן - עוצר אותו.
func _on_timeline_play_pause() -> void:
	if timeline.playing:
		_on_timeline_stop()
	else:
		_on_timeline_play()


# -------------------------------------------------------------- צילום אוטומטי

## הגרירה בוטלה בקליק ימני - לא מקליטים בסיומה.
func _on_gizmo_drag_cancelled() -> void:
	_gizmo_drag_cancelled = true


## סוף הזזה או סיבוב של עצם נבחר: כשהצילום האוטומטי דלוק הפריים נקלט לבד.
## גם לחיצה על ידית בלי הזזה מסיימת גרירה ולכן נקלטת - זו ההתנהגות המקובלת
## של צילום אוטומטי.
func _on_gizmo_drag_finished() -> void:
	var cancelled := _gizmo_drag_cancelled
	_gizmo_drag_cancelled = false
	if cancelled or not timeline.auto_frame:
		return
	if selection.selection_count() == 0:
		return
	_on_timeline_capture()
