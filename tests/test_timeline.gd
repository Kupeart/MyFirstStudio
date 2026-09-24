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
		"הסרגל לא בנה את כל הפריימים"
	)
	assert(panel.get_fps() == TimelineManagerScript.DEFAULT_FPS, "קצב ברירת המחדל אינו 12")
	assert(panel.get_current_frame() == 1, "הסרגל לא מתחיל בפריים הראשון")

	panel.set_current_frame(5)
	assert(panel.get_current_frame() == 5, "הפריים הנוכחי לא התעדכן")
	var cell: Button = panel.get_node("Frames/Frame5")
	var other: Button = panel.get_node("Frames/Frame4")
	assert(cell.button_pressed, "הפריים הנוכחי לא מסומן")
	assert(not other.button_pressed, "פריים אחר מסומן בטעות")
	var current_style := cell.get_theme_stylebox("normal") as StyleBoxFlat
	var plain_style := other.get_theme_stylebox("normal") as StyleBoxFlat
	assert(
		current_style != null and current_style.border_width_left > 0,
		"לפריים הנוכחי אין מסגרת מוזהבת"
	)
	assert(
		plain_style != null and plain_style.border_width_left == 0,
		"גם לפריים שאינו נוכחי יש מסגרת"
	)

	panel.set_frame_recorded(5, true)
	assert(panel.is_frame_recorded(5), "סימן ההקלטה לא הופיע")
	assert(not panel.is_frame_recorded(4), "סימן ההקלטה הופיע בפריים הלא נכון")
	assert(cell.get_node("Recorded").visible, "סימן ההקלטה לא הוצג על הפריים")
	panel.free()


## הפריסה על הסרגל חייבת ללכת לפי הנוסחה x = (frame - 1) x frame_width.
func test_frame_x_follows_the_ruler_formula() -> void:
	var width := 65.0
	assert(TimelinePanelScript.frame_x(1, width) == 0.0, "הפריים הראשון לא מתחיל בראש הסרגל")
	assert(
		TimelinePanelScript.frame_x(2, width) == width,
		"הפריים השני לא יושב בדיוק פריים אחד ימינה"
	)
	assert(
		TimelinePanelScript.frame_x(24, width) == 23.0 * width,
		"הפריים האחרון לא מחושב לפי הנוסחה"
	)


func test_panel_toggles_swap_their_icon_and_state() -> void:
	var panel: TimelinePanel = load(PANEL_SCENE).instantiate()
	add_child(panel)

	var interpolation: TextureButton = panel.get_node("TopBar/InterpolationButton")
	var onion: TextureButton = panel.get_node("TopBar/OnionButton")
	assert(not panel.is_spline_mode(), "מצב האינטרפולציה אמור להתחיל כ-Stepped")
	assert(not panel.is_onion_skin(), "הבצל אמור להתחיל כבוי")
	var stepped_icon := interpolation.texture_normal
	var onion_off_icon := onion.texture_normal

	interpolation.pressed.emit()
	assert(panel.is_spline_mode(), "לחיצה על האינטרפולציה לא החליפה למצב Spline")
	assert(interpolation.texture_normal != stepped_icon, "האייקון של האינטרפולציה לא התחלף")

	onion.pressed.emit()
	assert(panel.is_onion_skin(), "לחיצה על הבצל לא הדליקה אותו")
	assert(onion.texture_normal != onion_off_icon, "האייקון של הבצל לא התחלף")

	interpolation.pressed.emit()
	onion.pressed.emit()
	assert(not panel.is_spline_mode(), "האינטרפולציה לא חזרה ל-Stepped")
	assert(not panel.is_onion_skin(), "הבצל לא חזר להיות כבוי")
	assert(interpolation.texture_normal == stepped_icon, "האייקון של האינטרפולציה לא חזר")
	assert(onion.texture_normal == onion_off_icon, "האייקון של הבצל לא חזר")
	panel.free()


