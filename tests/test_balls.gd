class_name TestBalls
extends Node
## בדיקות לכדורים: רישום בעברית בבנק, זיהוי ה-shape keys שהוטבעו בקבצים,
## וידיות הגיזמו (גובה + לחיצה/מתיחה) - כולל כך שלברזל אין ידית לחיצה.

const PropScript := preload("res://scripts/core/prop.gd")
const GizmoScript := preload("res://scripts/core/move_gizmo.gd")
const LibraryScript := preload("res://scripts/core/asset_library.gd")
const SelectionScript := preload("res://scripts/core/selection.gd")
const ControlsScript := preload("res://scripts/ui/object_controls.gd")
const YamScript := preload("res://scripts/core/kador_yam.gd")
const RegelScript := preload("res://scripts/core/kador_regel.gd")
const SlimeScript := preload("res://scripts/core/kador_slime.gd")
const BarzelScript := preload("res://scripts/core/kador_barzel.gd")


## יוצר עצם (Prop) עם כדור בתוכו ומכניס לעץ - הכניסה לעץ בונה את המודל.
func _make_ball(root: Node3D, ball_script: GDScript, id: StringName) -> Array:
	var ball: Node3D = ball_script.new()
	var prop: Node3D = PropScript.new()
	prop.setup(id, "", ball)
	root.add_child(prop)
	return [prop, ball]


func test_balls_registered_with_hebrew_names() -> void:
	var library := LibraryScript.new()
	var expected := {
		&"beachball": "כדור ים",
		&"soccerball": "כדור רגל",
		&"jellyball": "כדור סליים",
		&"ironball": "כדור ברזל",
	}
	for id in expected.keys():
		assert(library.has_asset(id), "האסט '%s' חסר בבנק" % String(id))
		assert(
			library.get_asset(id).display_name == expected[id],
			"שם '%s' אינו '%s' (בפועל: '%s')" % [String(id), expected[id], library.get_asset(id).display_name]
		)


func test_balls_load_and_expose_shape_keys() -> void:
	var root := Node3D.new()
	add_child(root)
	# לשלושת הכדורים הרכים יש shape keys (השמות בקבצים אינם אחידים).
	assert((_make_ball(root, YamScript, &"beachball")[1] as Node3D).has_shape_keys(), "לכדור הים אין shape keys")
	assert((_make_ball(root, RegelScript, &"soccerball")[1] as Node3D).has_shape_keys(), "לכדור הרגל אין shape keys")
	assert((_make_ball(root, SlimeScript, &"jellyball")[1] as Node3D).has_shape_keys(), "לכדור הסליים אין shape keys")
	# כדור הברזל קשיח - בלי shape keys.
	assert(not (_make_ball(root, BarzelScript, &"ironball")[1] as Node3D).has_shape_keys(), "לכדור הברזל אין shape keys")
	root.free()


## הנתיב האמיתי של המשחק: הספרייה יוצרת את הכדור מהמזהה של קובץ המודל,
## וחייבת להחזיר כדור עם ממשק ה-shape keys (ולא מודל GLB גולמי).
func test_library_instantiates_ball_wrappers() -> void:
	var library := LibraryScript.new()
	for id in [&"beachball", &"soccerball", &"jellyball", &"ironball"]:
		var instance: Node3D = library.instantiate_def(library.get_asset(id))
		assert(instance != null, "הספרייה לא הצליחה ליצור את '%s'" % String(id))
		assert(instance.has_method("has_shape_keys"), "'%s' נוצר בלי ממשק הכדור" % String(id))
		assert(instance.has_method("set_squash_stretch"), "'%s' נוצר בלי ממשק הלחיצה/מתיחה" % String(id))
		instance.free()


func test_squash_stretch_is_clamped() -> void:
	var root := Node3D.new()
	add_child(root)
	var ball: Node3D = _make_ball(root, YamScript, &"beachball")[1]
	ball.set_squash_stretch(0.7)
	assert(absf(ball.get_squash_stretch() - 0.7) < 0.001, "עוצמת המתיחה לא נשמרה")
	ball.set_squash_stretch(-1.5)
	assert(absf(ball.get_squash_stretch() + 1.0) < 0.001, "העוצמה לא הוגבלה ל-1-")
	root.free()


