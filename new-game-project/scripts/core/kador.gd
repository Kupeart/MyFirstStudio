class_name Kador
extends Node3D
## בסיס משותף לכל סוגי הכדורים (כדור ים, רגל, סליים, ברזל).
##
## הסקריפט טוען את קובץ ה-GLB של הכדור, מנרמל את גודלו לקוטר הגיוני,
## מיישר אותו כך שנקודת המוצא תהיה בתחתית-המרכז (הכדור יושב על הרצפה),
## וחושף ממשק אחיד לגיזמו:
##   - get_dimensions() / set_dimensions() - שינוי גובה/גודל.
##   - set_dimensions_around_center()      - גדילה סביב מרכז הכדור.
##   - get_center() / get_local_center()   - מרכז הכדור (שם יושב הגיזמו).
##   - get_default_diameter()              - הקוטר שבו הכדור נוצר.
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
## מרכז הכדור במרחב המקומי של העצם. מתעדכן בכל עיגון (בסיס או מרכז),
## כדי שמרכז הכדור תמיד יהיה ידוע בלי למדוד את הגיאומטריה בכל פריים.
var _center_local := Vector3.ZERO
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
	_apply_default_size()
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


## הקוטר (במטרים) שבו הכדור נוצר כברירת מחדל. קבצים שיוצאים מבלנדר
## מגיעים לפעמים בקנה מידה לא נכון (כדור ענקי), ולכן המנוע מנרמל כל
## כדור לגודל הגיוני לילדים. כל כדור קובע את הקוטר שלו.
func get_default_diameter() -> float:
	return 0.5


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
## כאן נמדדות גם המידות המקוריות של הכדור כפי שיצאו מבלנדר.
func _center_model() -> void:
	if _glb == null:
		return
	var bounds := ModelBoundsScript.base_aabb(_glb)
	if bounds.size == Vector3.ZERO:
		_base_dims = Vector3.ONE
		_center_local = Vector3(0.0, 0.5, 0.0)
		return
	_base_dims = bounds.size
	# הכדור יושב על הבסיס: מרכזו בגובה חצי מהמידה המקורית.
	_anchor_center(_base_dims.y * 0.5)


## ממרכז את המודל בתוך הכדור: אופקית תמיד במרכז, ואנכית כך שמרכז
## הגיאומטריה ייפול בגובה center_height (במרחב המקומי של הכדור).
##
## למה זה נחוץ: הסקייל מתבצע סביב ראשית המודל, ולא סביב מרכז הגיאומטריה.
## בלי העיגון הזה הגיאומטריה נסחפת הצידה והחוצה בכל שינוי מידות - מה
## שגרם לכדור "לגדול מוזר". עיגון למרכז נותן גדילה סימטרית סביב המרכז.
func _anchor_center(center_height: float) -> void:
	_center_local = Vector3(0.0, center_height, 0.0)
	if _glb == null:
		return
	var box := ModelBoundsScript.base_aabb(_glb)
	if box.size == Vector3.ZERO:
		return
	var box_center := box.get_center()
	_glb.position -= Vector3(box_center.x, 0.0, box_center.z)
	_glb.position.y += center_height - box_center.y


## מנרמל את גודל הכדור לקוטר ברירת המחדל. שלושת הצירים מקבלים את אותו
## קוטר, ולכן הכדור נשאר עגול ולא נמתח.
func _apply_default_size() -> void:
	var diameter := get_default_diameter()
	if diameter <= 0.0 or _base_dims == Vector3.ZERO:
		return
	var longest := maxf(maxf(_base_dims.x, _base_dims.y), _base_dims.z)
	if is_equal_approx(longest, diameter):
		return
	set_dimensions(Vector3.ONE * diameter)


## הקופסה התוחמת של הכדור במרחב המקומי (בלי ה-shape keys), עבור
## תיבת ההתנגשות והמירכוז של העצם.
func get_base_bounds() -> AABB:
	if _glb == null:
		return AABB()
	return ModelBoundsScript.base_aabb(_glb)


## מרכז הכדור במרחב המקומי של העצם (מתעדכן בכל עיגון).
func get_local_center() -> Vector3:
	return _center_local


## מרכז הכדור בעולם - שם יושב הגיזמו, ומסביבו הכדור גדל ומתכווץ.
func get_center() -> Vector3:
	return global_transform * _center_local


# ------------------------------------------------------------------ מידות

## המידות הנוכחיות של הכדור במטרים.
func get_dimensions() -> Vector3:
	return dimensions


## קובע את מידות הכדור כשהבסיס נשאר על הרצפה (המרכז בגובה חצי גובה).
## הסקייל מחושב ביחס למידות המקוריות.
func set_dimensions(new_dimensions: Vector3) -> void:
	_apply_dimensions(new_dimensions)
	_anchor_center(dimensions.y * 0.5)
	resized.emit()


## קובע את מידות הכדור כך שיגדל או יקטן סביב מרכזו: מרכז הכדור נשאר
## בגובה center_height (במרחב המקומי), והבסיס נע בהתאם - למטה כשהכדור
## גדל ולמעלה כשהוא קטן. זו הגרירה של עיגול קנה המידה.
func set_dimensions_around_center(new_dimensions: Vector3, center_height: float) -> void:
	_apply_dimensions(new_dimensions)
	_anchor_center(center_height)
	resized.emit()


## מסקייל את המודל ליחס שבין המידות החדשות למקוריות, בלי לעגן אותו.
func _apply_dimensions(new_dimensions: Vector3) -> void:
	dimensions = new_dimensions
	if _glb == null:
		return
	_glb.scale = Vector3(
		new_dimensions.x / maxf(_base_dims.x, 0.001),
		new_dimensions.y / maxf(_base_dims.y, 0.001),
		new_dimensions.z / maxf(_base_dims.z, 0.001)
	)


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
