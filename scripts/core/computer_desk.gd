class_name ComputerDesk
extends Node3D
## שולחן מחשב מהמודל שהמשתמש מידל בבלנדר (ComputerDesk.glb).
##
## המודל נטען מקובץ ה-GLB, והסקריפט הזה "מלביש" עליו את ההתנהגויות של
## הסטודיו: שינוי גודל בגיזמו ועריכת חומריות לכל חלק בנפרד.
##
## שינוי הגודל מבוסס על שני shape keys שהוכנו בבלנדר:
##   - האחד מותח את הזרוע הימנית של ה-L לאורך ציר X.
##   - השני מותח את הזרוע הקדמית לאורך ציר Z.
## במקום להשתמש ב-blend shapes של המנוע (שמנפחים את תיבת התחום
## גם כשהעוצמה אפס - מה שמזיז את הגיזמו ותיבת ההתנגשות ממקומן),
## הסקריפט אופה בעצמו את גיאומטריית הראש: בסיס + דלתא × עוצמה.
## כך הגיאומטריה ותיבת התחום תמיד זהות, והגיזמו תמיד ממורכז.
##
## הגובה משתנה במתיחת הרגליים (כמו בשולחן הפרוצדורלי): הרגליים
## נשארות על הרצפה והראש עולה.
##
## הרגליים הן אובייקטים נפרדים ולכן ה-shape keys לא מזיזים אותן -
## הסקריפט מזיז אותן לבד: רגליים בקצה הזרוע הימנית זזות עם ציר X,
## רגליים בקצה הזרוע הקדמית זזות עם ציר Z, ורגל הפינה נשארת במקום.
##
## חומריות: שני חלקים - ראש השולחן והרגליים - כל אחד עם חומר משלו
## (מועתק מהחומרים שהוגדרו בבלנדר), וחלון החומריות עורך כל חלק בנפרד.

## נשלח אחרי כל שינוי מידות (לריענון תיבת ההתנגשות והתצוגה המקדימה).
signal resized

## המודל של המשתמש.
const GLB_PATH := "res://assets/models/Furnatures/Computer Desk/ComputerDesk.glb"
## גבולות שינוי הגובה - כדי שהשולחן תמיד יישאר שולחן.
const MIN_HEIGHT := 0.8
const MAX_HEIGHT := 3.2
## עד כמה (במטרים) רגל נחשבת "רגל של קצה" וזזה יחד עם הזרוע.
const LEG_EDGE_MARGIN := 1.0
## חלקי החומר.
const PART_TOP := &"top"
const PART_LEGS := &"legs"

## המידות הנוכחיות (במטרים): x=רוחב, y=גובה, z=עומק.
var dimensions := Vector3.ZERO
## החומרים של שני החלקים - אותם עורך חלון החומריות.
var top_material: StandardMaterial3D = null
var legs_material: StandardMaterial3D = null

var _glb: Node3D = null
var _top: MeshInstance3D = null
var _legs: Array[MeshInstance3D] = []
## המידות הבסיסיות של המודל כפי שיצאו מבלנדר.
var _base_dims := Vector3.ZERO
## כמה מטרים מוסיף כל shape key בעוצמה מלאה.
var _ext_x := 0.0
var _ext_z := 0.0
## התזוזה הממוצעת של כל shape key - וקטור כיוון מלא (כולל סימן),
## כדי שהרגליים יזוזו בדיוק לאן שקצה הראש זז.
var _move_x := Vector3.ZERO
var _move_z := Vector3.ZERO
## הדלתא של כל shape key לכל קודקוד של הראש (תזוזה מהבסיס).
var _top_base_verts := PackedVector3Array()
var _delta_x := PackedVector3Array()
var _delta_z := PackedVector3Array()
## מערכי הפאות של הראש כפי שיצאו מהמודל (הכל חוץ מהקודקודים).
var _top_arrays: Array = []
## חומר הפאה של הראש מהמודל המקורי.
var _top_surface_material: Material = null
## לכל רגל: מיקום הבסיס שלה, תחתית הגיאומטריה שלה ואיזו זרוע היא מזיזה.
var _leg_infos: Array[Dictionary] = []