## כל כפתור חייב אייקון אמיתי, ושני היפוכי הכיוון חייבים להיות משוקפים.
func test_panel_icon_buttons_are_wired() -> void:
	var panel: TimelinePanel = load(PANEL_SCENE).instantiate()
	add_child(panel)
	var names := [
		"ResetButton",
		"PreviousKeyButton",
		"PreviousButton",
		"PlayButton",
		"StopButton",
		"NextButton",
		"NextKeyButton",
		"CaptureButton",
		"InterpolationButton",
		"OnionButton",
		"AutoFrameButton",
	]
	for name in names:
		var button := panel.get_node("TopBar/%s" % name) as TextureButton
		assert(button != null, "הכפתור %s לא נמצא בלוח" % name)
		assert(button.texture_normal != null, "לכפתור %s אין אייקון" % name)

	assert(
		not (panel.get_node("TopBar/PreviousButton") as TextureButton).flip_h,
		"כפתור הפריים הקודם אמור להיות בכיוון המצויר באייקון"
	)
	assert(
		not (panel.get_node("TopBar/PreviousKeyButton") as TextureButton).flip_h,
		"כפתור ה-Keyframe הקודם אמור להיות בכיוון המצויר באייקון"
	)
	assert(
		(panel.get_node("TopBar/NextButton") as TextureButton).flip_h,
		"כפתור הפריים הבא לא משוקף"
	)
	assert(
		(panel.get_node("TopBar/NextKeyButton") as TextureButton).flip_h,
		"כפתור ה-Keyframe הבא לא משוקף"
	)
	assert(
		(panel.get_node("TopBar/NextButton") as TextureButton).texture_normal
		== (panel.get_node("TopBar/PreviousButton") as TextureButton).texture_normal,
		"הפריים הקודם והבא אמורים להשתמש באותו אייקון, אחד מהם משוקף"
	)
	panel.free()


func test_panel_transport_buttons_emit_their_signals() -> void:
	var panel: TimelinePanel = load(PANEL_SCENE).instantiate()
	add_child(panel)
	var fired := {"reset": false, "previous_key": false, "next_key": false}
	panel.reset_requested.connect(func() -> void: fired["reset"] = true)
	panel.previous_key_requested.connect(func() -> void: fired["previous_key"] = true)
	panel.next_key_requested.connect(func() -> void: fired["next_key"] = true)

	(panel.get_node("TopBar/ResetButton") as BaseButton).pressed.emit()
	(panel.get_node("TopBar/PreviousKeyButton") as BaseButton).pressed.emit()
	(panel.get_node("TopBar/NextKeyButton") as BaseButton).pressed.emit()
	assert(fired["reset"], "כפתור החזרה לפריים הראשון לא שלח אות")
	assert(fired["previous_key"], "כפתור ה-Keyframe הקודם לא שלח אות")
	assert(fired["next_key"], "כפתור ה-Keyframe הבא לא שלח אות")
	panel.free()


# ------------------------------------------------------------------ Spline

## מכין עצם עם שתי הקלטות: פריים 1 בתנוחה pose_a ופריים 5 בתנוחה pose_b.
## מחזיר את העצם, ואת המנהל אחרי שכבר קלט את שתי התנוחות.
func _make_two_pose_prop(root: Node3D, pose_a: Transform3D, pose_b: Transform3D) -> Dictionary:
	var prop := _make_prop(root, "spline")
	var manager := _make_manager()
	prop.global_transform = pose_a
	manager.capture([prop])
	manager.set_current_frame(5)
	prop.global_transform = pose_b
	manager.capture([prop])
	return {"prop": prop, "manager": manager}


func test_spline_interpolates_position_between_keys() -> void:
	var root := Node3D.new()
	add_child(root)
	var scene := _make_two_pose_prop(
		root,
		Transform3D(Basis(), Vector3(0.0, 0.0, 0.0)),
		Transform3D(Basis(), Vector3(4.0, 0.0, 0.0))
	)
	var manager: TimelineManager = scene["manager"]
	var prop: Node3D = scene["prop"]

	# Stepped: הפריים 3 עדיין מחזיק את התנוחה של פריים 1.
	manager.set_current_frame(3)
	assert(prop.global_position.distance_to(Vector3.ZERO) < 0.001, "Stepped לא החזיק את התנוחה הקודמת")

	# Spline: הפריים 3 יושב בדיוק באמצע הדרך.
	manager.set_spline_mode(true)
	assert(
		prop.global_position.distance_to(Vector3(2.0, 0.0, 0.0)) < 0.001,
		"מעבר Spline לא מיקם את העצם באמצע הדרך"
	)
	root.free()


