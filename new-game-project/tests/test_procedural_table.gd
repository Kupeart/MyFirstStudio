class_name TestProceduralTable
extends Node
## בדיקות לשולחן הפרוצדורלי, לחצי שינוי הגודל ולחלון החומריות.

const TableScript := preload("res://scripts/core/procedural_table.gd")
const GizmoScript := preload("res://scripts/core/move_gizmo.gd")
const PropScript := preload("res://scripts/core/prop.gd")
const PanelScript := preload("res://scripts/ui/material_panel.gd")


func test_default_build() -> void:
	var root := Node3D.new()
	add_child(root)
	var table := TableScript.new()
	root.add_child(table)

	assert(
		table.get_dimensions().is_equal_approx(Vector3(TableScript.DEFAULT_WIDTH, TableScript.DEFAULT_HEIGHT, TableScript.DEFAULT_LENGTH)),
		"ברירת המחדל של המידות שגויה"
	)
	# הראש מרחף על גבי הרגליים, ותחתיתו בדיוק בגובה רגל.
	var top: Node3D = table.get_node("Top")
	assert(top != null, "לוח הראש חסר")
	var top_bottom := top.position.y + TableScript.TOP_THICKNESS * 0.5
	assert(
		absf(top_bottom - TableScript.DEFAULT_HEIGHT) < 0.001,
		"הראש לא יושב בדיוק בגובה הכולל"
	)
	# ארבע רגליים בפינות.
	assert(table.get_node("Leg1") != null, "רגל 1 חסרה")
	assert(table.get_node("Leg4") != null, "רגל 4 חסרה")
	root.free()


func test_legs_follow_top() -> void:
	var root := Node3D.new()
	add_child(root)
	var table := TableScript.new()
	root.add_child(table)

	table.set_dimensions(Vector3(2.0, 0.75, 1.6))
	# גודל הראש השתנה, גודל הרגליים נשאר קבוע, והן זזו לפינות החדשות.
	# Leg4 יושבת בפינה החיובית בשני הצירים (+x, +z).
	var leg: MeshInstance3D = table.get_node("Leg4")
	var leg_aabb: AABB = leg.get_aabb()
	assert(absf(leg_aabb.size.x - TableScript.LEG_SIZE) < 0.001, "רוחב הרגל השתנה - אסור")
	assert(absf(leg_aabb.size.y - (0.75 - TableScript.TOP_THICKNESS)) < 0.001, "אורך הרגל לא נגזר מהגובה")
	var expected_x := 2.0 * 0.5 - TableScript.LEG_SIZE * 0.5
	var expected_z := 1.6 * 0.5 - TableScript.LEG_SIZE * 0.5
	assert(absf(leg.position.x - expected_x) < 0.001, "הרגל לא זזה לפינת הראש החדשה (X)")
	assert(absf(leg.position.z - expected_z) < 0.001, "הרגל לא זזה לפינת הראש החדשה (Z)")
	root.free()


func test_height_stretches_legs_only() -> void:
	var root := Node3D.new()
	add_child(root)
	var table := TableScript.new()
	root.add_child(table)

	table.set_dimensions(Vector3(1.2, 1.5, 0.8))
	var top: Node3D = table.get_node("Top")
	assert(absf(top.position.y - (1.5 - TableScript.TOP_THICKNESS * 0.5)) < 0.001, "הראש לא עלה עם הגובה")
	var top_aabb: AABB = (top as MeshInstance3D).get_aabb()
	assert(absf(top_aabb.size.y - TableScript.TOP_THICKNESS) < 0.001, "עובי הראש השתנה - אסור")
	root.free()


func test_box_faces_front_facing() -> void:
	# Godot מצייר פאה קדמית כשהמשולש מסודר עם כיוון השעון מבחוץ. אם הסדר
	# הפוך - הפאה מסוננת והתיבה נראית הפוכה מבפנים. בודקים שלכל משולש
	# מכפלת וקטור המשולש בנורמל המוצהר שלילית (כלומר: פונה החוצה).
	var mesh := TableScript.make_box_mesh(Vector3(2.0, 1.0, 3.0))
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var counter := 0
	while counter + 2 < vertices.size():
		var a := vertices[counter]
		var b := vertices[counter + 1]
		var c := vertices[counter + 2]
		var face_normal := (b - a).cross(c - b)
		assert(
			face_normal.dot(normals[counter]) < 0.0,
			"משולש בסדר סיבוב הפוך - הפאה תסונן והתיבה תיראה מבפנים"
		)
		counter += 3