func test_scale_handle_visible_for_all_balls() -> void:
	var root := Node3D.new()
	add_child(root)
	var scripts := [YamScript, RegelScript, SlimeScript, BarzelScript]
	var ids := [&"beachball", &"soccerball", &"jellyball", &"ironball"]
	for i in scripts.size():
		var made := _make_ball(root, scripts[i], ids[i])
		var gizmo := GizmoScript.new()
		root.add_child(gizmo)
		gizmo.set_mode(GizmoScript.GizmoMode.SCALE)
		gizmo.attach_to(made[0])
		assert(gizmo._find_ball() == made[1], "הגיזמו לא זיהה את הכדור %s" % String(ids[i]))
		var scale_handle := gizmo._handle_nodes[GizmoScript.Handle.KADOR_SCALE] as Node3D
		assert(scale_handle != null and scale_handle.visible, "ל-%s אין עיגול קנה מידה" % String(ids[i]))
		# גיזמו השולחן וגיזמו הקוביות לא מוצגים על כדור.
		assert(not gizmo._resize_root.visible, "גיזמו השולחן הוצג על כדור")
		assert(not gizmo._scale_root.visible, "גיזמו הקוביות הוצג על כדור")
	root.free()


func test_iron_ball_has_no_squash_handle() -> void:
	var root := Node3D.new()
	add_child(root)
	var made := _make_ball(root, BarzelScript, &"ironball")
	var gizmo := GizmoScript.new()
	root.add_child(gizmo)
	gizmo.set_mode(GizmoScript.GizmoMode.SCALE)
	gizmo.attach_to(made[0])
	var matich := gizmo._handle_nodes[GizmoScript.Handle.LACHITZA_MATICHAH] as Node3D
	assert(matich != null, "ידית הלחיצה/מתיחה לא נבנתה בכלל")
	assert(not matich.visible, "לכדור הברזל לא אמורה להיות ידית לחיצה/מתיחה")
	root.free()


func test_soft_ball_has_squash_handle() -> void:
	var root := Node3D.new()
	add_child(root)
	var made := _make_ball(root, SlimeScript, &"jellyball")
	var gizmo := GizmoScript.new()
	root.add_child(gizmo)
	gizmo.set_mode(GizmoScript.GizmoMode.SCALE)
	gizmo.attach_to(made[0])
	var matich := gizmo._handle_nodes[GizmoScript.Handle.LACHITZA_MATICHAH] as Node3D
	assert(matich != null and matich.visible, "לכדור הסליים אמורה להיות ידית לחיצה/מתיחה")
	root.free()


func test_ball_handles_are_pickable() -> void:
	var root := Node3D.new()
	add_child(root)
	var made := _make_ball(root, YamScript, &"beachball")
	var ball: Node3D = made[1]
	var gizmo := GizmoScript.new()
	root.add_child(gizmo)
	gizmo.set_mode(GizmoScript.GizmoMode.SCALE)
	gizmo.attach_to(made[0])
	gizmo.refresh()

	var dims: Vector3 = ball.get_dimensions()
	var radius := maxf(dims.x, dims.z) * 0.5
	var center := gizmo.global_position
	var down := Vector3(0.0, 0.0, -1.0)

	# קרן שמכוונת לנקודה על עיגול קנה המידה (על רדיוס הכדור בגובה המרכז).
	var ring_hit := gizmo._ball_handle_at(
		center + Vector3(radius, 4.0, 0.0), Vector3(0.0, -1.0, 0.0)
	)
	assert(
		ring_hit == GizmoScript.Handle.KADOR_SCALE,
		"קרן על עיגול קנה המידה לא זיהתה אותו (התקבל %d)" % ring_hit
	)

	# קרן שמכוונת לידית הלחיצה/מתיחה (מעל הכדור).
	var top := center.y + dims.y * 0.5 + GizmoScript.KADOR_HANDLE_LENGTH * 0.5
	var matich_hit := gizmo._ball_handle_at(Vector3(0.0, top, 5.0), down)
	assert(
		matich_hit == GizmoScript.Handle.LACHITZA_MATICHAH,
		"קרן על ידית הלחיצה/מתיחה לא זיהתה אותה (התקבל %d)" % matich_hit
	)

	# קרן הרחק מהידיות - לא תופסת כלום.
	var miss := gizmo._ball_handle_at(
		center + Vector3(radius * 2.5, 4.0, 0.0), Vector3(0.0, -1.0, 0.0)
	)
	assert(miss == GizmoScript.Handle.NONE, "קרן רחוקה תפסה ידית בטעות")
	root.free()


## הגיזמו של כדור יושב במרכז הכדור (כמו טבעות הסיבוב), לא על הרצפה.
func test_gizmo_centered_at_ball_center() -> void:
	var root := Node3D.new()
	add_child(root)
	var made := _make_ball(root, YamScript, &"beachball")
	var gizmo := GizmoScript.new()
	root.add_child(gizmo)
	gizmo.attach_to(made[0])
	var expected: Vector3 = (made[0] as Node3D).get_center()
	assert(
		gizmo.global_position.distance_to(expected) < 0.01,
		"הגיזמו לא יושב במרכז הכדור"
	)
	assert(gizmo.global_position.y > 0.5, "הגיזמו לא הורם למרכז הכדור")

	# גם כשמצמידים את הגיזמו ישירות לכדור (בלי Prop) - הוא עדיין במרכז.
	var direct := GizmoScript.new()
	root.add_child(direct)
	direct.attach_to(made[1])
	assert(
		direct.global_position.distance_to((made[1] as Node3D).get_center()) < 0.01,
		"הגיזמו שהוצמד ישירות לכדור לא יושב במרכזו"
	)
	root.free()


