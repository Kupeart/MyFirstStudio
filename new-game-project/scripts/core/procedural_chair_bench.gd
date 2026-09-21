class_name ProceduralChairBench
extends Node3D
## כיסא/ספסל פרוצדורלי שנבנה מהחלקים של ה-GLB.
##
## ה-GLB הוא "ערכת חלקים": מסגרת רגל אחת, קרש מושב אחד, עמודת גב אחת,
## מסילת גב ומחבר צד. הסקריפט מרכיב מהם כיסא שלם או ספסל שלם.
##
## הפריסה פרמטרית: לכל חלק גודל קבוע, ומספר החלקים נגזר מהמידות.
##   - רוחב -> הרגליים רק זזות הצידה (לא מתעבות); נוספות עמודות גב.
##   - עומק -> נוספות שורות קרש במושב; הרגליים מעמיקות יחד עם המושב.
##   - גובה -> המושב והמשענת עולים יחד (המשענת שומרת על גודלה),
##             ורק הרגליים מתארכות.
##
## ציר המידות: x = רוחב, y = גובה, z = עומק (כמו בשאר הרהיטים בסטודיו).

## נשלח אחרי כל שינוי מידות (לריענון תיבת ההתנגשות והתצוגה המקדימה).
signal resized

## המודל של המשתמש.
const GLB_PATH := "res://assets/models/Furnatures/ProceduralChairBench/ProceduralChairBench.glb"

## גבולות המידות.
const MIN_WIDTH := 0.4
const MAX_WIDTH := 2.4
const MIN_HEIGHT := 0.4
const MAX_HEIGHT := 1.3
const MIN_DEPTH := 0.3
const MAX_DEPTH := 1.0

## מעל הרוחב הזה המצב מתחלף מכיסא לספסל.
const BENCH_WIDTH_THRESHOLD := 1.0

## חלקי החומר.
const PART_FRAME := &"frame"
const PART_SEAT_BACK := &"seat_back"

## מידות ברירת מחדל (מטרים).
const CHAIR_DEFAULT := Vector3(0.6, 0.85, 0.5)
const BENCH_DEFAULT := Vector3(1.5, 1.0, 0.5)

## מפתחות החלקים במודל (אותיות קטנות).
const K_LEG_BENCH := "legforbench"
const K_LEG_CHAIR := "legforchair"
const K_SEAT := "sittingtile"
const K_SLAT := "tilesforback"
const K_RAIL := "vertidalconnectorforbackpiece"
const K_SIDE := "sideconnectorforbackpiece"

# ------------------------------------------------------------------ גדלים קבועים
# הגדלים האלה (במטרים) אינם משתנים עם שינוי המידות - רק מספר החלקים משתנה.

## מחזור קרש מושב לאורך העומק (קרש + רווח).
const PLANK_MODULE := 0.10
## עובי קרש המושב.
const PLANK_THICKNESS := 0.05
## מחזור עמודת גב לרוחב (עמודה + רווח).
const SLAT_MODULE := 0.16
## עומק עמודת הגב.
const SLAT_THICKNESS := 0.05
## חתך המסילה (עומק וגובה).
const RAIL_SIZE := 0.05
## גובה המשענת - קבוע, ולכן הוא עולה עם הגובה במקום להתארך.
const BACK_HEIGHT := 0.46
## גובה מינימלי למושב (כשהעצם נמוך מאוד).
const MIN_SEAT_HEIGHT := 0.22
## עומק עמוד הצד של הגב.
const SIDE_DEPTH := 0.09
## עובי עמוד הצד של הגב.
const SIDE_THICKNESS := 0.05
## מרווח קטן בין עמודות הגב לעמודי הצד.
const SLAT_INSET := 0.01
## הרווח בין קרשי המושב = 30% מגודל הקרש.
const GAP_RATIO := 0.3
## כמה מהמחזור תופסת עמודת הגב (קטן = עמודה דקה יותר).
const SLAT_FILL_RATIO := 0.5
## גוון העץ של המסגרת (הרגליים והמחברים).
const FRAME_WOOD_COLOR := Color(0.42, 0.25, 0.12)
## גוון העץ של המושב והמשענת.
const SEAT_WOOD_COLOR := Color(0.58, 0.37, 0.19)

## המידות הנוכחיות.
var dimensions := Vector3.ZERO
## החומרים של שני החלקים - אותם עורך חלון החומריות.
var frame_material: StandardMaterial3D = null
var seat_back_material: StandardMaterial3D = null