func test_spline_rotates_smoothly_with_slerp() -> void:
	var root := Node3D.new()
	add_child(root)
	var scene := _make_two_pose_prop(
		root,
		Transform3D(Basis(), Vector3.ZERO),
		Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3.ZERO)
	)
	var manager: TimelineManager = scene["manager"]
	var prop: Node3D = scene["prop"]

	manager.set_current_frame(3)
	manager.set_spline_mode(true)
	var degrees := rad_to_deg(prop.rotation.y)
	assert(
		absf(degrees - 45.0) < 1.0,
		"הסיבוב במעבר Spline לא יצא חצי דרך (יצא %.1f מעלות)" % degrees
	)
	root.free()


func test_spline_holds_when_there_is_only_one_key() -> void:
	var root := Node3D.new()
	add_child(root)
	var prop := _make_prop(root, "single")
	var manager := _make_manager()
	prop.global_position = Vector3(3.0, 0.0, 0.0)
	manager.set_current_frame(1)
	manager.capture([prop])
	manager.set_spline_mode(true)

	# אין הקלטה שנייה - ההחזקה נשארת כמו במצב Stepped.
	manager.set_current_frame(20)
	assert(
		prop.global_position.distance_to(Vector3(3.0, 0.0, 0.0)) < 0.001,
		"במצב Spline עם Key יחיד התנוחה לא הוחזקה"
	)
	root.free()


func test_spline_falls_back_to_lerp_without_control_points() -> void:
	var root := Node3D.new()
	add_child(root)
	var scene := _make_two_pose_prop(
		root,
		Transform3D(Basis(), Vector3(0.0, 0.0, 0.0)),
		Transform3D(Basis(), Vector3(10.0, 0.0, 0.0))
	)
	var manager: TimelineManager = scene["manager"]
	var prop: Node3D = scene["prop"]

	# רק שתי הקלטות - אין נקודות בקרה, ולכן קו ישר. הפריים 4 = 75% מהדרך.
	manager.set_current_frame(4)
	manager.set_spline_mode(true)
	assert(
		prop.global_position.distance_to(Vector3(7.5, 0.0, 0.0)) < 0.001,
		"בלי נקודות בקרה המעבר אמור להיות קו ישר"
	)
	root.free()


# ------------------------------------------------------------ Keyframes

func test_next_and_previous_key_jump_between_recordings() -> void:
	var root := Node3D.new()
	add_child(root)
	var prop := _make_prop(root, "keyed")
	var manager := _make_manager()

	for frame in [1, 5, 9]:
		manager.set_current_frame(frame)
		prop.global_position = Vector3(float(frame), 0.0, 0.0)
		manager.capture([prop])
	manager.set_current_frame(1)

	manager.next_key()
	assert(manager.current_frame == 5, "המעבר ל-Keyframe הבא לא עצר על ההקלטה הבאה")
	manager.next_key()
	assert(manager.current_frame == 9, "המעבר הבא לא הגיע ל-Keyframe האחרון")
	manager.previous_key()
	assert(manager.current_frame == 5, "המעבר ל-Keyframe הקודם לא עבד")
	manager.previous_key()
	assert(manager.current_frame == 1, "המעבר הקודם לא הגיע ל-Keyframe הראשון")
	assert(manager.get_keyed_frames() == [1, 5, 9], "רשימת הפריימים המוקלטים לא נכונה")
	root.free()


func test_key_navigation_stops_at_the_edges() -> void:
	var root := Node3D.new()
	add_child(root)
	var prop := _make_prop(root, "edges")
	var manager := _make_manager()
	manager.set_current_frame(4)
	manager.capture([prop])

	manager.next_key()
	assert(manager.current_frame == 4, "המעבר הבא עבר את ההקלטה היחידה")
	manager.previous_key()
	assert(manager.current_frame == 4, "המעבר הקודם עבר את ההקלטה היחידה")

	manager.clear()
	manager.next_key()
	manager.previous_key()
	assert(manager.current_frame == 1, "ניווט Keyframes בלי הקלטות הזיז את הפריים")
	root.free()


func test_toggling_spline_reapplies_the_current_frame() -> void:
	var root := Node3D.new()
	add_child(root)
	var scene := _make_two_pose_prop(
		root,
		Transform3D(Basis(), Vector3(0.0, 0.0, 0.0)),
		Transform3D(Basis(), Vector3(4.0, 0.0, 0.0))
	)
	var manager: TimelineManager = scene["manager"]
	var prop: Node3D = scene["prop"]
	manager.set_current_frame(3)

	# מדמים שהמשתמש הזיז את העצם, ואז מדליקים Spline בלי לזוז -
	# הפריים חייב להיות מוחל מחדש כדי שהשינוי ייראה מיד.
	prop.global_position = Vector3(99.0, 0.0, 0.0)
	manager.set_spline_mode(true)
	assert(
		prop.global_position.distance_to(Vector3(2.0, 0.0, 0.0)) < 0.001,
		"הדלקת Spline לא החילה מיד את הפריים הנוכחי"
	)
	root.free()


