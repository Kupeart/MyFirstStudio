class_name TestTimeline
extends Node
## בדיקות לציר הזמן: הקלטת פריים, ניגון במצב Stepped, מעבר בין פריימים,
## וממשק הרצועה (בניית 24 המשבצות וסימון הפריים הנוכחי).
##
## הבדיקות קוראות ל-_process() של המנהל ישירות, כדי שהניגון יהיה
## דטרמיניסטי ולא יהיה תלוי בקצב הפריימים של הריצה.

const PropScript := preload("res://scripts/core/prop.gd")
const TimelineManagerScript := preload("res://scripts/core/timeline_manager.gd")
const TimelinePanelScript := preload("res://scripts/ui/timeline_panel.gd")
const SelectionScript := preload("res://scripts/core/selection.gd")

const PANEL_SCENE := "res://scenes/ui/timeline_panel.tscn"


## יוצר עצם (Prop) עם מודל קובייה פשוטה ומכניס אותו לעץ.
func _make_prop(parent: Node3D, name_hint: String) -> Prop:
	var model := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mesh.mesh = box
	model.add_child(mesh)
	var prop: Prop = PropScript.new()
	parent.add_child(prop)
	prop.setup(StringName(name_hint), "בדיקה", model)
	return prop


## יוצר מנהל ציר זמן ומצרף אותו לבדיקה עצמה. המנהל נכנס לעץ, ולכן
## הוא משוחרר יחד עם הצומת של הבדיקה בסוף הריצה - בלי לדלוף אובייקטים.
func _make_manager() -> TimelineManager:
	var manager: TimelineManager = TimelineManagerScript.new()
	add_child(manager)
	return manager


func test_capture_records_and_restores_transform() -> void:
	var root := Node3D.new()
	add_child(root)
	var prop := _make_prop(root, "captured")
	var manager := _make_manager()

	prop.global_position = Vector3(1.0, 0.0, 2.0)
	manager.capture([prop])
	assert(manager.has_key(1), "הפריים לא סומן כמוקלט")
	assert(manager.is_prop_keyed(prop), "העצם לא נרשם כמוקלט")

	prop.global_position = Vector3(9.0, 9.0, 9.0)
	manager.apply_frame(1)
	assert(
		prop.global_position.distance_to(Vector3(1.0, 0.0, 2.0)) < 0.001,
		"התנוחה המוקלטת לא הוחזרה"
	)
	root.free()


func test_capture_without_props_records_nothing() -> void:
	var manager := _make_manager()
	assert(manager.capture([]) == 0, "הקלטה בלי עצים צריכה להחזיר 0")
	assert(not manager.has_any_keys(), "ציר ריק לא אמור להיחשב כמוקלט")


func test_stepped_playback_holds_previous_keyframe() -> void:
	var root := Node3D.new()
	add_child(root)
	var prop := _make_prop(root, "stepped")
	var manager := _make_manager()

	# תנוחה A בפריים 1, ותנוחה B בפריים 5.
	# הסדר נכון הוא קודם גוללים לפריים, ואז מזיזים את העצם וצולמים -
	# כי גלילה לפריים מחזירה את העצם לתנוחה שהוקלטה בו.
	manager.set_current_frame(1)
	prop.global_position = Vector3(0.0, 0.0, 0.0)
	manager.capture([prop])

	manager.set_current_frame(5)
	prop.global_position = Vector3(5.0, 0.0, 0.0)
	manager.capture([prop])

	# בין ההקלטות - מחזיקים את A.
	prop.global_position = Vector3(100.0, 0.0, 0.0)
	manager.apply_frame(3)
	assert(prop.global_position.distance_to(Vector3.ZERO) < 0.001, "הפריים 3 לא החזיק את התנוחה של פריים 1")

	# אחרי ההקלטה השנייה - מחזיקים את B, גם בסוף הציר.
	manager.apply_frame(6)
	assert(prop.global_position.distance_to(Vector3(5.0, 0.0, 0.0)) < 0.001, "הפריים 6 לא הציג את התנוחה של פריים 5")
	manager.apply_frame(TimelineManagerScript.FRAME_COUNT)
	assert(prop.global_position.distance_to(Vector3(5.0, 0.0, 0.0)) < 0.001, "הפריים האחרון לא החזיק את ההקלטה האחרונה")
	root.free()


func test_next_and_previous_frame_move_the_cursor() -> void:
	var manager := _make_manager()
	manager.next_frame()
	assert(manager.current_frame == 2, "הפריים הבא לא קודם")
	manager.previous_frame()
	assert(manager.current_frame == 1, "הפריים הקודם לא הוחזר")
	manager.previous_frame()
	assert(manager.current_frame == 1, "אי אפשר לרדת מתחת לפריים 1")
	manager.set_current_frame(999)
	assert(
		manager.current_frame == TimelineManagerScript.FRAME_COUNT,
		"פריים מעבר לסוף הציר לא הוגבל"
	)