## החלקים המקוריים מה-GLB (שם באותיות קטנות -> MeshInstance3D).
var _templates: Dictionary = {}
## מטמון של רשתות ממוראות (נבנה פעם אחת לכל חלק).
var _mirrored_cache: Dictionary = {}
## כל המשוכות שנבנו (להחלת חומרים).
var _all_meshes: Array[MeshInstance3D] = []
## המודל הגולמי (לא נכנס לעץ - משמש רק כמקור לחלקים).
var _source: Node3D = null
## מסובב: רוחב המודל (Z) הופך לרוחב העולם (X).
var _pivot: Node3D = null
## האספלט עצמו - מחזיק את החלקים במישור המודל (רוחב=Z, עומק=X, גובה=Y).
var _assembly: Node3D = null
## האם המצב הנוכחי הוא ספסל.
var _is_bench := false


func _ready() -> void:
	_load_templates()

	_pivot = Node3D.new()
	_pivot.name = "Rotated"
	_pivot.rotation.y = PI * 0.5
	add_child(_pivot)

	_assembly = Node3D.new()
	_assembly.name = "Parts"
	_pivot.add_child(_assembly)

	dimensions = CHAIR_DEFAULT
	_rebuild()
	_build_materials()
	resized.emit()


# ------------------------------------------------------------------ טעינה

## טוען את ה-GLB ואוסף את החלקים.
func _load_templates() -> void:
	var packed := load(GLB_PATH) as PackedScene
	if packed == null:
		push_error("ProceduralChairBench: לא נמצא קובץ המודל " + GLB_PATH)
		return
	_source = packed.instantiate()
	_source.name = "Source"
	# לא מוסיפים את ערכת החלקים לעץ: היא פרוסה ולא מורכבת, ואם הייתה
	# בעץ היא הייתה נכללת בתיבת ההתנגשות ובגיזמו.
	_collect_templates(_source)


func _collect_templates(node: Node) -> void:
	var mesh := node as MeshInstance3D
	if mesh != null and mesh.mesh != null:
		_templates[node.name.to_lower()] = mesh
	for child in node.get_children():
		_collect_templates(child)


# ------------------------------------------------------------------ בנייה

## בונה מחדש את כל החלקים לפי המידות הנוכחיות.
func _rebuild() -> void:
	_clear_parts()
	if _assembly == null:
		return
	_is_bench = dimensions.x >= BENCH_WIDTH_THRESHOLD
	_build(dimensions)
	_center_assembly()
	_apply_materials()


## מוחק את החלקים הקיימים (הסרה מהעץ מיידית כדי שלא ייכללו במדידה).
func _clear_parts() -> void:
	_all_meshes.clear()
	if _assembly == null:
		return
	for child in _assembly.get_children():
		_assembly.remove_child(child)
		child.queue_free()


## מרכיב חלק אחד במישור המודל. כל הגדלים נגזרים מהמידות המבוקשות.
func _build(dims: Vector3) -> void:
	var width := dims.x
	var height := dims.y
	var depth := dims.z

	# המושב עולה עם הגובה; המשענת (בגובה קבוע) יושבת עליו ומטפסת איתו.
	# קצה הרגליים נמצא בדיוק בגובה המושב, ותחתית המשענת יושבת עליו.
	var seat_top := maxf(MIN_SEAT_HEIGHT, height - BACK_HEIGHT)
	var leg_top := seat_top
	var back_height := height - leg_top

	var leg_key := K_LEG_BENCH if _is_bench else K_LEG_CHAIR
	var leg_thickness := _template_size(leg_key).z

	# --- רגליים: מסגרת אחת בכל צד ---
	# ממורכזות על טווח העומק של המושב (0..depth) ולכן מסונכרנות איתו,
	# והן לא מתעבות עם הרוחב - רק זזות הצידה.
	for side: float in [-1.0, 1.0]:
		var leg_z := side * (width * 0.5 - leg_thickness * 0.5)
		_place(
			leg_key,
			Vector3(depth * 0.5, 0.0, leg_z),
			Vector3(depth, leg_top, leg_thickness),
			side < 0.0
		)

	# --- מושב: קרשים לרוחב, עם רווחים, לאורך העומק ---
	var plank_count := maxi(1, roundi(depth / PLANK_MODULE))
	var plank_module := depth / float(plank_count)
	var plank_depth := plank_module / (1.0 + GAP_RATIO)
	for i in plank_count:
		_place(
			K_SEAT,
			Vector3((i + 0.5) * plank_module, seat_top - PLANK_THICKNESS, 0.0),
			Vector3(plank_depth, PLANK_THICKNESS, width)
		)

	# --- משענת: מחוברת לקרש האחורי של המושב ולקצה העליון של הרגליים ---
	var back_x := depth - RAIL_SIZE * 0.5
	var slat_height := maxf(0.05, back_height - 2.0 * RAIL_SIZE)

	# מסילה תחתונה ומסילה עליונה - כל אחת תופסת את כל רוחב המשענת.
	_place(K_RAIL, Vector3(back_x, leg_top, 0.0), Vector3(RAIL_SIZE, RAIL_SIZE, width))
	_place(K_RAIL, Vector3(back_x, height - RAIL_SIZE, 0.0), Vector3(RAIL_SIZE, RAIL_SIZE, width))

	# עמודות הגב: מספרן נגזר מהרוחב, וגודלן קבוע.
	var slat_span := maxf(0.05, width - 2.0 * (SIDE_THICKNESS + SLAT_INSET))
	var slat_count := maxi(2, roundi(slat_span / SLAT_MODULE))
	var slat_module := slat_span / float(slat_count)
	var slat_width := slat_module * SLAT_FILL_RATIO
	for i in slat_count:
		var slat_z := -slat_span * 0.5 + (i + 0.5) * slat_module
		_place(
			K_SLAT,
			Vector3(back_x, leg_top + RAIL_SIZE, slat_z),
			Vector3(SLAT_THICKNESS, slat_height, slat_width)
		)

	# עמודי הצד של המשענת (מסגרת הגב).
	for side: float in [-1.0, 1.0]:
		var post_z := side * (width * 0.5 - SIDE_THICKNESS * 0.5)
		_place(
			K_SIDE,
			Vector3(back_x, leg_top, post_z),
			Vector3(SIDE_DEPTH, back_height, SIDE_THICKNESS)
		)