# ------------------------------------------------------------------ בצל

## מכין עצם מוקלט (פריימים 1 ו-5) שנבחר בבחירה בודדת, עם מנהל שמחובר
## להורה של רוחות הרפאים. מחזיר את העצם, הבחירה והמנהל.
func _make_onion_scene(
	root: Node3D, ghost_root: Node3D, pose_a: Vector3, pose_b: Vector3
) -> Dictionary:
	var prop := _make_prop(root, "onion")
	var selection: StudioSelection = SelectionScript.new()
	root.add_child(selection)
	var manager := _make_manager()
	manager.setup(selection, ghost_root)

	prop.global_position = pose_a
	manager.capture([prop])
	manager.set_current_frame(5)
	prop.global_position = pose_b
	manager.capture([prop])
	manager.set_current_frame(1)
	selection.select(prop)
	return {"prop": prop, "selection": selection, "manager": manager}


func test_onion_shows_ghosts_of_previous_and_next_frame() -> void:
	var root := Node3D.new()
	add_child(root)
	var ghost_root := Node3D.new()
	add_child(ghost_root)
	var scene := _make_onion_scene(root, ghost_root, Vector3(1.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0))
	var manager: TimelineManager = scene["manager"]

	assert(manager.get_ghost_count() == 0, "הבצל הצייר רוחות לפני שהודלק")
	manager.set_onion_skin(true)

	# פריים 1: יש רק הבא (אין פריים 0).
	assert(manager.get_ghost_count() == 1, "בקצה הציר אמורה להיות רוח אחת בלבד")

	# פריים 3: יש גם קודם וגם הבא.
	manager.set_current_frame(3)
	assert(manager.get_ghost_count() == 2, "באמצע הציר אמורות להיות שתי רוחות")

	var prev_ghost: Node3D = ghost_root.get_node_or_null("OnionPrev")
	var next_ghost: Node3D = ghost_root.get_node_or_null("OnionNext")

	# במצב Stepped הפריים הקודם (2) והפריים הבא (4) שניהם מחזיקים את התנוחה
	# של פריים 1 - וזה בדיוק מה שהרוחות צריכות להראות.
	assert(
		prev_ghost.global_position.distance_to(Vector3(1.0, 0.0, 0.0)) < 0.001,
		"רוח הפריים הקודם לא יושבת בתנוחה של פריים 1"
	)
	assert(
		next_ghost.global_position.distance_to(Vector3(1.0, 0.0, 0.0)) < 0.001,
		"במצב Stepped רוח הפריים הבא אמורה להחזיק את ההקלטה של פריים 1"
	)

	# במצב Spline הרוחות כבר נמשכות לקראת ההקלטה הבאה: פריים 2 ברבע
	# מהדרך ופריים 4 בשלושת רבעים.
	manager.set_spline_mode(true)
	assert(
		prev_ghost.global_position.distance_to(Vector3(2.0, 0.0, 0.0)) < 0.001,
		"במצב Spline רוח הפריים הקודם לא נמשכה לקראת ההקלטה הבאה"
	)
	assert(
		next_ghost.global_position.distance_to(Vector3(4.0, 0.0, 0.0)) < 0.001,
		"במצב Spline רוח הפריים הבא לא התקדמה לקראת ההקלטה הבאה"
	)
	root.free()
	ghost_root.free()


func test_onion_ghosts_are_not_selectable_props() -> void:
	var root := Node3D.new()
	add_child(root)
	var ghost_root := Node3D.new()
	add_child(ghost_root)
	var scene := _make_onion_scene(root, ghost_root, Vector3(1.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0))
	var manager: TimelineManager = scene["manager"]
	manager.set_onion_skin(true)
	manager.set_current_frame(3)

	var ghost: Node3D = ghost_root.get_node_or_null("OnionPrev")
	assert(ghost != null, "רוח הרפאים לא נוצרה")
	assert(not ghost.is_in_group(PropScript.GROUP), "רוח הרפאים נכנסה לקבוצת העצים ולכן ניתנת לבחירה")
	assert(ghost.get_node_or_null("Body") == null, "לרוח הרפאים יש גוף פיזי - היא תיתפס בקליק")
	root.free()
	ghost_root.free()