func _ready() -> void:
	_load_model()
	_prepare_top()
	_prepare_legs()
	_build_materials()
	_center_model()
	# מידות ההתחלה - המודל כמו שיצא מבלנדר.
	dimensions = _base_dims
	# הגיאומטריה נבנתה רק עכשיו (תיבת ההתנגשות לא יכלה למדוד אותה
	# לפני כן) - מודיעים שהמידות "השתנו" כדי שהיא תיבנה מחדש.
	resized.emit()


## טוען את קובץ המודל ומאתר את הראש ואת הרגליים.
func _load_model() -> void:
	var packed := load(GLB_PATH) as PackedScene
	if packed == null:
		push_error("ComputerDesk: לא נמצא קובץ המודל " + GLB_PATH)
		return
	_glb = packed.instantiate()
	_glb.name = "Model"
	add_child(_glb)
	_find_parts(_glb)
	if _top == null:
		push_error("ComputerDesk: לא נמצא ראש שולחן במודל (צומת בלי 'leg' בשם עם רשת).")
		return
	if _legs.is_empty():
		push_warning("ComputerDesk: לא נמצאו רגליים במודל (מחפשים 'leg' בשם הצומת).")


## מפריד בין ראש השולחן לרגליים: כל צומת רשת שבשמו "leg" היא רגל,
## וצומת הרשת הראשון שאינו רגל הוא הראש. עמיד גם לשינויי שמות קטנים
## (רווחים ומספור של הייצוא מבלנדר).
func _find_parts(node: Node3D) -> void:
	var mesh := node as MeshInstance3D
	if mesh != null and mesh.mesh != null:
		var lower := node.name.to_lower()
		if lower.contains("leg"):
			_legs.append(mesh)
		elif _top == null:
			_top = mesh
	for child in node.get_children():
		_find_parts(child as Node3D)


## קורא את הגיאומטריה של הראש ואת שני ה-shape keys, ואופה רשת
## חדשה בלי blend shapes כדי שתיבת התחום תרקוד לגיאומטריה האמיתית.
func _prepare_top() -> void:
	if _top == null:
		return
	var mesh := _top.mesh
	if mesh == null:
		return
	if mesh.get_blend_shape_count() == 0:
		push_warning(
			"ComputerDesk: לראש השולחן אין shape keys. צריך לסמן 'Shape Keys' בחלון הייצוא של glTF בבלנדר ולייצא מחדש."
		)
	_top_arrays = mesh.surface_get_arrays(0)
	_top_base_verts = _top_arrays[Mesh.ARRAY_VERTEX]
	_top_surface_material = mesh.surface_get_material(0)

	var count: int = mesh.get_blend_shape_count()
	var deltas: Array[PackedVector3Array] = []
	for i in count:
		# מערכי ה-shape keys שמיצאו מבלנדר מכילים את המיקום המוחלט של
		# כל קודקוד בעוצמה מלאה - הדלתא האמיתית היא ההפרש מהבסיס.
		var pose: PackedVector3Array = mesh.surface_get_blend_shape_arrays(0)[i][Mesh.ARRAY_VERTEX]
		var delta := PackedVector3Array()
		delta.resize(pose.size())
		for v in pose.size():
			delta[v] = pose[v] - _top_base_verts[v]
		deltas.append(delta)

	# איזה shape key מותח איזה ציר: מזיזים את כל הקודקודים של אותו
	# מפתח לפי הממוצע של התזוזה שלהם, ומשייכים לפי הציר הדומיננטי.
	for i in deltas.size():
		var delta := deltas[i]
		var sum := Vector3.ZERO
		var moved := 0
		for v in delta.size():
			if delta[v].length_squared() > 1e-6:
				sum += delta[v]
				moved += 1
		if moved == 0:
			continue
		var mean := sum / float(moved)
		if absf(mean.x) >= absf(mean.z):
			_delta_x = delta
			_move_x = mean
			_ext_x = absf(mean.x)
		else:
			_delta_z = delta
			_move_z = mean
			_ext_z = absf(mean.z)

	# עכשיו אופים רשת חדשה בלי blend shapes (במצב הבסיסי).
	_bake_top(0.0, 0.0)