func test_playback_advances_at_the_chosen_fps() -> void:
	var manager := _make_manager()
	manager.set_fps(10)
	manager.play()
	assert(manager.playing, "הניגון לא התחיל")
	assert(manager.current_frame == 1, "הניגון לא מתחיל מהפריים הראשון")

	manager._process(0.1)
	assert(manager.current_frame == 2, "הפריים לא התקדם לפי קצב הניגון")
	manager._process(0.25)
	assert(manager.current_frame == 4, "הניגון לא התקדם מספיק בפריים אחד ארוך")


func test_playback_stops_at_the_last_frame() -> void:
	var manager := _make_manager()
	manager.set_fps(10)
	manager.play()
	for step in TimelineManagerScript.FRAME_COUNT + 5:
		manager._process(0.1)
	assert(not manager.playing, "הניגון לא נעצר בסוף הציר")
	assert(
		manager.current_frame == TimelineManagerScript.FRAME_COUNT,
		"הניגון לא עצר בפריים האחרון"
	)


func test_play_clears_the_selection() -> void:
	var root := Node3D.new()
	add_child(root)
	var prop := _make_prop(root, "selected")
	var selection: StudioSelection = SelectionScript.new()
	add_child(selection)
	selection.select(prop)
	assert(selection.selection_count() == 1, "העצם לא נבחר")

	var manager := _make_manager()
	manager.setup(selection)
	manager.capture([prop])
	manager.play()
	assert(selection.selection_count() == 0, "הניגון לא שיחרר את הבחירה")
	root.free()


func test_clear_removes_all_keys() -> void:
	var root := Node3D.new()
	add_child(root)
	var prop := _make_prop(root, "cleared")
	var manager := _make_manager()
	manager.capture([prop])
	assert(manager.has_any_keys(), "ההקלטה לא נרשמה")

	manager.clear()
	assert(not manager.has_any_keys(), "האיפוס לא ניקה את ההקלטות")
	assert(not manager.has_key(1), "הפריים נשאר מסומן אחרי איפוס")
	assert(manager.current_frame == 1, "האיפוס לא החזיר לפריים הראשון")
	root.free()


func test_panel_builds_all_frame_cells() -> void:
	var panel: TimelinePanel = load(PANEL_SCENE).instantiate()
	add_child(panel)
	assert(
		panel.get_cell_count() == TimelineManagerScript.FRAME_COUNT,
		"הרצועה לא בנתה את כל הפריימים"
	)
	assert(panel.get_fps() == TimelineManagerScript.DEFAULT_FPS, "קצב ברירת המחדל אינו 12")
	assert(panel.get_current_frame() == 1, "הרצועה לא מתחילה בפריים הראשון")

	panel.set_current_frame(5)
	assert(panel.get_current_frame() == 5, "הפריים הנוכחי לא התעדכן")
	var cell: Button = panel.get_node("Layout/Filmstrip/Frames/Frame5")
	var style := cell.get_theme_stylebox("normal") as StyleBoxFlat
	assert(
		style != null and style.border_width_top > 0,
		"לפריים הנוכחי אין מסגרת מוזהבת"
	)

	panel.set_frame_recorded(5, true)
	assert(panel.is_frame_recorded(5), "סימן ההקלטה לא הופיע")
	assert(not panel.is_frame_recorded(4), "סימן ההקלטה הופיע בפריים הלא נכון")
	panel.free()


func test_panel_placeholder_toggles_only_change_their_label() -> void:
	var panel: TimelinePanel = load(PANEL_SCENE).instantiate()
	add_child(panel)

	var interpolation: Button = panel.get_node("Layout/Controls/InterpolationButton")
	var onion: Button = panel.get_node("Layout/Controls/OnionButton")
	assert(not panel.is_spline_mode(), "מצב האינטרפולציה אמור להתחיל כ-Stepped")
	assert(not panel.is_onion_skin(), "הבצל אמור להתחיל כבוי")

	interpolation.pressed.emit()
	assert(panel.is_spline_mode(), "לחיצה על האינטרפולציה לא החליפה למצב Spline")
	assert(interpolation.text.contains("Spline"), "הכיתוב של האינטרפולציה לא התעדכן")

	onion.pressed.emit()
	assert(panel.is_onion_skin(), "לחיצה על הבצל לא הדליקה אותו")
	assert(onion.text.contains("פועל"), "הכיתוב של הבצל לא התעדכן")
	panel.free()