func test_onion_clears_on_disable_and_on_deselect() -> void:
	var root := Node3D.new()
	add_child(root)
	var ghost_root := Node3D.new()
	add_child(ghost_root)
	var scene := _make_onion_scene(root, ghost_root, Vector3(1.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0))
	var manager: TimelineManager = scene["manager"]
	var selection: StudioSelection = scene["selection"]
	manager.set_onion_skin(true)
	manager.set_current_frame(3)
	assert(manager.get_ghost_count() == 2, "הרוחות לא נוצרו")
	assert(ghost_root.get_child_count() == 2, "נשארו צמתים ישנים של רוחות בעץ")

	# ביטול הבחירה מסיר את הרוחות מיד.
	selection.set_selection([])
	assert(manager.get_ghost_count() == 0, "הרוחות לא נעלמו בביטול הבחירה")

	# הפעלה מחדש ואז כיבוי הבצל.
	selection.select(scene["prop"])
	assert(manager.get_ghost_count() == 2, "הרוחות לא חזרו אחרי בחירה מחדש")
	manager.set_onion_skin(false)
	assert(manager.get_ghost_count() == 0, "הרוחות לא נעלמו בכיבוי הבצל")
	assert(ghost_root.get_child_count() == 0, "צמתי הרוחות נשארו בעץ אחרי כיבוי")
	root.free()
	ghost_root.free()


func test_onion_keeps_the_same_ghosts_across_frames() -> void:
	var root := Node3D.new()
	add_child(root)
	var ghost_root := Node3D.new()
	add_child(ghost_root)
	var scene := _make_onion_scene(root, ghost_root, Vector3(1.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0))
	var manager: TimelineManager = scene["manager"]
	manager.set_onion_skin(true)
	manager.set_current_frame(3)

	# מעבר בין פריימים רק מזיז את הרוחות - הוא לא בונה אותן מחדש.
	var prev_ghost: Node3D = ghost_root.get_node_or_null("OnionPrev")
	manager.set_current_frame(4)
	assert(manager.get_ghost_count() == 2, "מספר הרוחות השתנה במעבר פריים")
	assert(
		ghost_root.get_node_or_null("OnionPrev") == prev_ghost,
		"הרוחות נבנו מחדש במעבר פריים - בזבוז בזמן ניגון"
	)
	root.free()
	ghost_root.free()


# -------------------------------------------------------------- צילום אוטומטי

func test_auto_frame_flag_toggles() -> void:
	var manager := _make_manager()
	assert(not manager.is_auto_frame(), "הצילום האוטומטי אמור להתחיל כבוי")
	manager.set_auto_frame(true)
	assert(manager.is_auto_frame(), "הצילום האוטומטי לא נדלק")
	manager.set_auto_frame(false)
	assert(not manager.is_auto_frame(), "הצילום האוטומטי לא נכבה")


func test_panel_auto_frame_button_swaps_its_icon() -> void:
	var panel: TimelinePanel = load(PANEL_SCENE).instantiate()
	add_child(panel)
	var auto_button: TextureButton = panel.get_node("TopBar/AutoFrameButton")
	var off_icon := auto_button.texture_normal
	assert(not panel.is_auto_frame(), "הצילום האוטומטי אמור להתחיל כבוי")

	auto_button.pressed.emit()
	assert(panel.is_auto_frame(), "לחיצה על הצילום האוטומטי לא הדליקה אותו")
	assert(auto_button.texture_normal != off_icon, "האייקון של הצילום האוטומטי לא התחלף")
	panel.free()


func test_panel_spline_toggle_marks_the_manager_state() -> void:
	var manager := _make_manager()
	var panel: TimelinePanel = load(PANEL_SCENE).instantiate()
	add_child(panel)
	panel.interpolation_toggled.connect(manager.set_spline_mode)

	var interpolation: TextureButton = panel.get_node("TopBar/InterpolationButton")
	interpolation.pressed.emit()
	assert(manager.is_spline_mode(), "המעבר ל-Spline לא הגיע למנהל הציר")
	interpolation.pressed.emit()
	assert(not manager.is_spline_mode(), "החזרה ל-Stepped לא הגיעה למנהל הציר")
	panel.free()
