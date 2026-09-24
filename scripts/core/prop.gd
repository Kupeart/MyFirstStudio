class_name Prop
extends Node3D
## עצם שהמשתמש הציב בעולם הסטודיו.
##
## המבנה של כל עצם:
##   Prop  (Node3D - הסקריפט הזה, נקודת המוצא בתחתית-המרכז של העצם)
##     ├─ Model (Node3D - המודל שיצא מבלנדר)
##     └─ Body  (StaticBody3D, שכבת "props")
##          └─ Collision (CollisionShape3D - תיבה בגודל המודל)
##
## תיבת ההתנגשות היא מה שמאפשר ללחוץ על העצם ולבחור בו.
## מזיזים ומסובבים תמיד את העצם השלם (Prop), לא את המודל שבתוכו.
##
## סימון בחירה: עצם שנבחר נשאר מוצק לגמרי במקומו, ומקבל מתאר צהוב דק
## סביב הצללית שלו (ראו selection_outline.tres). המתאר לא מכסה את העצם
## ולא משנה את מיקומו - רואים בדיוק מה יש בעולם.

const ModelBoundsScript := preload("res://scripts/core/model_bounds.gd")
## חומר המסגרת שמסמן את העצם הנבחר.
const OutlineMaterial := preload("res://assets/materials/selection_outline.tres")

## שכבת הפיזיקה של העצים (שכבה 1 היא הרצפה). משמשת את מנוע הבחירה.
const LAYER := 2
## הקבוצה שכל עצם בעולם מצטרף אליה, כדי שמנוע הבחירה ימצא אותו בקלות.
const GROUP := "props"

## נשלח כשסימון הבחירה של העצם משתנה.
signal selection_changed(prop: Node3D, selected: bool)

## המזהה של האסט שממנו נוצר העצם.
var asset_id: StringName = &""
## השם שמוצג לילדים.
var display_name: String = ""

var _model: Node3D = null
var _body: StaticBody3D = null
var _meshes: Array[MeshInstance3D] = []
var _selected := false


## בונה את העצם סביב מודל מוכן (המודל כבר מיושר לתחתית-המרכז).
## קוראים לזה מיד אחרי שיצרנו את העצם עם Script.new().
func setup(id: StringName, label: String, model: Node3D) -> void:
	name = "Prop_%s" % String(id)
	asset_id = id
	display_name = label
	add_to_group(GROUP)
	_model = model
	_model.name = "Model"
	add_child(_model)
	_collect_meshes(_model)
	_add_collision()


## המודל שבתוך העצם (למשל שולחן פרוצדורלי). משמש את הגיזמו ואת
## חלון החומריות כדי להגיע לחלקים הפרוצדורליים של העצם.
func get_model() -> Node3D:
	return _model


## האם העצם מסומן כרגע (המסגרת הצהובה מוצגת).
func is_selected() -> bool:
	return _selected


## מדליק או מכבה את סימון הבחירה.
func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	_refresh_outline()
	selection_changed.emit(self, value)


## מסגרת הסימון הצהובה סביב הצללית. מוצגת אך ורק כשהעצם נבחר -
## העצם עצמו נשאר מוצק במקומו, בלי שקיפות ובלי תזוזה.
func _refresh_outline() -> void:
	var mat: Material = null
	if _selected:
		mat = OutlineMaterial
	for mesh in _meshes:
		mesh.material_overlay = mat


## האם מסגרת הסימון מוצגת כרגע.
func is_outlined() -> bool:
	if not _selected or _meshes.is_empty():
		return false
	return _meshes[0].material_overlay != null


## הגודל האמיתי של העצם במטרים.
func get_size() -> Vector3:
	return _bounds().size


## מרכז העצם בעולם - סביבו מוצג הגיזמו של ההזזה.
func get_center() -> Vector3:
	var bounds := _bounds()
	return global_transform * bounds.get_center()


## מרכז הבסיס של העצם (על הרצפה) - הנקודה שממנה יוצאת קרן הבחירה.
func get_base_center() -> Vector3:
	var bounds := _bounds()
	var local := Vector3(bounds.get_center().x, 0.0, bounds.get_center().z)
	return global_transform * local


## התיבה התוחמת של המודל. מודל עם shape keys (כמו הכדורים) מספק את
## התיבה של הגיאומטריה הבסיסית, כדי שתיבת ההתנגשות והמירכוז לא יהיו
## מנופחים בגלל הדפורמציות.
func _bounds() -> AABB:
	if _model != null and _model.has_method("get_base_bounds"):
		return _model.get_base_bounds()
	return ModelBoundsScript.combined_aabb(_model)


func _add_collision() -> void:
	var bounds := _bounds()
	var size := Vector3(
		maxf(bounds.size.x, 0.05),
		maxf(bounds.size.y, 0.05),
		maxf(bounds.size.z, 0.05)
	)
	var box := BoxShape3D.new()
	box.size = size

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	shape.shape = box
	# מרכז התיבה לפי מרכז הגיאומטריה בפועל (בדרך כלל חצי גובה) - כך
	# היא נשארת עוטפת את העצם גם כשכדור גדל סביב מרכזו והבסיס שלו יורד.
	shape.position = bounds.get_center()

	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = LAYER
	_body.collision_mask = 0
	_body.add_child(shape)
	add_child(_body)
	# מודל שיודע לשנות את גודלו (כמו שולחן פרוצדורלי) מרענן את
	# תיבת ההתנגשות מיד כשזה קורה.
	if _model.has_signal("resized"):
		if not _model.resized.is_connected(refresh_collision):
			_model.resized.connect(refresh_collision)


## מרענן את תיבת ההתנגשות לפי הגיאומטריה הנוכחית של המודל.
## נקרא אוטומטית כשהמודל משנה את גודלו (אות resized).
func refresh_collision() -> void:
	if _body == null:
		return
	var shape_node := _body.get_node_or_null("Collision") as CollisionShape3D
	if shape_node == null:
		return
	var bounds := _bounds()
	if bounds.size == Vector3.ZERO:
		return
	var size := Vector3(
		maxf(bounds.size.x, 0.05),
		maxf(bounds.size.y, 0.05),
		maxf(bounds.size.z, 0.05)
	)
	var box := shape_node.shape as BoxShape3D
	if box != null:
		box.size = size
	shape_node.position = bounds.get_center()


func _collect_meshes(node: Node) -> void:
	var mesh := node as MeshInstance3D
	if mesh != null:
		_meshes.append(mesh)
	for child in node.get_children():
		_collect_meshes(child)