## ידית המרכז של ההזזה מזיזה את הכדור בחופשיות במישור המסך - בכל הצירים.
func test_center_handle_moves_all_axes() -> void:
	var root := Node3D.new()
	add_child(root)
	var made := _make_ball(root, YamScript, &"beachball")
	var prop: Node3D = made[0]
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 10.0)
	root.add_child(camera)
	var gizmo := GizmoScript.new()
	root.add_child(gizmo)
	gizmo.setup(camera)
	gizmo.attach_to(prop)

	var center_screen := camera.unproject_position(gizmo.global_position)
	var grab := camera.project_ray_origin(center_screen)
	var dir := camera.project_ray_normal(center_screen)
	gizmo._begin_drag(GizmoScript.Handle.GROUND, grab, dir, gizmo.global_position)
	# הזזת העכבר כלפי מעלה על המסך - הכדור צריך לעלות בגובה.
	gizmo.drag_to(center_screen + Vector2(0.0, -90.0))
	assert(prop.global_position.y > 0.05, "ידית המרכז לא הזיזה את הכדור בגובה")
	root.free()


func test_scale_drag_changes_all_dims() -> void:
	var root := Node3D.new()
	add_child(root)
	var made := _make_ball(root, YamScript, &"beachball")
	var ball: Node3D = made[1]
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 10.0)
	root.add_child(camera)
	var gizmo := GizmoScript.new()
	root.add_child(gizmo)
	gizmo.setup(camera)
	gizmo.set_mode(GizmoScript.GizmoMode.SCALE)
	gizmo.attach_to(made[0])

	var start: Vector3 = ball.get_dimensions()
	gizmo._ball = ball
	gizmo._ball_start_dims = start
	gizmo._ball_scale_start_distance = 100.0
	var center_screen := camera.unproject_position(gizmo.global_position)
	gizmo._kador_scale_drag(center_screen + Vector2(150.0, 0.0))

	var after: Vector3 = ball.get_dimensions()
	var factor := 1.5
	assert(absf(after.x - start.x * factor) < 0.01, "קנה המידה לא שינה את הרוחב")
	assert(absf(after.y - start.y * factor) < 0.01, "קנה המידה לא שינה את הגובה")
	assert(absf(after.z - start.z * factor) < 0.01, "קנה המידה לא שינה את העומק")
	root.free()


## לכדור אין עריכת חומרים: אייקון "עיצוב וחומרים" מוסתר כשבוחרים כדור,
## וגם אין לו שינוי גודל פרוצדורלי (יש לו עיגול קנה מידה אחיד).
func test_ball_hides_materials_toolbox() -> void:
	var root := Node3D.new()
	add_child(root)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0.0, 3.0, 6.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)

	var gizmo := GizmoScript.new()
	root.add_child(gizmo)

	var selection = SelectionScript.new()
	add_child(selection)
	selection.setup(camera, null, root, gizmo, null)

	var controls = ControlsScript.new()
	add_child(controls)
	controls.setup(gizmo, camera, selection)

	var made := _make_ball(root, YamScript, &"beachball")
	selection.select(made[0])
	controls._process(0.0)
	assert(controls._selection_is_ball(), "הבקרות לא זיהו שנבחר כדור")
	assert(not controls._toolbox.visible, "אייקון עיצוב וחומרים לא הוסתר לכדור")
	assert(
		not controls._selection_supports_resize(), "כדור לא אמור לקבל שינוי גודל פרוצדורלי"
	)
	root.free()


func test_squash_drag_changes_shape_keys() -> void:
	var root := Node3D.new()
	add_child(root)
	var made := _make_ball(root, RegelScript, &"soccerball")
	var ball: Node3D = made[1]
	var gizmo := GizmoScript.new()
	root.add_child(gizmo)
	gizmo.set_mode(GizmoScript.GizmoMode.SCALE)
	gizmo.attach_to(made[0])

	gizmo._ball = ball
	gizmo._ball_start_squash = 0.0
	gizmo._ball_grab_point = Vector2(0.0, 0.0)
	gizmo._lachitza_matichah_drag(Vector2(0.0, -50.0))  # גרירה מעלה = מתיחה

	var expected := clampf(50.0 * GizmoScript.KADOR_SQUASH_PER_PIXEL, -1.0, 1.0)
	assert(
		absf(ball.get_squash_stretch() - expected) < 0.001,
		"גרירת ידית הלחיצה/מתיחה לא עדכנה את העוצמה"
	)
	root.free()