## אופה את הרשת של הראש: בסיס + דלתא של X בעוצמה v_x + דלתא של Z
## בעוצמה v_z. התזוזה היא חלקית, כך שכל גודל ביניים נראה טבעי.
func _bake_top(value_x: float, value_z: float) -> void:
	if _top == null or _top_arrays.is_empty():
		return
	var arrays := _top_arrays.duplicate(true)
	var verts := PackedVector3Array()
	verts.resize(_top_base_verts.size())
	for i in _top_base_verts.size():
		var vert := _top_base_verts[i]
		if value_x > 0.0 and _delta_x.size() == _top_base_verts.size():
			vert += _delta_x[i] * value_x
		if value_z > 0.0 and _delta_z.size() == _top_base_verts.size():
			vert += _delta_z[i] * value_z
		verts[i] = vert
	arrays[Mesh.ARRAY_VERTEX] = verts
	var baked := ArrayMesh.new()
	baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	baked.surface_set_material(0, _top_surface_material)
	_top.mesh = baked


## אוסר את המידע של הרגליים: איזו זרוע מזיזה כל רגל ומה תחתית הגיאומטריה
## שלה (לחישוב המתיחה בגובה). ההשייכות נגזרת מהמיקום: רגל שקרובה לקצה
## הימני של הראש זזה עם זרוע X, רגל שקרובה לקצה הקדמי זזה עם זרוע Z.
func _prepare_legs() -> void:
	if _top == null:
		return
	var top_aabb := _top.get_aabb()
	var edge_x := top_aabb.end.x - LEG_EDGE_MARGIN
	var edge_z := top_aabb.position.z + LEG_EDGE_MARGIN
	for leg in _legs:
		var leg_aabb := leg.get_aabb()
		var center := leg_aabb.get_center()
		_leg_infos.append(
			{
				"node": leg,
				"base_pos": leg.position,
				"bottom": leg_aabb.position.y,
				"moves_x": center.x > edge_x,
				"moves_z": center.z < edge_z,
			}
		)


## מעתיק את החומרים מבלנדר לשני חומרים נפרדים - לראש ולרגליים.
func _build_materials() -> void:
	if _top_surface_material != null:
		top_material = _top_surface_material.duplicate() as StandardMaterial3D
	if top_material == null:
		top_material = StandardMaterial3D.new()
		top_material.roughness = 0.6
	if not _legs.is_empty():
		var leg_mat := _legs[0].mesh.surface_get_material(0) if _legs[0].mesh != null else null
		if leg_mat != null:
			legs_material = leg_mat.duplicate() as StandardMaterial3D
	if legs_material == null:
		legs_material = StandardMaterial3D.new()
		legs_material.metallic = 0.9
		legs_material.roughness = 0.3
	_apply_materials()


