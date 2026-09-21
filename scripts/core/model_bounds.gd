class_name ModelBounds
extends RefCounted
## מדידות של מודל שיוצא מבלנדר.
##
## מודל שנטען למנוע הוא Node3D שמכיל ענף אחד או יותר של MeshInstance3D.
## הפונקציה כאן מחזירה את הקופסה התוחמת של כל הגיאומטריה ביחד,
## ביחס לשורש של המודל.
##
## שימושים במנוע:
##   - יישור נקודת המוצא של המודל לתחתית-המרכז (asset_library).
##   - מיסגור המצלמה בתצוגה המקדימה ובתמונות הממוזערות (asset_bank).
##   - בניית תיבת ההתנגשות של כל עצם בעולם, כדי שאפשר לבחור אותו (prop).

## הקופסה התוחמת של כל חלקי המודל, ביחס לשורש שלו.
## מחזיר AABB ריק (size == ZERO) אם אין במודל שום גיאומטריה.
static func combined_aabb(root: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect_mesh_aabbs(root, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return AABB()
	var merged: AABB = boxes[0]
	for index in range(1, boxes.size()):
		merged = merged.merge(boxes[index])
	return merged


## התיבה התוחמת של עצם על המסך (בפיקסלים), מהקרנת שמונה פינות התיבה
## התוחמת בעולם. משמשת למיקום ממשק צף ליד עצם ולבחירת מלבן.
static func screen_box(camera: Camera3D, center: Vector3, size: Vector3) -> Rect2:
	var half := size * 0.5
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for i in 8:
		var corner := center + Vector3(
			half.x if (i & 1) != 0 else -half.x,
			half.y if (i & 2) != 0 else -half.y,
			half.z if (i & 4) != 0 else -half.z
		)
		var screen := camera.unproject_position(corner)
		if not screen.is_finite():
			continue
		min_point = min_point.min(screen)
		max_point = max_point.max(screen)
	# גיבוי: אם לא הצלחנו להקרין אף פינה - מסתפקים במרכז בלבד.
	if not min_point.is_finite() or not max_point.is_finite():
		var single := camera.unproject_position(center)
		min_point = single
		max_point = single
	return Rect2(min_point, max_point - min_point)


static func _collect_mesh_aabbs(node: Node, xform: Transform3D, out_boxes: Array[AABB]) -> void:
	var local := xform
	if node is Node3D:
		local = xform * (node as Node3D).transform
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		out_boxes.append(local * mesh_instance.get_aabb())
	for child in node.get_children():
		_collect_mesh_aabbs(child, local, out_boxes)


## הקופסה התוחמת של המודל לפי הקודקודים הבסיסיים בלבד - בלי להתחשב
## ב-shape keys (blend shapes).
##
## get_aabb() של המנוע מרחיב את התיבה גם לפי ה-shape keys, ולכן למודל עם
## shape keys (כמו הכדורים) היא גדולה בהרבה מהצורה שמוצגת בפועל. כאן
## מודדים את הגיאומטריה הבסיסית, שזו הצורה ה"רגילה" של המודל.
static func base_aabb(root: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect_base_aabbs(root, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return AABB()
	var merged: AABB = boxes[0]
	for index in range(1, boxes.size()):
		merged = merged.merge(boxes[index])
	return merged


static func _collect_base_aabbs(node: Node, xform: Transform3D, out_boxes: Array[AABB]) -> void:
	var local := xform
	if node is Node3D:
		local = xform * (node as Node3D).transform
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		var box := _mesh_base_aabb(mesh_instance.mesh)
		if box.size != Vector3.ZERO:
			out_boxes.append(local * box)
	for child in node.get_children():
		_collect_base_aabbs(child, local, out_boxes)


## התיבה התוחמת של הרשת לפי הקודקודים הבסיסיים שלה (בלי shape keys).
static func _mesh_base_aabb(mesh: Mesh) -> AABB:
	var min_point := Vector3(INF, INF, INF)
	var max_point := Vector3(-INF, -INF, -INF)
	var found := false
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.is_empty():
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			min_point = min_point.min(vertex)
			max_point = max_point.max(vertex)
			found = true
	if not found:
		return mesh.get_aabb()
	return AABB(min_point, max_point - min_point)
