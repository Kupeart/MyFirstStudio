class_name TestComputerDesk
extends Node
## בדיקות לשולחן המחשב של המשתמש: שינוי גודל לפי ה-shape keys,
## תנועת הרגליים, חלקי החומר והרישום בבנק האסטים.

const DeskScript := preload("res://scripts/core/computer_desk.gd")
const PropScript := preload("res://scripts/core/prop.gd")
const LibraryScript := preload("res://scripts/core/asset_library.gd")
const GizmoScript := preload("res://scripts/core/move_gizmo.gd")


## יוצר שולחן מחשב ומכניס אותו לעץ - הכניסה לעץ בונה את הגיאומטריה.
func _make_desk(root: Node3D) -> Node3D:
	var desk: Node3D = DeskScript.new()
	root.add_child(desk)
	return desk


## התיבה התוחמת של כל השולחן במרחב המקומי של הסקריפט.
func _desk_bounds(desk: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect(desk, Transform3D.IDENTITY, boxes)
	var merged := boxes[0]
	for box in boxes:
		merged = merged.merge(box)
	return merged


func _collect(node: Node3D, xform: Transform3D, out: Array[AABB]) -> void:
	var local := xform * node.transform
	var mesh := node as MeshInstance3D
	if mesh != null and mesh.mesh != null:
		out.append(local * mesh.get_aabb())
	for child in node.get_children():
		_collect(child as Node3D, local, out)


func test_default_dimensions_match_model() -> void:
	var root := Node3D.new()
	add_child(root)
	var desk := _make_desk(root)

	var dims: Vector3 = desk.get_dimensions()
	assert(dims.x > 1.0 and dims.y > 1.0 and dims.z > 1.0, "המידות הבסיסיות לא נמדדו מהמודל")
	# התיבה התוחמת אחרי האפייה תואמת בדיוק למידות - בלי ניפוח של blend shapes.
	var bounds := _desk_bounds(desk)
	assert(absf(bounds.size.x - dims.x) < 0.01, "רוחב התיבה לא תואם למידות (X)")
	assert(absf(bounds.size.y - dims.y) < 0.05, "גובה התיבה לא תואם למידות (Y)")
	assert(absf(bounds.size.z - dims.z) < 0.01, "עומק התיבה לא תואם למידות (Z)")
	# נקודת המוצא בתחתית-המרכז: השולחן יושב על הרצפה וממורכז.
	assert(absf(bounds.position.y) < 0.05, "השולחן לא יושב על הרצפה")
	assert(absf(bounds.get_center().x) < 0.05, "השולחן לא ממורכז ב-X")
	assert(absf(bounds.get_center().z) < 0.05, "השולחן לא ממורכז ב-Z")
	root.free()


func test_width_grows_top_and_legs() -> void:
	var root := Node3D.new()
	add_child(root)
	var desk := _make_desk(root)
	var base: Vector3 = desk.get_dimensions()

	desk.set_dimensions(Vector3(base.x + 1.0, base.y, base.z))
	var dims: Vector3 = desk.get_dimensions()
	assert(absf(dims.x - (base.x + 1.0)) < 0.01, "הרוחב לא התעדכן")
	# התיבה גדלה בדיוק במטר - הגיאומטריה האפויה תואמת למידות.
	var bounds := _desk_bounds(desk)
	assert(absf(bounds.size.x - (base.x + 1.0)) < 0.05, "הראש לא התרחב במלוא המטר")
	# רגליים של הזרוע הימנית זזו, רגל הפינה נשארה.
	var moved := 0
	var stayed := 0
	for info in desk._leg_infos:
		var leg: MeshInstance3D = info["node"]
		if info["moves_x"]:
			assert(absf(leg.position.x - 1.0) < 0.01, "רגל של הזרוע הימנית לא זזה מטר")
			moved += 1
		else:
			assert(absf(leg.position.x) < 0.01, "רגל שלא שייכת לזרוע זזה - אסור")
			stayed += 1
	assert(moved > 0, "לא זוהתה אף רגל של הזרוע הימנית")
	assert(stayed > 0, "לא זוהתה אף רגל סטטית")
	root.free()


func test_depth_grows_top_and_legs() -> void:
	var root := Node3D.new()
	add_child(root)
	var desk := _make_desk(root)
	var base: Vector3 = desk.get_dimensions()

	desk.set_dimensions(Vector3(base.x, base.y, base.z + 0.5))
	var bounds := _desk_bounds(desk)
	assert(absf(bounds.size.z - (base.z + 0.5)) < 0.05, "הראש לא התארך בחצי מטר")
	var moved := 0
	for info in desk._leg_infos:
		var leg: MeshInstance3D = info["node"]
		if info["moves_z"]:
			assert(absf(absf(leg.position.z) - 0.5) < 0.01, "רגל של הזרוע הקדמית לא זזה חצי מטר")
			moved += 1
		else:
			assert(absf(leg.position.z) < 0.01, "רגל שלא שייכת לזרוע הקדמית זזה - אסור")
	assert(moved > 0, "לא זוהתה אף רגל של הזרוע הקדמית")
	root.free()


func test_height_stretches_legs_and_keeps_floor() -> void:
	var root := Node3D.new()
	add_child(root)
	var desk := _make_desk(root)
	var base: Vector3 = desk.get_dimensions()

	desk.set_dimensions(Vector3(base.x, base.y + 1.0, base.z))
	# הראש עלה בדיוק מטר, הרגליים נמתחו ונשארו על הרצפה.
	assert(absf(desk._top.position.y - 1.0) < 0.01, "הראש לא עלה מטר")
	var stretch: float = (base.y + 1.0) / base.y
	for info in desk._leg_infos:
		var leg: MeshInstance3D = info["node"]
		assert(absf(leg.scale.y - stretch) < 0.001, "הרגל לא נמתחה לפי הגובה החדש")
	var bounds := _desk_bounds(desk)
	assert(absf(bounds.size.y - (base.y + 1.0)) < 0.05, "גובה התיבה לא תואם למידות")
	assert(absf(bounds.position.y) < 0.05, "הרגליים לא נשארו על הרצפה")
	root.free()


func test_dimensions_clamped() -> void:
	var root := Node3D.new()
	add_child(root)
	var desk := _make_desk(root)
	var base: Vector3 = desk.get_dimensions()

	desk.set_dimensions(Vector3(99.0, 99.0, 99.0))
	var dims: Vector3 = desk.get_dimensions()
	assert(absf(dims.x - (base.x + desk._ext_x)) < 0.01, "הרוחב לא הוצמד למתיחה המלאה")
	assert(absf(dims.y - DeskScript.MAX_HEIGHT) < 0.01, "הגובה לא הוצמד לגבול העליון")
	assert(absf(dims.z - (base.z + desk._ext_z)) < 0.01, "העומק לא הוצמד למתיחה המלאה")
	root.free()


func test_resized_signal() -> void:
	var root := Node3D.new()
	add_child(root)
	var desk := _make_desk(root)
	var base: Vector3 = desk.get_dimensions()

	var count: Array[int] = [0]
	desk.resized.connect(func() -> void: count[0] += 1)
	desk.set_dimensions(Vector3(base.x, base.y + 0.5, base.z))
	assert(count[0] == 1, "אות resized לא נשלח אחרי שינוי")
	desk.set_dimensions(Vector3(base.x, base.y + 0.5, base.z))
	assert(count[0] == 1, "אות resized נשלח גם בלי שינוי אמיתי")
	root.free()


func test_material_parts_are_independent() -> void:
	var root := Node3D.new()
	add_child(root)
	var desk := _make_desk(root)

	var parts: Array = desk.get_material_parts()
	assert(parts.size() == 2, "צריכים להיות שני חלקי חומר: ראש ורגליים")
	var top_mat: StandardMaterial3D = desk.get_part_material(parts[0])
	var legs_mat: StandardMaterial3D = desk.get_part_material(parts[1])
	assert(top_mat != null and legs_mat != null, "לכל חלק חייב להיות חומר")
	assert(top_mat != legs_mat, "לשני החלקים חייב להיות חומר נפרד")

	var original_legs_color: Color = legs_mat.albedo_color
	top_mat.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	assert(legs_mat.albedo_color.is_equal_approx(original_legs_color), "שינוי חומר הראש הדליק לרגליים")

	# הרגליים מקבלות רק פלסטיק ומתכת, הראש - הכל.
	var legs_presets: Array = desk.get_part_presets(parts[1])
	assert(legs_presets.size() == 2, "לרגליים צריכים להיות רק פלסטיק ומתכת")
	assert(desk.get_part_presets(parts[0]).is_empty(), "לראש מותרים כל הסטים")
	root.free()


func test_make_preview_matches_original() -> void:
	var root := Node3D.new()
	add_child(root)
	var desk := _make_desk(root)
	var base: Vector3 = desk.get_dimensions()
	desk.set_dimensions(Vector3(base.x + 0.5, base.y, base.z))

	# כמו הפאנל: יוצרים תצוגה מקדימה, מכניסים לעץ ומסנכרנים מידות וחומרים.
	var preview: Node3D = desk.make_preview()
	root.add_child(preview)
	preview.set_dimensions(desk.get_dimensions())
	for part in desk.get_material_parts():
		preview.set_part_material(part, desk.get_part_material(part))
	assert(
		preview.get_dimensions().is_equal_approx(desk.get_dimensions()),
		"התצוגה המקדימה לא קיבלה את המידות של השולחן האמיתי"
	)
	var parts: Array = desk.get_material_parts()
	assert(
		preview.get_part_material(parts[0]) == desk.get_part_material(parts[0]),
		"התצוגה המקדימה לא משתפת את אותו מופע חומר"
	)
	root.free()


func test_collision_box_matches_desk() -> void:
	var root := Node3D.new()
	add_child(root)
	# כמו בזרימה האמיתית: המודל נוצר מחוץ לעץ, ה-Prop מאמץ אותו,
	# והכניסה לעץ בונה את הגיאומטריה ומרעננת את תיבת ההתנגשות.
	var desk: Node3D = DeskScript.new()
	var prop: Node3D = PropScript.new()
	prop.setup(&"computerdesk", "שולחן מחשב", desk)
	root.add_child(prop)

	var shape_node: CollisionShape3D = prop.get_node("Body/Collision")
	var box: BoxShape3D = shape_node.shape
	var dims: Vector3 = desk.get_dimensions()
	assert(absf(box.size.x - dims.x) < 0.1, "תיבת ההתנגשות לא תואמת לרוחב השולחן")
	assert(absf(box.size.y - dims.y) < 0.1, "תיבת ההתנגשות לא תואמת לגובה השולחן")
	assert(absf(box.size.z - dims.z) < 0.1, "תיבת ההתנגשות לא תואמת לעומק השולחן")

	# וגם אחרי שינוי גודל נוסף.
	desk.set_dimensions(Vector3(dims.x + 0.5, dims.y, dims.z + 0.5))
	assert(absf((shape_node.shape as BoxShape3D).size.x - (dims.x + 0.5)) < 0.1, "תיבת ההתנגשות לא התרעננה ברוחב")
	root.free()


func test_library_registers_desk_and_skips_ui() -> void:
	var library := LibraryScript.new()

	# שולחן המחשב רשום כמודל עטוף עם ממשק שינוי הגודל.
	var desk := library.instantiate_asset(&"computerdesk")
	assert(desk != null, "שולחן המחשב לא נטען מהספרייה")
	assert(desk.has_method("set_dimensions"), "למודל שולחן המחשב חסר ממשק שינוי הגודל")
	desk.free()

	# ההנדלים שבתיקיית UI לא מופיעים כאסט להצבה.
	assert(not library.has_asset(&"scalehandler"), "ההנדלים מתיקיית ה-UI לא אמורים להיות אסט")
	# והשולחן הפרוצדורלי עדיין עובד.
	assert(library.has_asset(&"simpletable"), "השולחן הפרוצדורלי נעלם מהבנק")


## ההנדלים שמידל המשתמש (ScaleHandler) מוצמדים לקצוות השולחן וזזים
## איתו כשהוא משנה גודל - וגם נתפסים בקליק במקום שבו הם מוצגים.
func test_resize_handles_attach_to_edges() -> void:
	var root := Node3D.new()
	add_child(root)
	var desk: Node3D = DeskScript.new()
	var prop: Node3D = PropScript.new()
	prop.setup(&"computerdesk", "שולחן מחשב", desk)
	root.add_child(prop)

	var gizmo := GizmoScript.new()
	root.add_child(gizmo)
	gizmo.set_mode(GizmoScript.GizmoMode.SCALE)
	gizmo.attach_to(prop)

	var dims: Vector3 = desk.get_dimensions()
	var width_holder := gizmo._handle_nodes[GizmoScript.Handle.RESIZE_WIDTH] as Node3D
	var length_holder := gizmo._handle_nodes[GizmoScript.Handle.RESIZE_LENGTH] as Node3D
	assert(width_holder != null and length_holder != null, "ידיות שינוי הגודל לא נבנו")

	# ההנדל של הרוחב מוצמד לאמצע הקצה הימני, בגובה לוח הראש.
	var expected := Vector3(dims.x * 0.5, dims.y - 0.12, 0.0)
	assert(
		width_holder.global_position.distance_to(expected) < 0.001,
		"הנדל הרוחב לא מוצמד לקצה הימני של השולחן"
	)
	# ההנדל של העומק מוצמד לקצה הקדמי וצף לכיוון -Z.
	assert(
		absf(length_holder.global_position.z - (-dims.z * 0.5)) < 0.001,
		"הנדל העומק לא מוצמד לקצה הקדמי"
	)
	assert(
		length_holder.global_basis.z.dot(Vector3.FORWARD) > 0.9,
		"הנדל העומק לא צף לכיוון הקצה הקדמי (-Z)"
	)

	# אחרי שינוי גודל ההנדלים זזים לקצה החדש.
	desk.set_dimensions(Vector3(dims.x + 1.0, dims.y, dims.z))
	gizmo.refresh()
	# השולחן מתרחב רק לכיוון +X, ולכן הקצה הימני האמיתי זז - ההנדל
	# חייב להצמד אליו (ולא לנוסחה קבועה).
	var bounds := _desk_bounds(desk)
	assert(
		absf(width_holder.global_position.x - bounds.end.x) < 0.01,
		"הנדל הרוחב לא זז עם הקצה החדש"
	)
	root.free()


func test_resize_handles_pickable_at_edges() -> void:
	var root := Node3D.new()
	add_child(root)
	var desk: Node3D = DeskScript.new()
	var prop: Node3D = PropScript.new()
	prop.setup(&"computerdesk", "שולחן מחשב", desk)
	root.add_child(prop)

	var gizmo := GizmoScript.new()
	root.add_child(gizmo)
	gizmo.set_mode(GizmoScript.GizmoMode.SCALE)
	gizmo.attach_to(prop)

	var dims: Vector3 = desk.get_dimensions()
	# קרן אנכית מעל ההנדל הירוק (קצת החוצה מנקודת ההצמדה).
	var tip := Vector3(dims.x * 0.5 + 0.3, 0.0, 0.0)
	var handle := gizmo._resize_handle_at(tip + Vector3(0.0, 5.0, 0.0), Vector3(0.0, -1.0, 0.0))
	assert(handle == GizmoScript.Handle.RESIZE_WIDTH, "קרן על הנדל הרוחב לא זיהתה אותו")

	# קרן הרחק מכל הנדל (מעל מרכז השולחן) - לא תופסת כלום.
	var center := gizmo._resize_handle_at(Vector3(0.0, 5.0, 0.0), Vector3(0.0, -1.0, 0.0))
	assert(center == GizmoScript.Handle.NONE, "קרן במרכז השולחן תפסה הנדל - אסור")
	root.free()