## מיישר את המודל כך שנקודת המוצא של הסקריפט תהיה בתחתית-המרכז
## של השולחן האמיתי (לפי הרשת האפויה, לא לפי ה-blend shapes).
func _center_model() -> void:
	if _glb == null or _top == null:
		return
	var boxes: Array[AABB] = []
	_collect_aabbs(_glb, Transform3D.IDENTITY, boxes)
	if boxes.is_empty():
		return
	var merged := boxes[0]
	for box in boxes:
		merged = merged.merge(box)
	_base_dims = merged.size
	_glb.position = Vector3(
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


# ------------------------------------------------------------------ מידות

## המידות הנוכחיות: x=רוחב, y=גובה, z=עומק.
func get_dimensions() -> Vector3:
	return dimensions


## קובע מידות חדשות. הרוחב והעומק מוצמדים לטווח שה-shape keys
## מאפשרים (מהמודל הבסיסי ועד המתיחה המלאה), והגובה בין גבולות
## בטיחות. משמיט את resized רק אם באמת השתנה משהו.
func set_dimensions(new_dimensions: Vector3) -> void:
	var clamped := Vector3(
		clampf(new_dimensions.x, _base_dims.x, _base_dims.x + _ext_x),
		clampf(new_dimensions.y, MIN_HEIGHT, MAX_HEIGHT),
		clampf(new_dimensions.z, _base_dims.z, _base_dims.z + _ext_z)
	)
	if clamped.is_equal_approx(dimensions):
		return
	dimensions = clamped
	_apply_dimensions()
	resized.emit()


## מיישם את המידות הנוכחיות על הגיאומטריה.
func _apply_dimensions() -> void:
	var value_x := (dimensions.x - _base_dims.x) / _ext_x if _ext_x > 0.0 else 0.0
	var value_z := (dimensions.z - _base_dims.z) / _ext_z if _ext_z > 0.0 else 0.0
	_bake_top(clampf(value_x, 0.0, 1.0), clampf(value_z, 0.0, 1.0))

	# גובה: הראש עולה בדיוק בתוספת הגובה, הרגליים נמתחות ונשארות
	# על הרצפה (הן ילדים של הראש ולכן מפצות על העלייה).
	var height_delta := dimensions.y - _base_dims.y
	var stretch := dimensions.y / _base_dims.y if _base_dims.y > 0.0 else 1.0
	if _top != null:
		_top.position.y = height_delta
	for info in _leg_infos:
		var leg: MeshInstance3D = info["node"]
		var bottom: float = info["bottom"]
		leg.scale.y = stretch
		leg.position.y = -height_delta + bottom * (1.0 - stretch)
		# הרגליים בקצה הזרועות זזות החוצה יחד עם הראש המתוח.
		var base_pos: Vector3 = info["base_pos"]
		var offset := Vector3(base_pos)
		if info["moves_x"] and _delta_x.size() > 0:
			offset += _move_x * value_x
		if info["moves_z"] and _delta_z.size() > 0:
			offset += _move_z * value_z
		leg.position.x = offset.x
		leg.position.z = offset.z


# ------------------------------------------------------------------ חלקי חומר

## כל חלקי החומר שאפשר לערוך בחלון החומריות.
func get_material_parts() -> Array[StringName]:
	return [PART_TOP, PART_LEGS]


## השם שמוצג לילדים לכל חלק.
func get_part_label(part: StringName) -> String:
	if part == PART_LEGS:
		return "רגליים"
	return "ראש השולחן"


## החומר של חלק מסוים.
func get_part_material(part: StringName) -> StandardMaterial3D:
	if part == PART_LEGS:
		return legs_material
	return top_material


## מחליף את החומר של חלק מסוים.
func set_part_material(part: StringName, material: StandardMaterial3D) -> void:
	if part == PART_LEGS:
		legs_material = material
	else:
		top_material = material
	_apply_materials()


## אילו סטים מותר להחיל על החלק: לרגליים רק פלסטיק ומתכת,
## לראש - הכל (כולל טקסטורות עץ). רשימה ריקה = הכל מותר.
func get_part_presets(part: StringName) -> Array[String]:
	if part == PART_LEGS:
		return ["builtin:plastic", "builtin:metal"]
	return []


## מופע חדש של אותו מודל, לתצוגה המקדימה בחלון החומריות.
## הפאנל מוסיף אותו לעץ ואז מסנכרן אליו מידות וחומרים.
func make_preview() -> Node3D:
	var preview := ComputerDesk.new()
	preview.name = "Preview"
	return preview


## מרענן את החומרים על כל חלקי השולחן.
func _apply_materials() -> void:
	if _top != null:
		_top.material_override = top_material
	for leg in _legs:
		leg.material_override = legs_material
