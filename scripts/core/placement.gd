class_name StudioPlacement
extends Node3D
## מנוע ההצבה: מלווה גרירה של כרטיס אסט מהבנק אל תוך העולם.
##
## בזמן הגרירה מוצג "אובייקט רפאים" - העתק שקוף של המודל שעוקב אחרי העכבר
## על הרצפה (החזקת Shift מצמדת לרשת של חצי מטר). בשחרור
## העצם נוצר במצב רפאים - מרחף וקצת שקוף עד שלוחצים ✓.
## נוצר העצם האמיתי בדיוק באותו מקום.

const PropScript := preload("res://scripts/core/prop.gd")
const LibraryScript := preload("res://scripts/core/asset_library.gd")

## גודל תא ההצמדה במטרים - זהה לגריד שמצויר על הרצפה.
const GRID_SIZE := 0.5

## כמה שקוף אובייקט הרפאים.
@export var ghost_alpha := 0.45

var _library: LibraryScript = null
var _camera: Camera3D = null
var _props_root: Node3D = null

var _ghost: Node3D = null
var _ghost_id: StringName = &""
## הנקודה האחרונה שחושבה בהצלחה - נשמרת כדי שגרירה אל השמיים לא תעלים את הרפאים.
var _last_point := Vector3.ZERO


func setup(library: LibraryScript, camera: Camera3D, props_root: Node3D) -> void:
	_library = library
	_camera = camera
	_props_root = props_root


func _process(_delta: float) -> void:
	# הגרירה הסתיימה בלי הצבה (שחרור מחוץ למסך, Esc) - מנקים את הרפאים.
	if _ghost != null and not get_viewport().gui_is_dragging():
		cancel_drag()


## מציג או מעדכן את אובייקט הרפאים במקום שעל הרצפה שמתחת לסמן העכבר.
func show_ghost_at(asset_id: StringName, screen_position: Vector2) -> void:
	if _ghost == null or _ghost_id != asset_id:
		_create_ghost(asset_id)
	if _ghost == null:
		return
	_last_point = ground_point(screen_position)
	_ghost.global_position = _last_point


## יוצר עצם אמיתי בעולם במקום מבוקש, ומחזיר אותו (או null).
## משמש גם להצבה בגרירה וגם לשכפול של עצם קיים.
func spawn(asset_id: StringName, at: Vector3) -> Node3D:
	if _library == null:
		return null
	var model := _library.instantiate_asset(asset_id)
	if model == null:
		return null

	var def := _library.get_asset(asset_id)
	var prop: Node3D = PropScript.new()
	prop.setup(asset_id, def.display_name if def != null else String(asset_id), model)
	if _props_root != null:
		_props_root.add_child(prop)
	prop.global_position = at
	return prop


## יוצר את העצם האמיתי במקום שאליו נגרר הכרטיס ומחזיר אותו (או null).
func finish_drop(asset_id: StringName, screen_position: Vector2) -> Node3D:
	var point := ground_point(screen_position)
	cancel_drag()
	return spawn(asset_id, point)


## יוצר עותק מדויק של עצם קיים במקום מבוקש: אותו סיבוב ואותן מידות
## בדיוק כפי שהן ברגע הנתון. spawn() לבדו נותן את מצב ברירת המחדל של
## המודל מהספרייה - כאן מעבירים גם את ה-basis של המקור.
func spawn_copy_of(source: Node3D, at: Vector3) -> Node3D:
	if source == null:
		return null
	var copy := spawn(source.asset_id, at)
	if copy == null:
		return null
	copy.global_transform = Transform3D(source.global_basis, at)
	# שולחן פרוצדורלי - מעתיקים גם את המידות והחומר, לא רק את הסיבוב.
	var source_model: Node3D = source.get_model()
	var copy_model: Node3D = copy.get_model()
	if source_model == null or copy_model == null:
		return copy
	if not source_model.has_method("set_dimensions") or not copy_model.has_method("set_dimensions"):
		return copy
	copy_model.set_dimensions(source_model.get_dimensions())
	if source_model.has_method("get_material") and copy_model.has_method("set_material"):
		var source_material: StandardMaterial3D = source_model.get_material()
		copy_model.set_material(source_material.duplicate() as StandardMaterial3D)
	return copy


## מסלק את אובייקט הרפאים.
func cancel_drag() -> void:
	if _ghost != null:
		# מסלקים מהעץ מיד - queue_free משחרר רק בסוף הפריים.
		remove_child(_ghost)
		_ghost.queue_free()
		_ghost = null
	_ghost_id = &""


## נקודת ההצבה על הרצפה (y = 0) שמתחת לנקודה על המסך, אחרי הצמדה לרשת.
func ground_point(screen_position: Vector2) -> Vector3:
	if _camera == null:
		return _last_point
	var from := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	# קרן כמעט אופקית לא פוגשת את הרצפה - נשארים במקום האחרון.
	if absf(direction.y) < 0.0001:
		return _last_point
	var distance := -from.y / direction.y
	if distance <= 0.0:
		# העכבר מצביע אל השמיים.
		return _last_point
	var point := from + direction * distance
	return Vector3(_snap(point.x), 0.0, _snap(point.z))


# ------------------------------------------------------------------ פנימי

func _create_ghost(asset_id: StringName) -> void:
	cancel_drag()
	if _library == null:
		return
	var model := _library.instantiate_asset(asset_id)
	if model == null:
		return
	_apply_ghost_look(model)
	_ghost = model
	_ghost_id = asset_id
	add_child(_ghost)
	_ghost.global_position = _last_point


## המודל של הרפאים נראה כמו זכוכית כחולה שקופה, בלי צל, כדי שיהיה ברור
## שזה עדיין לא עצם אמיתי.
func _apply_ghost_look(root: Node) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.86, 1.0, ghost_alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_set_ghost_material(root, material)


func _set_ghost_material(node: Node, material: Material) -> void:
	var mesh := node as MeshInstance3D
	if mesh != null:
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_ghost_material(child, material)


## הצמדה לרשת של חצי מטר. ברירת מחדל - תנועה חופשית.
## החזקת Shift בזמן גרירה מצמדת לרשת.
func _snap(value: float) -> float:
	if not Input.is_key_pressed(KEY_SHIFT):
		return value
	return snappedf(value, GRID_SIZE)
