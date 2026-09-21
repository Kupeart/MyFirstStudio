class_name Kador
extends Node3D
## בסיס משותף לכל סוגי הכדורים (כדור ים, רגל, סליים, ברזל).
##
## הסקריפט טוען את קובץ ה-GLB של הכדור, מיישר אותו כך שנקודת המוצא תהיה
## בתחתית-המרכז (הכדור יושב על הרצפה), וחושף ממשק אחיד לגיזמו:
##   - get_dimensions() / set_dimensions() - שינוי גובה/גודל.
##   - has_shape_keys()                    - האם יש לכדור shape keys.
##   - get_squash_stretch() / set_squash_stretch() - לחיצה/מתיחה.
##
## ה-shape keys בקבצי הכדור אינם אחידים בשמות ("Squash"/"Stretch" מול
## "squash "/"stretch "), ולכן החיפוש אחריהם מתעלם מאותיות גדולות/קטנות
## ורווחים מיותרים.

## נשלח אחרי כל שינוי מידות (לרענון תיבת ההתנגשות).
signal resized

const ModelBoundsScript := preload("res://scripts/core/model_bounds.gd")

## המידות הנוכחיות של הכדור במטרים (x=רוחב, y=גובה, z=עומק).
var dimensions: Vector3 = Vector3.ONE

## מופע ה-GLB שבתוך הכדור.
var _glb: Node3D = null
## הרשת הראשונה שנמצאה (הכדור עצמו).
var _mesh: MeshInstance3D = null
## המידות המקוריות כפי שיצאו מבלנדר.
var _base_dims := Vector3.ONE
## אינדקסים של shape keys הלחיצה והמתיחה (או 1- אם אין).
var _squash_idx := -1
var _stretch_idx := -1
## עוצמת הלחיצה/מתיחה הנוכחית: 1- לחיצה מלאה, 0 נייטרלי, 1+ מתיחה מלאה.
var _squash_stretch := 0.0


func _ready() -> void:
	_load_model()
	_apply_material()
	_center_model()
	dimensions = _base_dims
	resized.emit()


# ------------------------------------------------------------------ נקודות הרחבה

## נתיב קובץ ה-GLB של הכדור. מחייב מימוש בכל תת-מחלקה.
func _glb_path() -> String:
	return ""


## צביעת/טקסטור הכדור. ברירת המחדל שומרת על החומר שיצא מבלנדר.
func _apply_material() -> void:
	pass


## שם הכדור בעברית לתצוגה.
func get_mode_name() -> String:
	return ""


## מזהה סוג הכדור (לתצוגה/בדיקות).
func get_ball_kind() -> StringName:
	return &""


## האם לכדור יש shape keys של לחיצה/מתיחה.
func has_shape_keys() -> bool:
	return _squash_idx >= 0 and _stretch_idx >= 0


# ------------------------------------------------------------------ טעינה

func _load_model() -> void:
	var path := _glb_path()
	if path.is_empty():
		push_error("Kador: אין נתיב GLB עבור " + name)
		return
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Kador: לא ניתן לטעון את המודל " + path)
		return
	_glb = packed.instantiate()
	_glb.name = "Model"
	add_child(_glb)
	_mesh = _find_first_mesh(_glb)
	if _mesh == null:
		push_error("Kador: לא נמצאה רשת במודל " + path)
		return
	var mesh := _mesh.mesh as ArrayMesh
	if mesh != null and mesh.get_blend_shape_count() > 0:
		_squash_idx = _blend_shape_index(mesh, "squash")
		_stretch_idx = _blend_shape_index(mesh, "stretch")


func _find_first_mesh(node: Node) -> MeshInstance3D:
	var mesh := node as MeshInstance3D
	if mesh != null and mesh.mesh != null:
		return mesh
	for child in node.get_children():
		var found := _find_first_mesh(child)
		if found != null:
			return found
	return null


## מוצא shape key לפי שם, בלי תלות באותיות גדולות/קטנות או רווחים מיותרים.
func _blend_shape_index(mesh: ArrayMesh, wanted: String) -> int:
	var target := wanted.strip_edges().to_lower()
	for i in range(mesh.get_blend_shape_count()):
		if mesh.get_blend_shape_name(i).strip_edges().to_lower() == target:
			return i
	return -1


## מזיז את המודל כך שנקודת המוצא תהיה בתחתית-המרכז (הכדור על הרצפה).
func _center_model() -> void:
	if _glb == null:
		return
	var bounds := ModelBoundsScript.base_aabb(_glb)
	if bounds.size == Vector3.ZERO:
		_base_dims = Vector3.ONE
		return
	_base_dims = bounds.size
	var offset := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	_glb.position -= offset


## הקופסה התוחמת של הכדור במרחב המקומי (בלי ה-shape keys), עבור
## תיבת ההתנגשות והמירכוז של העצם.
func get_base_bounds() -> AABB:
	if _glb == null:
		return AABB()
	return ModelBoundsScript.base_aabb(_glb)


## מרכז הכדור בעולם - הראשית שלו היא בתחתית, ולכן מוסיפים חצי גובה.
func get_center() -> Vector3:
	return global_transform * Vector3(0.0, dimensions.y * 0.5, 0.0)


# ------------------------------------------------------------------ מידות

## המידות הנוכחיות של הכדור במטרים.
func get_dimensions() -> Vector3:
	return dimensions


## קובע את מידות הכדור. הסקייל מחושב ביחס למידות המקוריות, כך
## שהכדור גדל/מתכווץ סביב הבסיס שלו.
func set_dimensions(new_dimensions: Vector3) -> void:
	dimensions = new_dimensions
	if _glb == null:
		return
	var factor := Vector3(
		new_dimensions.x / maxf(_base_dims.x, 0.001),
		new_dimensions.y / maxf(_base_dims.y, 0.001),
		new_dimensions.z / maxf(_base_dims.z, 0.001)
	)
	_glb.scale = factor
	resized.emit()


# ------------------------------------------------------------------ לחיצה / מתיחה

## עוצמת הלחיצה/מתיחה הנוכחית (1- לחיצה מלאה, 1+ מתיחה מלאה).
func get_squash_stretch() -> float:
	return _squash_stretch


## קובע את עוצמת הלחיצה/מתיחה. ערך שלילי = לחיצה, חיובי = מתיחה,
## 0 = צורת הכדור הרגילה. אין השפעה אם לכדור אין shape keys.
func set_squash_stretch(value: float) -> void:
	value = clampf(value, -1.0, 1.0)
	_squash_stretch = value
	if _mesh == null:
		return
	if _squash_idx >= 0:
		_mesh.set_blend_shape_value(_squash_idx, maxf(-value, 0.0))
	if _stretch_idx >= 0:
		_mesh.set_blend_shape_value(_stretch_idx, maxf(value, 0.0))


# ------------------------------------------------------------------ עזר

## תצוגה מקדימה לבנק האסטים.
func make_preview() -> Node3D:
	return get_script().new() as Node3D