## מוסיף חלק לאספלט. המיקום הוא תחתית-מרכז תיבת התחום של החלק,
## והגודל המבוקש נקבע בדיוק (בלי לקנה מידה את כל האספלט).
func _place(key: String, pos: Vector3, target_size: Vector3, mirror: bool = false) -> void:
	if _assembly == null or not _templates.has(key):
		return
	var template: MeshInstance3D = _templates[key]
	var source_mesh: Mesh = template.mesh
	var mesh: Mesh = source_mesh
	if mirror:
		mesh = _mirrored_mesh(key, source_mesh)

	var box := mesh.get_aabb()
	var holder := Node3D.new()
	holder.name = key

	var instance := MeshInstance3D.new()
	instance.name = key
	instance.mesh = mesh
	# מזיזים את הגיאומטריה כך שתחתית-המרכז שלה תהיה בנקודת הראשית.
	instance.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	holder.add_child(instance)

	holder.position = pos
	holder.scale = Vector3(
		(target_size.x / box.size.x) if box.size.x > 0.0 else 1.0,
		(target_size.y / box.size.y) if box.size.y > 0.0 else 1.0,
		(target_size.z / box.size.z) if box.size.z > 0.0 else 1.0
	)
	_assembly.add_child(holder)
	_all_meshes.append(instance)


## יוצר עותק ממוראה (שיקוף בציר Z) של רשת, כדי ששני הצדדים יהיו מראה
## מדויק זה של זה - בלי קנה מידה שלילי שהופך נורמליות.
func _mirrored_mesh(key: String, source_mesh: Mesh) -> Mesh:
	if _mirrored_cache.has(key):
		return _mirrored_cache[key]

	var mirrored := ArrayMesh.new()
	for surface in source_mesh.get_surface_count():
		var arrays := source_mesh.surface_get_arrays(surface)

		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			var vertex := vertices[i]
			vertices[i] = Vector3(vertex.x, vertex.y, -vertex.z)
		arrays[Mesh.ARRAY_VERTEX] = vertices

		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in normals.size():
				var normal := normals[i]
				normals[i] = Vector3(normal.x, normal.y, -normal.z)
			arrays[Mesh.ARRAY_NORMAL] = normals

		# היפוך סדר הקודקודים בכל פאה כדי לשמור על כיוון הנורמליות.
		if arrays[Mesh.ARRAY_INDEX] != null:
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, indices.size(), 3):
				var swap := indices[i + 1]
				indices[i + 1] = indices[i + 2]
				indices[i + 2] = swap
			arrays[Mesh.ARRAY_INDEX] = indices

		mirrored.add_surface_from_arrays(source_mesh.surface_get_primitive_type(surface), arrays)
		mirrored.surface_set_material(surface, source_mesh.surface_get_material(surface))

	_mirrored_cache[key] = mirrored
	return mirrored