func test_dimensions_clamped() -> void:
	var root := Node3D.new()
	add_child(root)
	var table := TableScript.new()
	root.add_child(table)

	table.set_dimensions(Vector3(99.0, 99.0, 0.01))
	assert(
		table.get_dimensions().is_equal_approx(Vector3(TableScript.MAX_WIDTH, TableScript.MAX_HEIGHT, TableScript.MIN_LENGTH)),
		"מידות חריגות לא הוצמדו לגבולות"
	)
	root.free()


func test_resized_signal() -> void:
	var root := Node3D.new()
	add_child(root)
	var table := TableScript.new()
	root.add_child(table)

	# למבדה ב-GDScript יש העתק משלה של המשתנים - סופרים בעזרת מערך.
	var count: Array[int] = [0]
	table.resized.connect(func() -> void: count[0] += 1)
	table.set_dimensions(Vector3(2.0, 0.75, 0.8))
	assert(count[0] == 1, "אות resized לא נשלח אחרי שינוי")
	# הצבת אותן מידות בדיוק - שום דבר לא קרה, אין אות מיותר.
	table.set_dimensions(Vector3(2.0, 0.75, 0.8))
	assert(count[0] == 1, "אות resized נשלח גם בלי שינוי אמיתי")
	root.free()


func test_uv_not_stretched() -> void:
	# תיבה 2×1×3 עם טקסטורה של מטר לחזרה: בפאה העליונה ה-UV נפרש על 2
	# בציר X ו-3 בציר Z; בפאות הצד ציר ה-V (האנכי) נפרש על 1 (הגובה).
	var mesh := TableScript.make_box_mesh(Vector3(2.0, 1.0, 3.0))
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]

	var top_min := Vector2(INF, INF)
	var top_max := Vector2(-INF, -INF)
	var side_min := Vector2(INF, INF)
	var side_max := Vector2(-INF, -INF)
	for i in normals.size():
		var normal: Vector3 = normals[i]
		var uv: Vector2 = uvs[i]
		# הנורמלים שמפיק SurfaceTool מכילים סטייה זעירה (~0.00002) -
		# מזהים פאות לפי קרבה ולא לפי שוויון מדויק.
		if normal.distance_to(Vector3.UP) < 0.001:
			top_min = top_min.min(uv)
			top_max = top_max.max(uv)
		if normal.distance_to(Vector3.RIGHT) < 0.001:
			side_min = side_min.min(uv)
			side_max = side_max.max(uv)

	assert(absf(top_max.x - top_min.x - 2.0) < 0.001, "רוחב ה-UV בפאה העליונה לא תואם למידה")
	assert(absf(top_max.y - top_min.y - 3.0) < 0.001, "אורך ה-UV בפאה העליונה לא תואם למידה")
	assert(absf(side_max.y - side_min.y - 1.0) < 0.001, "ציר V בפאות הצד לא תואם לגובה")


func _make_table_prop(root: Node3D) -> Node3D:
	# כמו בזרימה האמיתית: המודל נוצר מחוץ לעץ, ה-Prop מאמץ אותו,
	# והכניסה לעץ מפעילה את _ready שבונה את הגיאומטריה.
	var table := TableScript.new()
	var prop: Node3D = PropScript.new()
	prop.setup(&"simpletable", "שולחן פשוט", table)
	root.add_child(prop)
	return prop


func test_collision_box_matches_table() -> void:
	# ההצבה בונה את תיבת ההתנגשות לפני שהמודל נכנס לעץ - בגיאומטריה
	# עדיין אין כלום. עם הכניסה לעץ השולחן נבנה ומודיע על כך, ותיבת
	# ההתנגשות חייבת להתרענן למידות האמיתיות - אחרת אי אפשר לבחור
	# את השולחן בקליק.
	var root := Node3D.new()
	add_child(root)
	var prop := _make_table_prop(root)

	var shape_node: CollisionShape3D = prop.get_node("Body/Collision")
	var box: BoxShape3D = shape_node.shape
	assert(
		box.size.is_equal_approx(Vector3(TableScript.DEFAULT_WIDTH, TableScript.DEFAULT_HEIGHT, TableScript.DEFAULT_LENGTH)),
		"תיבת ההתנגשות לא התרעננה למידות השולחן אחרי הבנייה"
	)

	# וגם אחרי שינוי גודל נוסף.
	var table: Node3D = prop.get_model()
	table.set_dimensions(Vector3(2.5, 1.0, 1.5))
	assert(
		(shape_node.shape as BoxShape3D).size.is_equal_approx(Vector3(2.5, 1.0, 1.5)),
		"תיבת ההתנגשות לא התרעננה אחרי שינוי מידות"
	)
	root.free()