## מיישר את החלקים כך שתחתית-המרכז של כל הרהיט תהיה בנקודת הראשית.
func _center_assembly() -> void:
	if _assembly == null:
		return
	_assembly.position = Vector3.ZERO
	var boxes: Array[AABB] = []
	_collect_aabbs(_assembly, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return
	var merged := boxes[0]
	for box in boxes:
		merged = merged.merge(box)
	_assembly.position = Vector3(
		-merged.get_center().x,
		-merged.position.y,
		-merged.get_center().z
	)


func _collect_aabbs(node: Node3D, xform: Transform3D, out: Array[AABB]) -> void:
	var local := xform * node.transform
	var mesh := node as MeshInstance3D
	if mesh != null and mesh.mesh != null:
		out.append(local * mesh.get_aabb())
	for child in node.get_children():
		_collect_aabbs(child as Node3D, local, out)


func _template_size(key: String) -> Vector3:
	if not _templates.has(key):
		return Vector3.ONE
	return (_templates[key] as MeshInstance3D).get_aabb().size


# ------------------------------------------------------------------ חומרים

## מעתיק את החומרים מהמודל לשני חומרים - מסגרת ומושב/גב.
func _build_materials() -> void:
	var frame_source: Material = null
	var seat_source: Material = null
	for mesh in _all_meshes:
		var mat := mesh.mesh.surface_get_material(0) if mesh.mesh != null else null
		if mat == null:
			continue
		if _is_frame_mesh(mesh):
			if frame_source == null:
				frame_source = mat
		elif seat_source == null:
			seat_source = mat

	frame_material = frame_source.duplicate() as StandardMaterial3D if frame_source != null else null
	if frame_material == null:
		frame_material = StandardMaterial3D.new()
	seat_back_material = seat_source.duplicate() as StandardMaterial3D if seat_source != null else null
	if seat_back_material == null:
		seat_back_material = StandardMaterial3D.new()

	# ברירת מחדל: גוון עץ, כדי שגם המשחק וגם התמונה הממוזערת ייראו כרהיט עץ.
	_make_wooden(frame_material, FRAME_WOOD_COLOR, 0.7)
	_make_wooden(seat_back_material, SEAT_WOOD_COLOR, 0.6)
	_apply_materials()


## נותן לחומר מראה עץ פשוט - גוון חם בלי ברק מתכתי.
func _make_wooden(material: StandardMaterial3D, color: Color, roughness: float) -> void:
	if material == null:
		return
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = roughness


## האם המשוכה שייכת למסגרת (רגליים ומחברים) ולא למושב/גב.
func _is_frame_mesh(mesh: MeshInstance3D) -> bool:
	var n := mesh.name.to_lower()
	return n.begins_with("leg") or n.begins_with("sideconnector") or n.begins_with("vertidalconnector")


## מחיל את החומרים על כל חלקי המודל.
func _apply_materials() -> void:
	for mesh in _all_meshes:
		if _is_frame_mesh(mesh):
			if frame_material != null:
				mesh.material_override = frame_material
		elif seat_back_material != null:
			mesh.material_override = seat_back_material


# ------------------------------------------------------------------ מידות

func get_dimensions() -> Vector3:
	return dimensions


## קובע מידות חדשות ובונה את הרהיט מחדש. הרוחב קובע אם זה כיסא או ספסל.
func set_dimensions(new_dimensions: Vector3) -> void:
	var clamped := Vector3(
		clampf(new_dimensions.x, MIN_WIDTH, MAX_WIDTH),
		clampf(new_dimensions.y, MIN_HEIGHT, MAX_HEIGHT),
		clampf(new_dimensions.z, MIN_DEPTH, MAX_DEPTH)
	)
	if clamped.is_equal_approx(dimensions):
		return
	dimensions = clamped
	_rebuild()
	resized.emit()


# ------------------------------------------------------------------ חלקי חומר

func get_material_parts() -> Array[StringName]:
	return [PART_FRAME, PART_SEAT_BACK]


func get_part_label(part: StringName) -> String:
	if part == PART_FRAME:
		return "מסגרת"
	return "מושב וגב"


func get_part_material(part: StringName) -> StandardMaterial3D:
	if part == PART_FRAME:
		return frame_material
	return seat_back_material


func set_part_material(part: StringName, material: StandardMaterial3D) -> void:
	if part == PART_FRAME:
		frame_material = material
	else:
		seat_back_material = material
	_apply_materials()


func get_part_presets(_part: StringName) -> Array[String]:
	return []


## מופע חדש לתצוגה המקדימה בחלון החומריות.
func make_preview() -> Node3D:
	var preview := ProceduralChairBench.new()
	preview.name = "Preview"
	return preview


## שם המצב הנוכחי (לשורת הסטטוס).
func get_mode_name() -> String:
	return "ספסל" if _is_bench else "כיסא"