func test_gizmo_resize_drag() -> void:
	var root := Node3D.new()
	add_child(root)
	var prop := _make_table_prop(root)
	var table: Node3D = prop.get_model()

	var gizmo := GizmoScript.new()
	root.add_child(gizmo)
	gizmo._targets.clear()
	gizmo._targets.append(prop)
	gizmo._active = GizmoScript.Handle.RESIZE_WIDTH
	gizmo._resize_table = table
	gizmo._resize_start_dims = table.get_dimensions()
	gizmo._grab_axis_point = Vector3.ZERO

	# קרן מעל ציר ה-X: ההצלה הקרובה על הציר היא בנקודה x=2.
	var origin := Vector3(2.0, 0.1, 5.0)
	var direction := Vector3(0.0, 0.0, -1.0)
	gizmo._resize_drag(origin, direction)
	assert(absf(table.get_dimensions().x - 3.2) < 0.001, "גרירת הרוחב לא הוסיפה את המרחק למידה")
	assert(absf(table.get_dimensions().y - TableScript.DEFAULT_HEIGHT) < 0.001, "גרירת הרוחב שינתה גם גובה - אסור")

	# ביטול בקליק ימני מחזיר את המידות שלפני הגרירה.
	gizmo.cancel_drag()
	assert(
		table.get_dimensions().is_equal_approx(Vector3(TableScript.DEFAULT_WIDTH, TableScript.DEFAULT_HEIGHT, TableScript.DEFAULT_LENGTH)),
		"ביטול גרירה לא החזיר את המידות"
	)
	root.free()


func test_gizmo_resize_arrows_visibility() -> void:
	var root := Node3D.new()
	add_child(root)
	var gizmo := GizmoScript.new()
	root.add_child(gizmo)

	# שולחן פרוצדורלי - חצי שינוי גודל במצב קנה מידה.
	var prop := _make_table_prop(root)
	gizmo.set_mode(GizmoScript.GizmoMode.SCALE)
	gizmo.attach_to(prop)
	assert(gizmo._resize_root.visible == true, "חצי שינוי הגודל לא מוצגים לשולחן פרוצדורלי")
	assert(gizmo._scale_root.visible == false, "גיזמו הקוביות לא אמור להופיע לשולחן פרוצדורלי")

	# עצם רגיל - גיזמו הקוביות הרגיל.
	var mock_prop := Node3D.new()
	root.add_child(mock_prop)
	gizmo.attach_to(mock_prop)
	assert(gizmo._resize_root.visible == false, "חצי שינוי הגודל מוצגים לעצם שאינו שולחן")
	assert(gizmo._scale_root.visible == true, "גיזמו הקוביות לא מוצג לעצם רגיל")
	root.free()


func test_material_panel_cancel_restores() -> void:
	var root := Node3D.new()
	add_child(root)
	var prop := _make_table_prop(root)
	var table: Node3D = prop.get_model()
	var material := table.get_material() as StandardMaterial3D
	var original_color: Color = material.albedo_color

	var panel := PanelScript.new()
	root.add_child(panel)
	panel.open_for(prop)
	assert(panel.visible == true, "החלון לא נפתח")

	# המשתמש משנה צבע ומתכתיות - ואז לוחץ ✗.
	material.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	material.metallic = 0.7
	panel._on_cancel_pressed()

	assert(panel.visible == false, "החלון לא נסגר אחרי ✗")
	assert(material.albedo_color.is_equal_approx(original_color), "הצבע לא הוחזר אחרי ביטול")
	assert(absf(material.metallic) < 0.001, "המתכתיות לא הוחזרה אחרי ביטול")
	root.free()
