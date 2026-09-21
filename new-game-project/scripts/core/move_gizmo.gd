class_name MoveGizmo
extends Node3D
## גיזמו ההזזה והסיבוב של העצם הנבחר:
##   מצב הזזה (TRANSLATE): שלושה חצים צבעוניים (X אדום, Y ירוק, Z כחול)
##                         וידית צהובה במרכז להזזה חופשית על הרצפה.
##   מצב סיבוב (ROTATE):    שלוש טבעות סיבוב (אדום/ירוק/כחול) סביב מרכז העצם.
##
## הגיזמו מוצג רק על העצם הנבחר, נשמר בגודל קבוע על המסך (גדל עם המרחק
## מהמצלמה), ומצויר מעל שאר העולם כדי שתמיד אפשר יהיה לתפוס אותו.
##
## הצמדה: גרירה ברירת מחדל היא תנועה חופשית. החזקת Shift בזמן גרירה
## מצמדת את העצם לרשת (0.5 מ' אופקי, 0.25 מ' בגובה, וסיבוב בצעדים גלובליים של 15 מעלות).
##
## ביטול גרירה: לחיצה על מקש ימני בעכבר (RMB) תוך כדי גרירה מבטלת ומחזירה
## את העצם במדויק לטרנספורמציה ההתחלתית שלו (כמו בבלנדר).

## מצב הגיזמו: הזזה, סיבוב או קנה מידה.
enum GizmoMode { TRANSLATE, ROTATE, SCALE }

## איזו ידית נגררת כרגע.
enum Handle {
	NONE,
	AXIS_X,
	AXIS_Y,
	AXIS_Z,
	GROUND,
	ROTATE_X,
	ROTATE_Y,
	ROTATE_Z,
	SCALE_X,
	SCALE_Y,
	SCALE_Z,
	SCALE_UNIFORM,
	RESIZE_WIDTH,
	RESIZE_LENGTH,
	RESIZE_HEIGHT,
	KADOR_SCALE,
	LACHITZA_MATICHAH,
}

## מידות החץ, ביחס לגודל הגיזמו.
const SHAFT := 1.15
const SHAFT_WIDTH := 0.045
const TIP_LENGTH := 0.3
const TIP_RADIUS := 0.085
## רדיוס התפיסה של הצירים ושל הידית המרכזית.
const GRAB_RADIUS := 0.17
const GROUND_GRAB_RADIUS := 0.24
## גודל הידית המרכזית להזזה חופשית על הרצפה.
const GROUND_HANDLE_SIZE := Vector3(0.3, 0.03, 0.3)
## המרחק שבו הגיזמו נחשב "בגודל אחד" - ממנו נגזר הגודל הקבוע על המסך.
const REFERENCE_DISTANCE := 13.0
## גודל תא ההצמדה (זהה לרשת שעל הרצפה ולמנוע ההצבה).
const GRID_SIZE := 0.5
## הצמדה עדינה יותר בגובה, כדי שאפשר יהיה להרים עצמים בקפיצות קטנות.
const HEIGHT_STEP := 0.25

## רדיוס ועובי טבעת הסיבוב, וקצב הסיבוב כשמחזיקים Shift.
const RING_RADIUS := 1.30
const RING_TUBE := 0.035
const RING_SEGMENTS := 64
const RING_TUBE_SEGMENTS := 8
const ROTATION_STEP := 15.0

## אינדיקציית ריחוף: כמה מגדילים ידית כשהעכבר עומד עליה, וכמה מערבבים
## את הצבע שלה עם לבן כדי שיהיה ברור איזו ידית נתפסת.
const HOVER_SCALE_BOOST := 1.3
const HOVER_BRIGHTEN := 0.45
## מרחקים כמעט-שווים בזיהוי טבעות - מעדיפים את החלק הקרוב למצלמה.
const RING_TIE_EPSILON := 0.02

## גיזמו קנה מידה: אורך כל ציר, גודל הקוביות בקצוות ובמרכז,
## ורדיוס התפיסה של הקובייה המרכזית (הגדלה אחידה).
const SCALE_AXIS_LENGTH := 1.15
const SCALE_CUBE_SIZE := 0.17
const SCALE_CENTER_SIZE := 0.21
const CENTER_GRAB_RADIUS := 0.24
## קנה המידה המינימלי (כדי שאי אפשר לאפס עצם) וקפיצת ההצמדה עם Shift.
const SCALE_MIN := 0.1
const SCALE_STEP := 0.25

## גיזמו שינוי הגודל של השולחן הפרוצדורלי: שלושה חצים בראש מרובע.
## רוחב (X) ואורך (Z) מותחים רק את הראש; גובה (Y) מאריך את הרגליים.
const RESIZE_AXIS_LENGTH := 1.15
const RESIZE_SHAFT_WIDTH := 0.05
const RESIZE_TIP_SIZE := 0.16
const RESIZE_TIP_LENGTH := 0.26
const RESIZE_STEP := 0.25

## ההנדלים שמידל המשתמש (ScaleHandler.glb) מחליפים את חצי שינוי הגודל:
## מוט עם ראש משושה בקצה, שמוצמד לקצה השולחן וצף ממנו החוצה -
## כמו בסקיצה: ירוק מותח רוחב, אדום עומק, כחול גובה.
const HANDLE_GLB := "res://assets/models/UI/ScaleHandler.glb"
## צבעי ההנדלים כמו בעיצוב של המשתמש.
const RESIZE_WIDTH_COLOR := Color(0.16, 0.88, 0.16)
const RESIZE_LENGTH_COLOR := Color(0.93, 0.26, 0.26)
const RESIZE_HEIGHT_COLOR := Color(0.35, 0.55, 0.98)

## גיזמו הכדור: עיגול קנה מידה אחיד במרכז הכדור (טורקיז) שמשנה את כל
## גודל הכדור, וידית לחיצה/מתיחה (אדום) מעל הכדור שמערבבת את ה-shape keys.
const KADOR_HANDLE_LENGTH := 1.05
const KADOR_SHAFT_WIDTH := 0.06
const KADOR_TIP_SIZE := 0.2
const KADOR_TIP_LENGTH := 0.28
const KADOR_MATICH_COLOR := Color(0.93, 0.26, 0.26)
const KADOR_SCALE_COLOR := Color(0.25, 0.9, 0.6)
## עיגול קנה המידה של הכדור: רדיוס, עובי, מספר מקטעים ורדיוס התפיסה
## (ביחידות הגיזמו - כמו טבעות הסיבוב).
const KADOR_RING_RADIUS := 1.15
const KADOR_RING_TUBE := 0.05
const KADOR_RING_SEGMENTS := 64
const KADOR_RING_TOLERANCE := 0.16
## כמה לחיצה/מתיחה לכל פיקסל גרירה של ידית הלחיצה/מתיחה.
const KADOR_SQUASH_PER_PIXEL := 0.006
## טווח קנה המידה של הכדור (יחס לגודל המקורי).
const KADOR_SCALE_MIN := 0.2
const KADOR_SCALE_MAX := 4.0

const X_COLOR := Color(0.93, 0.26, 0.26)
const Y_COLOR := Color(0.35, 0.85, 0.35)
const Z_COLOR := Color(0.35, 0.55, 0.98)
const GROUND_COLOR := Color(1.0, 0.85, 0.15)
## צבע הקובייה המרכזית של גיזמו קנה המידה (הגדלה אחידה).
const CENTER_COLOR := Color(0.95, 0.96, 0.99)

## נשלח כשמתחילים או מסיימים גרירת ידית.
signal drag_started(handle: int)
signal drag_finished()
signal drag_cancelled()
signal mode_changed(new_mode: GizmoMode)

var _camera: Camera3D = null
## העצמים שהגיזמו עובד עליהם - אובייקט בודד או קבוצת בחירה שלמה.
var _targets: Array[Node3D] = []
var _mode: GizmoMode = GizmoMode.TRANSLATE
var _active: Handle = Handle.NONE
var _axes: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
## צומת מחזיק לחצי ההזזה ולידית הקרקע.
var _arrows_root: Node3D = null
## הצומת שמחזיק את טבעות הסיבוב - מוצב במרכז העצם (לא בבסיס).
var _ring_origin: Node3D = null
## הצומת שמחזיק את ידיות קנה המידה.
var _scale_root: Node3D = null
## הצומת שמחזיק את חצי שינוי הגודל של השולחן הפרוצדורלי.
var _resize_root: Node3D = null
## השולחן שנערך כרגע (המודל שבתוך העצם הנבחר), או null.
var _resize_table: Node3D = null
## המידות של השולחן בתחילת גרירת שינוי גודל - לביטול בקליק ימני.
var _resize_start_dims := Vector3.ZERO
## הרשת של ההנדל שמידל המשתמש (או null אם הקובץ חסר - ואז משתמשים
## בחצים מלבניים רגילים), אורכו והיסט ההצמדה של הגיאומטריה.
var _handle_mesh: Mesh = null
var _handle_length := 0.5
## כל ידית שינוי גודל: הצומת שלה, הציר שלה והכיוון שהיא צפה אליו.
var _resize_holders: Array[Dictionary] = []
## הסיבוב של גיזמו קנה המידה - תואם לסיבוב העצם הנבחר, כך שהצירים
## שלו הם הצירים המקומיים של העצם (ורק גיזמו קנה המידה מקומי - ההזזה
## והסיבוב נשארים בצירי העולם).
var _scale_rotation: Basis = Basis.IDENTITY

## הצומת שמחזיק את ידיות הכדור (גובה ולחיצה/מתיחה).
var _ball_root: Node3D = null
## הכדור שנערך כרגע (המודל שבתוך העצם הנבחר), או null.
var _ball: Node3D = null
## כל ידית כדור: הצומת שלה והידית.
var _ball_holders: Array[Dictionary] = []
## מצב הכדור בתחילת גרירה - לביטול בקליק ימני.
var _ball_start_dims := Vector3.ZERO
var _ball_start_squash := 0.0
## נקודת העכבר בתחילת גרירת ידית כדור.
var _ball_grab_point := Vector2.ZERO
## מרחק העכבר ממרכז הכדור (על המסך) בתחילת גרירת קנה המידה.
var _ball_scale_start_distance := 1.0
## גובה מרכז הכדור (במרחב המקומי) בתחילת הגרירה - סביב הגובה הזה
## הכדור גדל, כך שמרכזו נשאר בדיוק במקום שבו יושב הגיזמו.
var _ball_center_height := 0.0

## מצב הגרירה: הטרנספורמציות המקוריות של כל העצמים, ומרכז הקבוצה -
## לצורך חישוב התנועה/סיבוב וצורך ביטול (RMB cancel).
var _start_transforms: Array[Transform3D] = []
var _start_center := Vector3.ZERO
## מצב גרירת הזזה:
var _grab_axis_point := Vector3.ZERO
var _grab_ground_point := Vector3.ZERO
var _grab_position := Vector3.ZERO
## מצב גרירת סיבוב במרחב תלת-ממדי:
var _ring_plane_center := Vector3.ZERO
var _ring_plane_normal := Vector3.UP
var _ring_grab_vector := Vector3.ZERO
var _accumulated_angle := 0.0
## מרחק העכבר ממרכז הגיזמו בתחילת גרירת קנה מידה אחידה.
var _scale_start_distance := 1.0
## מיפוי ידית -> הצומת שמציג אותה (להגדלה והבהרה בזמן ריחוף).
var _handle_nodes: Dictionary = {}
## הידית שהעכבר עומד עליה כרגע (בלי לגרור).
var _hovered: Handle = Handle.NONE
## נקודת התפיסה בעולם שנמצאה בזיהוי הידית האחרון.
var _picked_grab_point := Vector3.ZERO


func _ready() -> void:
	_arrows_root = Node3D.new()
	_arrows_root.name = "ArrowsRoot"
	add_child(_arrows_root)

	_ring_origin = Node3D.new()
	_ring_origin.name = "RingOrigin"
	add_child(_ring_origin)

	_scale_root = Node3D.new()
	_scale_root.name = "ScaleRoot"
	add_child(_scale_root)

	_resize_root = Node3D.new()
	_resize_root.name = "ResizeRoot"
	add_child(_resize_root)

	_ball_root = Node3D.new()
	_ball_root.name = "BallRoot"
	add_child(_ball_root)

	_build()
	_build_rings()
	_build_scale()
	_handle_mesh = _load_handle_mesh()
	_build_resize()
	_build_ball_handles()
	_update_mode_visibility()
	visible = false


## טוען את הרשת של ההנדל שמידל המשתמש (ScaleHandler.glb).
## מחזיר null אם הקובץ חסר - ואז שינוי הגודל מציג חצים מלבניים רגילים.
func _load_handle_mesh() -> Mesh:
	var packed := load(HANDLE_GLB) as PackedScene
	if packed == null:
		push_warning("MoveGizmo: לא נמצא קובץ ההנדלים " + HANDLE_GLB + " - שינוי הגודל יציג חצים רגילים.")
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return null
	var mesh := _find_first_mesh(instance)
	if mesh == null:
		push_warning("MoveGizmo: בקובץ ההנדלים " + HANDLE_GLB + " אין רשת תלת-ממדית.")
		instance.free()
		return null
	# אורך ההנדל והיסט ההצמדה של הגיאומטריה שלו (המוט מתחיל ב-z=0
	# והראש המשושה בקצה).
	_handle_length = mesh.get_aabb().size.z
	# המופע הזמני שימש רק למציאת הרשת - משחררים אותו.
	instance.free()
	return mesh


func _find_first_mesh(node: Node3D) -> Mesh:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		return mesh_instance.mesh
	for child in node.get_children():
		var found := _find_first_mesh(child as Node3D)
		if found != null:
			return found
	return null


func _process(_delta: float) -> void:
	if not _targets.is_empty():
		refresh()
	_update_hover()


## מעדכן איזו ידית מודגשת לפי מיקום העכבר הנוכחי.
## בזמן גרירה, מעל ממשק או בלי עצם נבחר - לא מדליקים כלום.
func _update_hover() -> void:
	if _targets.is_empty() or not visible or is_dragging() or _camera == null:
		_set_hovered(Handle.NONE)
		return
	if _mouse_over_interface():
		_set_hovered(Handle.NONE)
		return
	_set_hovered(_handle_at_screen(get_viewport().get_mouse_position()))


## מעביר את מצב הריחוף לידית אחרת - מכבה את הקודמת ומדליק את החדשה.
func _set_hovered(handle: Handle) -> void:
	if _hovered == handle:
		return
	if _hovered != Handle.NONE:
		_apply_hover_style(_hovered, false)
	_hovered = handle
	if _hovered != Handle.NONE:
		_apply_hover_style(_hovered, true)


## מגדיל ומבהיר את הידית (או מחזיר אותה למצב הרגיל).
func _apply_hover_style(handle: Handle, hovered: bool) -> void:
	var node := _handle_nodes.get(handle) as Node3D
	if node == null:
		return
	node.scale = Vector3.ONE * (HOVER_SCALE_BOOST if hovered else 1.0)
	var color := _handle_color_of(handle)
	var target := color.lerp(Color.WHITE, HOVER_BRIGHTEN) if hovered else color
	_set_group_material(node, _gizmo_material(target))


## הצבע המקורי של ידית.
func _handle_color_of(handle: Handle) -> Color:
	for axis in _axes:
		if axis["handle"] == handle:
			return axis["color"]
	for ring in _rings:
		if ring["handle"] == handle:
			return ring["color"]
	if handle == Handle.GROUND:
		return GROUND_COLOR
	if handle == Handle.SCALE_UNIFORM:
		return CENTER_COLOR
	for axis in _axes:
		if _scale_handle_of(axis["handle"]) == handle:
			return axis["color"]
	if _is_resizing_handle(handle):
		return _resize_handle_color(handle)
	if handle == Handle.KADOR_SCALE:
		return KADOR_SCALE_COLOR
	if handle == Handle.LACHITZA_MATICHAH:
		return KADOR_MATICH_COLOR
	return Color.WHITE


## מחליף את החומר של כל הרשתות שתחת הצומת.
func _set_group_material(node: Node, material: Material) -> void:
	var mesh := node as MeshInstance3D
	if mesh != null:
		mesh.material_override = material
	for child in node.get_children():
		_set_group_material(child, material)


## האם העכבר נמצא מעל רכיב ממשק שתופס לחיצות (כפתור, פאנל וכו').
func _mouse_over_interface() -> bool:
	var control := get_viewport().gui_get_hovered_control()
	while control != null:
		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			return true
		control = control.get_parent_control()
	return false


## מחבר את הגיזמו למצלמה - ממנה מגיעה קרן העכבר.
func setup(camera: Camera3D) -> void:
	_camera = camera


## קובע את מצב הגיזמו: הזזה (TRANSLATE) או סיבוב (ROTATE).
func set_mode(new_mode: GizmoMode) -> void:
	if _mode == new_mode:
		return
	if is_dragging():
		cancel_drag()
	_set_hovered(Handle.NONE)
	_mode = new_mode
	_update_mode_visibility()
	mode_changed.emit(_mode)


## מחזיר את המצב הנוכחי.
func get_mode() -> GizmoMode:
	return _mode


## מעדכן נראות של רכיבי ההזזה מול רכיבי הסיבוב ומול קנה המידה.
func _update_mode_visibility() -> void:
	# במצב קנה מידה: כדור בודד מקבל ידיות גובה ולחיצה/מתיחה; שולחן
	# פרוצדורלי מקבל חצי שינוי גודל; כל עצם אחר מקבל את גיזמו הקוביות.
	var ball := _find_ball()
	var show_ball := _mode == GizmoMode.SCALE and ball != null
	var show_resize := _mode == GizmoMode.SCALE and not show_ball and _find_resize_table() != null
	if _arrows_root != null:
		_arrows_root.visible = (_mode == GizmoMode.TRANSLATE)
	if _ring_origin != null:
		_ring_origin.visible = (_mode == GizmoMode.ROTATE)
	if _scale_root != null:
		_scale_root.visible = (_mode == GizmoMode.SCALE) and not show_ball and not show_resize
	if _resize_root != null:
		_resize_root.visible = show_resize
	if _ball_root != null:
		_ball_root.visible = show_ball
		var has_keys: bool = ball != null and ball.has_method("has_shape_keys") and ball.has_shape_keys()
		for entry in _ball_holders:
			# ידית הלחיצה/מתיחה מוצגת רק לכדור שיש לו shape keys (לא לברזל).
			var is_matich: bool = entry["handle"] == Handle.LACHITZA_MATICHAH
			(entry["node"] as Node3D).visible = show_ball and (has_keys or not is_matich)


## מצמיד את הגיזמו לעצם אחד ומציג אותו.
func attach_to(prop: Node3D) -> void:
	if prop == null:
		attach_to_group([])
	else:
		attach_to_group([prop])


## מצמיד גיזמו משותף אחד לכל הקבוצה. הגיזמו יושב במרכז העצמים,
## וגרירה שלו מזיזה או מסובבת את כולם יחד כאילו היו עצם אחד.
func attach_to_group(props: Array) -> void:
	if is_dragging():
		cancel_drag()
	_set_hovered(Handle.NONE)
	_targets.clear()
	for prop in props:
		if prop != null and is_instance_valid(prop):
			_targets.append(prop)
	_active = Handle.NONE
	visible = not _targets.is_empty()
	_update_mode_visibility()
	refresh()


## מסתיר את הגיזמו (לא נבחר שום עצם).
func detach() -> void:
	if is_dragging():
		cancel_drag()
	_targets.clear()
	_active = Handle.NONE
	_set_hovered(Handle.NONE)
	visible = false


## האם המשתמש גורר כרגע ידית.
func is_dragging() -> bool:
	return _active != Handle.NONE


## ביטול גרירה מיידי (קליק ימני כמו בבלנדר):
## מחזיר את כל העצמים בגרירה בדיוק לטרנספורמציות שהיו להם בתחילתה.
func cancel_drag() -> void:
	if _active == Handle.NONE:
		return
	# ביטול שינוי גודל: מחזירים את המידות שהיו בתחילת הגרירה.
	if _is_resizing_handle(_active) and _resize_table != null and is_instance_valid(_resize_table):
		if _resize_table.has_method("set_dimensions"):
			_resize_table.set_dimensions(_resize_start_dims)
	# ביטול עריכת כדור: מחזירים גם את המידות וגם את מצב הלחיצה/מתיחה.
	if _is_ball_handle(_active) and _ball != null and is_instance_valid(_ball):
		# מחזירים בדיוק למצב שלפני הגרירה - כולל מיקום מרכז הכדור.
		if _ball.has_method("set_dimensions_around_center"):
			_ball.set_dimensions_around_center(_ball_start_dims, _ball_center_height)
		elif _ball.has_method("set_dimensions"):
			_ball.set_dimensions(_ball_start_dims)
		if _ball.has_method("set_squash_stretch"):
			_ball.set_squash_stretch(_ball_start_squash)
	_active = Handle.NONE
	for i in _targets.size():
		var target := _targets[i]
		if is_instance_valid(target) and i < _start_transforms.size():
			target.global_transform = _start_transforms[i]
	refresh()
	drag_cancelled.emit()
	drag_finished.emit()


## ממקם את הגיזמו בבסיס מרכז הקבוצה ומכוונן את גודלו לפי המרחק מהמצלמה,
## כך שהוא ייראה באותו גודל על המסך בכל זום.
## הטבעות ממוקמות במרכז הקבוצה (שם הגיזמו מסתובב).
func refresh() -> void:
	if not is_dragging():
		_prune_targets()
	if _targets.is_empty():
		detach()
		return
	# בזמן קנה מידה הגיזמו נשאר במקומו - נקודת הסכימה לא זזה באמצע הגרירה.
	if not _is_scaling():
		# כדור: הגיזמו יושב במרכז הכדור (כמו טבעות הסיבוב); כל עצם אחר
		# יושב במרכז הבסיס שעל הרצפה.
		if _find_ball() != null:
			global_position = _group_center()
		else:
			global_position = _group_base_center()
		if _ring_origin != null:
			_ring_origin.global_position = _group_center()
		_update_scale_orientation()
	if _camera != null:
		var distance := _camera.global_position.distance_to(global_position)
		scale = Vector3.ONE * maxf(distance / REFERENCE_DISTANCE, 0.05)
	if _mode == GizmoMode.SCALE:
		_update_resize_handles()
		_update_ball_handles()


## האם מתבצעת כרגע גרירת קנה מידה או שינוי גודל פרוצדורלי.
func _is_scaling() -> bool:
	return (
		_active == Handle.SCALE_X
		or _active == Handle.SCALE_Y
		or _active == Handle.SCALE_Z
		or _active == Handle.SCALE_UNIFORM
		or _is_resizing_handle(_active)
		or _is_ball_handle(_active)
	)


## גיזמו קנה המידה מקומי: הצירים מסתובבים יחד עם העצם הנבחר, כך שגרירת
## ידית מותחת את העצם בדיוק לאורך הציר שהידית מראה - בלי גזירה.
## בקבוצה מסובבים לפי העצם הראשי (האחרון שנבחר).
func _update_scale_orientation() -> void:
	if _scale_root == null or _targets.is_empty():
		_scale_rotation = Basis.IDENTITY
		return
	var primary: Node3D = _targets[_targets.size() - 1]
	if primary == null or not is_instance_valid(primary):
		_scale_rotation = Basis.IDENTITY
		return
	_scale_rotation = primary.global_basis.orthonormalized()
	_scale_root.basis = _scale_rotation
	if _resize_root != null:
		_resize_root.basis = _scale_rotation


## מוצא את המודל הפרוצדורלי שניתן לשנות את גודלו מתוך העצמים הנבחרים.
## חצי שינוי הגודל מוצגים רק כשנבחר עצם אחד שהמודל שלו תומך בזה
## (כרגע: שולחן פרוצדורלי).
func _find_resize_table() -> Node3D:
	if _targets.size() != 1:
		return null
	var target: Node3D = _targets[0]
	if target == null or not is_instance_valid(target):
		return null
	if not target.has_method("get_model"):
		return null
	var model: Node3D = target.get_model()
	if model == null or not is_instance_valid(model):
		return null
	# כדור מטופל בידיות משלו (גובה ולחיצה/מתיחה), לא בחצי שינוי הגודל.
	if model.has_method("has_shape_keys") or model.has_method("get_ball_kind"):
		return null
	if model.has_method("set_dimensions") and model.has_method("get_dimensions"):
		return model
	return null


## מוצא את הכדור שבתוך העצם הנבחר (אם נבחר כדור בודד).
## העצם יכול להיות עטוף ב-Prop (עם get_model) או להיות הכדור עצמו.
func _find_ball() -> Node3D:
	if _targets.size() != 1:
		return null
	var target: Node3D = _targets[0]
	if target == null or not is_instance_valid(target):
		return null
	if _is_ball(target):
		return target
	if target.has_method("get_model"):
		var model: Node3D = target.get_model()
		if model != null and is_instance_valid(model) and _is_ball(model):
			return model
	return null


## האם הצומת הוא כדור שאפשר לערוך בגיזמו הכדור.
static func _is_ball(node: Node3D) -> bool:
	return (
		node.has_method("has_shape_keys")
		and node.has_method("set_squash_stretch")
		and node.has_method("get_dimensions")
		and node.has_method("set_dimensions")
	)


## האם הידית היא ידית של שינוי גודל פרוצדורלי.
func _is_resizing_handle(handle: Handle) -> bool:
	return (
		handle == Handle.RESIZE_WIDTH
		or handle == Handle.RESIZE_LENGTH
		or handle == Handle.RESIZE_HEIGHT
	)


## האם הידית היא ידית של כדור (קנה מידה אחיד או לחיצה/מתיחה).
static func _is_ball_handle(handle: Handle) -> bool:
	return handle == Handle.KADOR_SCALE or handle == Handle.LACHITZA_MATICHAH


## ידית שינוי הגודל שמתאימה לידית ציר (x=רוחב, y=גובה, z=אורך).
static func _resize_handle_of(axis_handle: Handle) -> Handle:
	match axis_handle:
		Handle.AXIS_X:
			return Handle.RESIZE_WIDTH
		Handle.AXIS_Y:
			return Handle.RESIZE_HEIGHT
		Handle.AXIS_Z:
			return Handle.RESIZE_LENGTH
	return Handle.NONE


## מרכז הבסיס (על הרצפה) של הקבוצה - מקור החצים וידית הקרקע.
func _group_base_center() -> Vector3:
	if _targets.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for target in _targets:
		if target.has_method("get_base_center"):
			sum += target.get_base_center()
		else:
			sum += target.global_position
	return sum / float(_targets.size())


## מרכז הקבוצה במרחב התלת-ממדי - סביבו מוצגות טבעות הסיבוב.
func _group_center() -> Vector3:
	if _targets.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for target in _targets:
		if target.has_method("get_center"):
			sum += target.get_center()
		else:
			sum += target.global_position
	return sum / float(_targets.size())


## מסלק מהקבוצה עצמים שנמחקו מהעולם.
func _prune_targets() -> void:
	var alive: Array[Node3D] = []
	for target in _targets:
		if is_instance_valid(target):
			alive.append(target)
	_targets = alive


## שומר את נקודת ההתחלה של כל עצם ואת מרכז הקבוצה - לפני שהגרירה מתחילה.
func _capture_targets() -> void:
	_start_transforms.clear()
	for target in _targets:
		_start_transforms.append(target.global_transform)
	_start_center = _group_center()


## מזיז את כל העצמים בקבוצה יחד באותו וקטור תנועה.
func _apply_translation(move: Vector3) -> void:
	for i in _targets.size():
		var target := _targets[i]
		if not is_instance_valid(target) or i >= _start_transforms.size():
			continue
		var start := _start_transforms[i]
		target.global_position = start.origin + move


## דואג שתנועה כלפי מטה לא תטביע אף עצם מתחת לרצפה.
func _clamp_above_floor(move: Vector3) -> void:
	var lowest := INF
	for start in _start_transforms:
		lowest = minf(lowest, start.origin.y)
	if lowest < INF:
		move.y = maxf(move.y, -lowest)


## מנסה לתפוס ידית של הגיזמו לפי נקודה על המסך. מחזיר true אם נתפסה ידית.
## בודק רק ידיות השייכות למצב הנוכחי (חצים/קרקע בהזזה, טבעות בסיבוב).
func try_grab(screen_position: Vector2) -> bool:
	if _targets.is_empty() or _camera == null:
		return false
	var handle := _handle_at_screen(screen_position)
	if handle == Handle.NONE:
		return false
	if _is_ball_handle(handle):
		_ball_grab_point = screen_position
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	if handle == Handle.ROTATE_X or handle == Handle.ROTATE_Y or handle == Handle.ROTATE_Z:
		_begin_ring_drag(handle, _picked_grab_point)
	else:
		_begin_drag(handle, origin, direction, _picked_grab_point)
	return true


## מאתר את הידית שנמצאת מתחת לנקודה על המסך - בלי להתחיל גרירה.
## משמש גם את התפיסה (try_grab) וגם את אינדיקציית הריחוף.
## אחרי זיהוי מוצלח, _picked_grab_point מכיל את נקודת התפיסה בעולם.
func _handle_at_screen(screen_position: Vector2) -> Handle:
	if _targets.is_empty() or _camera == null:
		return Handle.NONE

	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	_picked_grab_point = global_position

	if _mode == GizmoMode.TRANSLATE:
		var best_distance := INF
		var best: Handle = Handle.NONE
		var best_point := Vector3.ZERO
		for axis in _axes:
			var result := _closest_on_line(origin, direction, global_position, axis["dir"])
			var distance: float = result[0]
			var point: Vector3 = result[1]
			var along: float = (point - global_position).dot(axis["dir"])
			# גבולות הלחיצה לאורך החץ מכוילים - כל אורך החץ המצויר נתפס.
			if along < GROUND_GRAB_RADIUS * scale.x or along > (SHAFT + TIP_LENGTH) * scale.x:
				continue
			if distance > GRAB_RADIUS * scale.x or distance >= best_distance:
				continue
			best_distance = distance
			best = axis["handle"]
			best_point = point

		if best != Handle.NONE:
			_picked_grab_point = best_point
			return best

		var hit := _plane_hit(origin, direction, global_position.y)
		if hit[0]:
			var flat: Vector3 = hit[1] - global_position
			if Vector2(flat.x, flat.z).length() <= GROUND_GRAB_RADIUS * scale.x:
				_picked_grab_point = hit[1]
				return Handle.GROUND
		return Handle.NONE

	if _mode == GizmoMode.ROTATE:
		return _ring_at(origin, direction)

	if _mode == GizmoMode.SCALE:
		if _find_ball() != null:
			return _ball_handle_at(origin, direction)
		if _find_resize_table() != null:
			return _resize_handle_at(origin, direction)
		return _scale_handle_at(origin, direction)

	return Handle.NONE


## מאתר איזו ידית שינוי גודל נמצאת מתחת לקרן העכבר (שולחן שתומך
## בשינוי גודל). כל הנדל צף מקצה השולחן - בודקים את הקו שלו.
func _resize_handle_at(origin: Vector3, direction: Vector3) -> Handle:
	var best: Handle = Handle.NONE
	var best_distance := INF
	var best_point := Vector3.ZERO
	for entry in _resize_holders:
		var holder: Node3D = entry["node"]
		var handle: Handle = entry["handle"]
		# הקו של ההנדל: מנקודת ההצמדה שלו, לאורך הכיוון שהוא צף אליו.
		var base := holder.global_position
		var line_dir := (holder.global_basis * Vector3(0.0, 0.0, 1.0)).normalized()
		var result := _closest_on_line(origin, direction, base, line_dir)
		var distance: float = result[0]
		var point: Vector3 = result[1]
		var along: float = (point - base).dot(line_dir)
		var length := _handle_length if _handle_mesh != null else RESIZE_AXIS_LENGTH
		if along < -0.1 * scale.x or along > (length + 0.1) * scale.x:
			continue
		if distance > GRAB_RADIUS * scale.x or distance >= best_distance:
			continue
		best_distance = distance
		best = handle
		best_point = point

	if best != Handle.NONE:
		_picked_grab_point = best_point
	return best


## מאתר איזו ידית כדור (עיגול קנה מידה או לחיצה/מתיחה) נמצאת מתחת לקרן.
func _ball_handle_at(origin: Vector3, direction: Vector3) -> Handle:
	var best: Handle = Handle.NONE
	var best_distance := INF
	var best_t := INF
	var best_point := Vector3.ZERO
	var tie := RING_TIE_EPSILON * scale.x
	for entry in _ball_holders:
		var holder: Node3D = entry["node"]
		if not holder.visible:
			continue
		if entry["kind"] == "ring":
			# בודקים את מרחק הקרן מנקודות על היקף הטבעת (כמו טבעות הסיבוב).
			var mesh: MeshInstance3D = entry["mesh"]
			var radius := KADOR_RING_RADIUS * mesh.scale.x
			var ring_basis := holder.global_basis
			var center := holder.global_position
			var tolerance := (KADOR_RING_TUBE + KADOR_RING_TOLERANCE) * scale.x
			for i in KADOR_RING_SEGMENTS:
				var ang := TAU * float(i) / float(KADOR_RING_SEGMENTS)
				var point := center + ring_basis * Vector3(radius * cos(ang), 0.0, radius * sin(ang))
				var info := _ray_point_info(origin, direction, point)
				var distance: float = info[0]
				if distance > tolerance:
					continue
				var t: float = info[1]
				if t <= 0.0:
					continue
				var closer := distance < best_distance - tie
				var same_but_front := distance < best_distance + tie and t < best_t
				if closer or same_but_front:
					best_distance = distance
					best_t = t
					best = Handle.KADOR_SCALE
					best_point = origin + direction * t
		else:
			var base := holder.global_position
			var line_dir := (holder.global_basis * Vector3(0.0, 0.0, 1.0)).normalized()
			var result := _closest_on_line(origin, direction, base, line_dir)
			var distance: float = result[0]
			var point: Vector3 = result[1]
			var along: float = (point - base).dot(line_dir)
			if along < -0.1 * scale.x or along > (KADOR_HANDLE_LENGTH + 0.1) * scale.x:
				continue
			if distance > GRAB_RADIUS * scale.x or distance >= best_distance:
				continue
			best_distance = distance
			best = entry["handle"]
			best_point = point
	if best != Handle.NONE:
		_picked_grab_point = best_point
	return best


## מאתר איזו ידית קנה מידה נמצאת מתחת לקרן העכבר.
## קודם בודקים את הקובייה המרכזית (הגדלה אחידה), ואם לא היא - את שלושת הצירים.
func _scale_handle_at(origin: Vector3, direction: Vector3) -> Handle:
	var center_info := _ray_point_info(origin, direction, global_position)
	if center_info[0] <= CENTER_GRAB_RADIUS * scale.x and center_info[1] > 0.0:
		_picked_grab_point = global_position
		return Handle.SCALE_UNIFORM

	var best: Handle = Handle.NONE
	var best_distance := INF
	var best_point := Vector3.ZERO
	for axis in _axes:
		var scale_handle := _scale_handle_of(axis["handle"])
		if scale_handle == Handle.NONE:
			continue
		# כיוון הציר כפי שהידית מצוירת - מסובב לפי העצם הנבחר.
		var axis_dir := _scale_rotation * (axis["dir"] as Vector3)
		var result := _closest_on_line(origin, direction, global_position, axis_dir)
		var distance: float = result[0]
		var point: Vector3 = result[1]
		var along: float = (point - global_position).dot(axis["dir"])
		if along < CENTER_GRAB_RADIUS * scale.x or along > (SCALE_AXIS_LENGTH + SCALE_CUBE_SIZE) * scale.x:
			continue
		if distance > GRAB_RADIUS * scale.x or distance >= best_distance:
			continue
		best_distance = distance
		best = scale_handle
		best_point = point

	if best != Handle.NONE:
		_picked_grab_point = best_point
	return best


## מאתר איזו טבעת נמצאת מתחת לקרן העכבר.
##
## החישוב דוגם את נקודות היקף הטבעת ומודד את מרחק הקרן מכל אחת מהן.
## שגיאת הדגימה זניחה (פחות ממילימטר בגודל הגיזמו) לעומת רדיוס התפיסה,
## והשיטה עובדת נכון מכל זווית מבט - בניגוד לחישוב הקודם שהשתמש בכיוון
## משיש קבוע שגוי, מה שגרם לטבעות האדומה והכחולה להיתפס לא נכון.
## כששתי נקודות קרובות באותה מידה - מעדיפים את החלק הקדמי (קרוב למצלמה).
func _ring_at(origin: Vector3, direction: Vector3) -> Handle:
	var best: Handle = Handle.NONE
	var best_distance := INF
	var best_t := INF
	var center := _ring_origin.global_position
	var tie := RING_TIE_EPSILON * scale.x
	for ring in _rings:
		var ring_basis: Basis = ring["basis"]
		# רדיוס הטבעת *בקנה המידה של הגיזמו* - זהה לטבעת המצוירת.
		var radius: float = (ring["radius"] as float) * scale.x
		var tolerance: float = ((ring["tube"] as float) + GRAB_RADIUS) * scale.x
		var segments: int = ring["segments"]
		for i in segments:
			var a := TAU * float(i) / float(segments)
			var point := center + ring_basis * Vector3(radius * cos(a), 0.0, radius * sin(a))
			var info := _ray_point_info(origin, direction, point)
			var distance: float = info[0]
			if distance > tolerance:
				continue
			var t: float = info[1]
			if t <= 0.0:
				continue
			var closer := distance < best_distance - tie
			var same_but_front := distance < best_distance + tie and t < best_t
			if closer or same_but_front:
				best_distance = distance
				best_t = t
				best = ring["handle"]
				_picked_grab_point = origin + direction * t
	return best


## מרחק הקרן מנקודה, והמרחק לאורך הקרן עד לנקודה הקרובה ביותר עליה.
## מחזיר [מרחק, t] - t חיובי אומר שהנקודה לפני ראש הקרן.
static func _ray_point_info(origin: Vector3, direction: Vector3, point: Vector3) -> Array:
	var to_point := point - origin
	var t := to_point.dot(direction)
	var closest := origin + direction * t
	return [closest.distance_to(point), t]


## מזיז או מסובב את כל העצמים בקבוצה לפי מיקום העכבר החדש.
func drag_to(screen_position: Vector2) -> void:
	if _active == Handle.NONE or _targets.is_empty() or _camera == null:
		return
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)

	match _active:
		Handle.GROUND:
			# כדור: הידית המרכזית מזיזה את הכדור בחופשיות במישור המסך -
			# בכל הצירים, כולל מעלה/מטה (עם שמירה מעל הרצפה).
			if _find_ball() != null:
				var normal := -_camera.global_transform.basis.z
				var screen_plane := Plane(normal, _grab_ground_point.dot(normal))
				var free_hit = screen_plane.intersects_ray(origin, direction)
				if free_hit == null:
					return
				var free_delta: Vector3 = (free_hit as Vector3) - _grab_ground_point
				_clamp_above_floor(free_delta)
				_apply_translation(free_delta)
				return
			var hit := _plane_hit(origin, direction, global_position.y)
			if not hit[0]:
				return
			var delta: Vector3 = hit[1] - _grab_ground_point
			var new_position := _grab_position
			new_position.x = _snap(_grab_position.x + delta.x, GRID_SIZE)
			new_position.z = _snap(_grab_position.z + delta.z, GRID_SIZE)
			_apply_translation(new_position - _grab_position)
		Handle.AXIS_X, Handle.AXIS_Y, Handle.AXIS_Z:
			var axis_dir := _direction_of(_active)
			var index := _axis_index(_active)
			var step := HEIGHT_STEP if _active == Handle.AXIS_Y else GRID_SIZE
			var result := _closest_on_line(origin, direction, global_position, axis_dir)
			var moved: Vector3 = result[1] - _grab_axis_point
			var new_position := _grab_position
			new_position[index] = _snap(_grab_position[index] + moved[index], step)
			var move := new_position - _grab_position
			_clamp_above_floor(move)
			_apply_translation(move)
		Handle.ROTATE_X, Handle.ROTATE_Y, Handle.ROTATE_Z:
			_rotate_drag(origin, direction)
		Handle.SCALE_X, Handle.SCALE_Y, Handle.SCALE_Z:
			_scale_drag_axis(screen_position, origin, direction)
		Handle.SCALE_UNIFORM:
			_scale_drag_uniform(screen_position)
		Handle.RESIZE_WIDTH, Handle.RESIZE_LENGTH, Handle.RESIZE_HEIGHT:
			_resize_drag(origin, direction)
		Handle.KADOR_SCALE:
			_kador_scale_drag(screen_position)
		Handle.LACHITZA_MATICHAH:
			_lachitza_matichah_drag(screen_position)

	refresh()


## קנה מידה בציר אחד: כמה הזזנו את העכבר לאורך הציר קובע את המקדם.
func _scale_drag_axis(_screen_position: Vector2, origin: Vector3, direction: Vector3) -> void:
	var axis_dir := _scale_rotation * _direction_of(_active)
	var result := _closest_on_line(origin, direction, global_position, axis_dir)
	var moved: float = ((result[1] as Vector3) - _grab_axis_point).dot(axis_dir)
	var factor := maxf(SCALE_MIN, 1.0 + moved / (SCALE_AXIS_LENGTH * scale.x))
	if Input.is_key_pressed(KEY_SHIFT):
		factor = maxf(SCALE_MIN, snappedf(factor, SCALE_STEP))
	var factors := Vector3.ONE
	factors[_axis_index(_active)] = factor
	_apply_scale(factors)


## קנה מידה אחיד: היחס בין מרחק העכבר ממרכז הגיזמו עכשיו למרחק בהתחלה.
func _scale_drag_uniform(screen_position: Vector2) -> void:
	var pivot_screen := _camera.unproject_position(global_position)
	var distance := screen_position.distance_to(pivot_screen)
	var factor := maxf(SCALE_MIN, distance / maxf(_scale_start_distance, 1.0))
	if Input.is_key_pressed(KEY_SHIFT):
		factor = maxf(SCALE_MIN, snappedf(factor, SCALE_STEP))
	_apply_scale(Vector3.ONE * factor)


## שינוי גודל פרוצדורלי של השולחן: מרחק הגרירה לאורך הציר נוסף ישירות
## למידה שהתחילה ממנה. הרוחב והאורך מותחים רק את הראש, הגובה מאריך
## את הרגליים - השולחן עצמו מחליט מה קורה עם כל ציר. Shift מצמד
## לקפיצות של רבע מטר.
func _resize_drag(origin: Vector3, direction: Vector3) -> void:
	if _resize_table == null or not is_instance_valid(_resize_table):
		return
	var axis_dir := _scale_rotation * _direction_of(_active)
	var result := _closest_on_line(origin, direction, global_position, axis_dir)
	var moved: float = ((result[1] as Vector3) - _grab_axis_point).dot(axis_dir)
	var index := _axis_index(_active)
	var dims := _resize_start_dims
	dims[index] = dims[index] + moved
	if Input.is_key_pressed(KEY_SHIFT):
		dims[index] = snappedf(dims[index], RESIZE_STEP)
	_resize_table.set_dimensions(dims)


## מחיל קנה מידה על כל העצמים בקבוצה, סביב מרכז הבסיס שלה (על הרצפה) -
## כך שעצם שגדל נשאר עומד על הרצפה, והעצמים בקבוצה גם מתקרבים/מתרחקים.
## המתיחה היא מקומית - לאורך הצירים של העצם עצמו, בלי גזירה.
func _apply_scale(factors: Vector3) -> void:
	var pivot := global_position
	var rotation_inverse := _scale_rotation.inverse()
	for i in _targets.size():
		var target := _targets[i]
		if not is_instance_valid(target) or i >= _start_transforms.size():
			continue
		var start := _start_transforms[i]
		# המרחק מנקודת הסכימה מוכפל בקנה המידה, במערכת הצירים של הגיזמו.
		var offset := rotation_inverse * (start.origin - pivot)
		offset.x *= factors.x
		offset.y *= factors.y
		offset.z *= factors.z
		# קנה מידה מקומי: מתיחה לאורך הצירים של העצם, כך שהתוצאה נקייה.
		var new_basis := start.basis * Basis.from_scale(factors)
		target.global_transform = Transform3D(new_basis, pivot + _scale_rotation * offset)


## מסיים את הגרירה בהצלחה.
func release() -> void:
	if _active == Handle.NONE:
		return
	_active = Handle.NONE
	drag_finished.emit()


# ------------------------------------------------------------------ סיבוב 3D מדויק

func _begin_ring_drag(handle: Handle, hit_point: Vector3) -> void:
	_active = handle
	_capture_targets()
	_ring_plane_center = _ring_origin.global_position
	_ring_plane_normal = _direction_of(handle).normalized()

	var to_hit := hit_point - _ring_plane_center
	var proj := to_hit - _ring_plane_normal * to_hit.dot(_ring_plane_normal)
	if proj.length_squared() > 0.0001:
		_ring_grab_vector = proj.normalized()
	else:
		_ring_grab_vector = Vector3.UP if absf(_ring_plane_normal.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	_accumulated_angle = 0.0
	drag_started.emit(handle)


func _rotate_drag(origin: Vector3, direction: Vector3) -> void:
	var plane := Plane(_ring_plane_normal, _ring_plane_center.dot(_ring_plane_normal))
	var hit = plane.intersects_ray(origin, direction)
	var curr_hit: Vector3
	if hit != null:
		curr_hit = hit
	else:
		var to_center := _ring_plane_center - origin
		var proj_len := to_center.dot(direction)
		curr_hit = origin + direction * proj_len

	var to_curr := curr_hit - _ring_plane_center
	var proj := to_curr - _ring_plane_normal * to_curr.dot(_ring_plane_normal)
	if proj.length_squared() < 0.0001:
		return
	var curr_vector := proj.normalized()

	var angle := _ring_grab_vector.signed_angle_to(curr_vector, _ring_plane_normal)
	_accumulated_angle = angle

	var apply_angle := _accumulated_angle
	if Input.is_key_pressed(KEY_SHIFT):
		apply_angle = snappedf(apply_angle, deg_to_rad(ROTATION_STEP))

	# מסובבים את כל הקבוצה סביב מרכז הקבוצה - כאילו היו עצם אחד שלם.
	var turn := Basis(_ring_plane_normal, apply_angle)
	for i in _targets.size():
		var target := _targets[i]
		if not is_instance_valid(target) or i >= _start_transforms.size():
			continue
		var start := _start_transforms[i]
		var offset := start.origin - _start_center
		target.global_transform = Transform3D(turn * start.basis, _start_center + turn * offset)


# ------------------------------------------------------------------ פנימי

func _begin_drag(handle: Handle, origin: Vector3, direction: Vector3, point: Vector3) -> void:
	_active = handle
	_capture_targets()
	# שינוי גודל: שומרים את השולחן והמידות שלו בתחילת הגרירה,
	# כדי שקליק ימני יוכל להחזיר אותן.
	if _is_resizing_handle(handle):
		_resize_table = _find_resize_table()
		if _resize_table != null:
			_resize_start_dims = _resize_table.get_dimensions()
	# כדור: שומרים את המידות ומצב הלחיצה/מתיחה בתחילת הגרירה.
	if _is_ball_handle(handle):
		_ball = _find_ball()
		if _ball != null:
			if _ball.has_method("get_dimensions"):
				_ball_start_dims = _ball.get_dimensions()
			if _ball.has_method("get_squash_stretch"):
				_ball_start_squash = _ball.get_squash_stretch()
			# מרכז הכדור נשאר קבוע לאורך כל הגרירה - סביבו הכדור גדל.
			if _ball.has_method("get_local_center"):
				_ball_center_height = _ball.get_local_center().y
			else:
				_ball_center_height = _ball_start_dims.y * 0.5
		if _camera != null:
			var center_screen := _camera.unproject_position(global_position)
			_ball_scale_start_distance = maxf(_ball_grab_point.distance_to(center_screen), 1.0)
	_grab_position = global_position
	_grab_axis_point = point
	if handle == Handle.GROUND:
		_grab_ground_point = point
		if _find_ball() != null and _camera != null:
			# כדור: נקודת התפיסה על מישור המסך - תנועה חופשית בכל הצירים.
			var normal := -_camera.global_transform.basis.z
			var plane := Plane(normal, global_position.dot(normal))
			var free_hit = plane.intersects_ray(origin, direction)
			if free_hit != null:
				_grab_ground_point = free_hit as Vector3
		else:
			var hit := _plane_hit(origin, direction, global_position.y)
			if hit[0]:
				_grab_ground_point = hit[1]
	if handle == Handle.SCALE_UNIFORM and _camera != null:
		var pivot_screen := _camera.unproject_position(global_position)
		_scale_start_distance = maxf(get_viewport().get_mouse_position().distance_to(pivot_screen), 1.0)
	drag_started.emit(handle)


## הצמדה לרשת. ברירת מחדל - תנועה חופשית.
## החזקת Shift בזמן גרירה מצמדת לרשת (0.5 מ' אופקי, 0.25 בגובה, 15 מעלות סיבוב).
static func _snap(value: float, step: float) -> float:
	if not Input.is_key_pressed(KEY_SHIFT):
		return value
	return snappedf(value, step)


func _build_rings() -> void:
	var mesh := _make_ring_mesh()
	_rings = [
		{"handle": Handle.ROTATE_X, "dir": Vector3.RIGHT, "color": X_COLOR,
		 "basis": Basis(Vector3.BACK, PI * 0.5), "radius": RING_RADIUS,
		 "tube": RING_TUBE, "segments": RING_SEGMENTS},
		{"handle": Handle.ROTATE_Y, "dir": Vector3.UP, "color": Y_COLOR,
		 "basis": Basis(), "radius": RING_RADIUS,
		 "tube": RING_TUBE, "segments": RING_SEGMENTS},
		{"handle": Handle.ROTATE_Z, "dir": Vector3.BACK, "color": Z_COLOR,
		 "basis": Basis(Vector3.RIGHT, PI * 0.5), "radius": RING_RADIUS,
		 "tube": RING_TUBE, "segments": RING_SEGMENTS},
	]
	for ring in _rings:
		var mi := MeshInstance3D.new()
		var ring_handle: Handle = ring["handle"]
		mi.name = "Ring%s" % _handle_name(ring_handle)
		mi.mesh = mesh
		var ring_color: Color = ring["color"]
		mi.material_override = _gizmo_material(ring_color)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ring_basis: Basis = ring["basis"]
		mi.transform = Transform3D(ring_basis, Vector3.ZERO)
		_ring_origin.add_child(mi)
		_handle_nodes[ring_handle] = mi


static func _make_ring_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := RING_SEGMENTS
	var tubes := RING_TUBE_SEGMENTS
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		for j in tubes:
			var b0 := TAU * float(j) / float(tubes)
			var b1 := TAU * float(j + 1) / float(tubes)
			var p00 := _ring_point(a0, b0)
			var p10 := _ring_point(a1, b0)
			var p01 := _ring_point(a0, b1)
			var p11 := _ring_point(a1, b1)
			tool.add_vertex(p00)
			tool.add_vertex(p10)
			tool.add_vertex(p01)
			tool.add_vertex(p10)
			tool.add_vertex(p11)
			tool.add_vertex(p01)
	return tool.commit()


static func _ring_point(a: float, b: float) -> Vector3:
	var r := RING_RADIUS + RING_TUBE * cos(b)
	return Vector3(r * cos(a), RING_TUBE * sin(b), r * sin(a))


func _build() -> void:
	_axes = [
		{"handle": Handle.AXIS_X, "dir": Vector3.RIGHT, "color": X_COLOR},
		{"handle": Handle.AXIS_Y, "dir": Vector3.UP, "color": Y_COLOR},
		{"handle": Handle.AXIS_Z, "dir": Vector3.BACK, "color": Z_COLOR},
	]
	for axis in _axes:
		var arrow := _make_arrow(axis["dir"], axis["color"])
		arrow.name = "Axis%s" % _handle_name(axis["handle"])
		_arrows_root.add_child(arrow)
		_handle_nodes[axis["handle"]] = arrow
	var ground := _make_ground_handle()
	_arrows_root.add_child(ground)
	_handle_nodes[Handle.GROUND] = ground


## בונה את ידיות קנה המידה: מוט וקובייה לכל ציר, וקובייה במרכז
## להגדלה/הקטנה אחידה.
func _build_scale() -> void:
	for axis in _axes:
		var scale_handle := _scale_handle_of(axis["handle"])
		var color: Color = axis["color"]
		var holder := Node3D.new()
		holder.name = "Scale%s" % _handle_name(scale_handle)
		holder.transform = Transform3D(_basis_facing(axis["dir"]), Vector3.ZERO)

		var material := _gizmo_material(color)
		var rod := MeshInstance3D.new()
		var rod_mesh := BoxMesh.new()
		rod_mesh.size = Vector3(SHAFT_WIDTH * 1.2, SHAFT_WIDTH * 1.2, SCALE_AXIS_LENGTH)
		rod.mesh = rod_mesh
		rod.position = Vector3(0.0, 0.0, SCALE_AXIS_LENGTH * 0.5)
		rod.material_override = material
		rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(rod)

		var cube := MeshInstance3D.new()
		var cube_mesh := BoxMesh.new()
		cube_mesh.size = Vector3.ONE * SCALE_CUBE_SIZE
		cube.mesh = cube_mesh
		cube.position = Vector3(0.0, 0.0, SCALE_AXIS_LENGTH)
		cube.material_override = material
		cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(cube)

		_scale_root.add_child(holder)
		_handle_nodes[scale_handle] = holder

	var center := MeshInstance3D.new()
	center.name = "ScaleUniform"
	var center_mesh := BoxMesh.new()
	center_mesh.size = Vector3.ONE * SCALE_CENTER_SIZE
	center.mesh = center_mesh
	center.material_override = _gizmo_material(CENTER_COLOR)
	center.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scale_root.add_child(center)
	_handle_nodes[Handle.SCALE_UNIFORM] = center


## בונה את ידיות שינוי הגודל של שולחן שתומך בזה. ברירת המחדל היא
## ההנדל שמידל המשתמש (מוט עם ראש משושה), הצמוד לקצה השולחן וצף
## ממנו החוצה - כמו בסקיצה: ירוק = רוחב, אדום = עומק, כחול = גובה.
## אם קובץ ההנדלים חסר, מוצגים במקומו חצים מלבניים רגילים.
## ההצמדה לקצוות מתעדכנת בכל פריים לפי המידות הנוכחיות (_update_resize_handles).
func _build_resize() -> void:
	var defs: Array[Dictionary] = _resize_handle_defs()
	for def in defs:
		var resize_handle: Handle = def["handle"]
		var direction: Vector3 = def["dir"]
		var color: Color = _resize_handle_color(resize_handle)
		var holder := Node3D.new()
		holder.name = "Resize%s" % _handle_name(resize_handle)
		holder.transform = Transform3D(_basis_facing(direction), Vector3.ZERO)

		if _handle_mesh != null:
			# ההנדל של המשתמש: הופכים את הרשת סביב Y ומזיזים לאורך ציר ה-Z
			# כך שהמוט מתחיל בנקודת ההצמדה (z=0) והראש המשושה בקצה החיצוני.
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = _handle_mesh
			var inner := (_handle_mesh.get_aabb() as AABB).end.z
			mesh_instance.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, inner))
			mesh_instance.material_override = _gizmo_material(color)
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mesh_instance)
		else:
			# גיבוי: חצים מלבניים רגילים.
			var material := _gizmo_material(color)
			var shaft := MeshInstance3D.new()
			var shaft_mesh := BoxMesh.new()
			shaft_mesh.size = Vector3(RESIZE_SHAFT_WIDTH, RESIZE_SHAFT_WIDTH, RESIZE_AXIS_LENGTH - RESIZE_TIP_LENGTH)
			shaft.mesh = shaft_mesh
			shaft.position = Vector3(0.0, 0.0, (RESIZE_AXIS_LENGTH - RESIZE_TIP_LENGTH) * 0.5)
			shaft.material_override = material
			shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(shaft)

			var tip := MeshInstance3D.new()
			var tip_mesh := BoxMesh.new()
			tip_mesh.size = Vector3(RESIZE_TIP_SIZE, RESIZE_TIP_SIZE, RESIZE_TIP_LENGTH)
			tip.mesh = tip_mesh
			tip.position = Vector3(0.0, 0.0, RESIZE_AXIS_LENGTH - RESIZE_TIP_LENGTH * 0.5)
			tip.material_override = material
			tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(tip)

		_resize_root.add_child(holder)
		_handle_nodes[resize_handle] = holder
		_resize_holders.append({"handle": resize_handle, "node": holder, "dir": direction})


## שלוש ידיות שינוי הגודל: איזה ציר כל אחת שולטת ולאיזה כיוון היא צפה.
## רוחב (X) צף ימינה מהקצה הימני, עומק (Z) צף קדימה (-Z) מהקצה הקדמי,
## גובה (Y) צף מעלה משולחן הראש - כמו בסקיצה של המשתמש.
func _resize_handle_defs() -> Array[Dictionary]:
	return [
		{"handle": Handle.RESIZE_WIDTH, "dir": Vector3.RIGHT},
		{"handle": Handle.RESIZE_LENGTH, "dir": Vector3.FORWARD},
		{"handle": Handle.RESIZE_HEIGHT, "dir": Vector3.UP},
	]


## צבע ההנדל של כל ידית שינוי גודל - כמו בעיצוב של המשתמש.
func _resize_handle_color(handle: Handle) -> Color:
	match handle:
		Handle.RESIZE_WIDTH:
			return RESIZE_WIDTH_COLOR
		Handle.RESIZE_LENGTH:
			return RESIZE_LENGTH_COLOR
		Handle.RESIZE_HEIGHT:
			return RESIZE_HEIGHT_COLOR
	return Color.WHITE


## היכן כל ידית נצמדת לשולחן (במרחב המקומי של השולחן, במטרים):
## רוחב - אמצע הקצה הימני, עומק - הצד השמאלי של הקצה הקדמי,
## גובה - מעל מרכז חזית השולחן. נקודת ההצמדה של הגובה היא פני
## השולחן, ושל האחרות - גובה לוח הראש.
func _resize_attach_offset(handle: Handle, dims: Vector3) -> Vector3:
	match handle:
		Handle.RESIZE_WIDTH:
			return Vector3(dims.x * 0.5, dims.y - 0.12, 0.0)
		Handle.RESIZE_LENGTH:
			return Vector3(-dims.x * 0.25, dims.y - 0.12, -dims.z * 0.5)
		Handle.RESIZE_HEIGHT:
			return Vector3(0.0, dims.y, -dims.z * 0.3)
	return Vector3.ZERO


## מעדכן בכל פריים את מקום ההצמדה של ההנדלים לקצוות השולחן, לפי
## המידות הנוכחיות. הגיזמו מוצג בגודל קבוע על המסך (סקייל לפי מרחק),
## ולכן מפצים על הסקייל כדי שההנדלים יצמדו בדיוק לקצה.
func _update_resize_handles() -> void:
	if _resize_root == null or not _resize_root.visible or _resize_holders.is_empty():
		return
	var table := _find_resize_table()
	if table == null or not table.has_method("get_dimensions"):
		return
	var dims: Vector3 = table.get_dimensions()
	var gizmo_scale := maxf(scale.x, 0.001)
	for entry in _resize_holders:
		var holder: Node3D = entry["node"]
		holder.position = _resize_attach_offset(entry["handle"], dims) / gizmo_scale


func _make_arrow(axis_dir: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.transform = Transform3D(_basis_facing(axis_dir), Vector3.ZERO)
	var material := _gizmo_material(color)

	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(SHAFT_WIDTH, SHAFT_WIDTH, SHAFT)
	shaft.mesh = shaft_mesh
	shaft.position = Vector3(0.0, 0.0, SHAFT * 0.5)
	shaft.material_override = material
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shaft)

	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = TIP_RADIUS
	tip_mesh.height = TIP_LENGTH
	tip_mesh.radial_segments = 16
	tip.mesh = tip_mesh
	tip.transform = Transform3D(
		Basis(Vector3.RIGHT, PI * 0.5),
		Vector3(0.0, 0.0, SHAFT + TIP_LENGTH * 0.5)
	)
	tip.material_override = material
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tip)
	return root


func _make_ground_handle() -> MeshInstance3D:
	var handle := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = GROUND_HANDLE_SIZE
	handle.mesh = box
	handle.position = Vector3(0.0, GROUND_HANDLE_SIZE.y * 0.5, 0.0)
	handle.material_override = _gizmo_material(GROUND_COLOR)
	handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return handle


static func _gizmo_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	return material


static func _basis_facing(direction: Vector3) -> Basis:
	var reference := Vector3.UP
	if absf(direction.dot(Vector3.UP)) > 0.99:
		reference = Vector3.RIGHT
	var z := direction.normalized()
	var x := reference.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)


## חיתוך של קרן עם מישור אופקי בגובה y.
## מחזיר [האם יש חיתוך, נקודת החיתוך].
static func _plane_hit(origin: Vector3, direction: Vector3, y: float) -> Array:
	if absf(direction.y) < 0.0001:
		return [false, Vector3.ZERO]
	var distance := (y - origin.y) / direction.y
	if distance <= 0.0:
		return [false, Vector3.ZERO]
	return [true, origin + direction * distance]


## הנקודה הקרובה ביותר על הישר לקרן נתונה.
## מחזיר [המרחק בין הקרן לישר, הנקודה על הישר].
static func _closest_on_line(
	ray_origin: Vector3, ray_direction: Vector3, line_point: Vector3, line_direction: Vector3
) -> Array:
	var w := ray_origin - line_point
	var a := ray_direction.dot(ray_direction)
	var b := ray_direction.dot(line_direction)
	var c := line_direction.dot(line_direction)
	var d := ray_direction.dot(w)
	var e := line_direction.dot(w)
	var denominator := a * c - b * b
	if absf(denominator) < 0.000001:
		return [INF, line_point]
	var s := (a * e - b * d) / denominator
	var t := (b * e - c * d) / denominator
	var on_line := line_point + line_direction * s
	var on_ray := ray_origin + ray_direction * t
	return [on_ray.distance_to(on_line), on_line]


## כיוון הציר של ידית (תרגום, סיבוב או קנה מידה).
static func _direction_of(handle: Handle) -> Vector3:
	match handle:
		Handle.AXIS_X, Handle.ROTATE_X, Handle.SCALE_X, Handle.RESIZE_WIDTH:
			return Vector3.RIGHT
		Handle.AXIS_Y, Handle.ROTATE_Y, Handle.SCALE_Y, Handle.RESIZE_HEIGHT:
			return Vector3.UP
		Handle.AXIS_Z, Handle.ROTATE_Z, Handle.SCALE_Z:
			return Vector3.BACK
		# ידית העומק צפה מהקצה הקדמי לכיוון -Z, וגרירתה החוצה
		# מאריכה את הזרוע הקדמית של השולחן.
		Handle.RESIZE_LENGTH:
			return Vector3.FORWARD
		Handle.LACHITZA_MATICHAH:
			return Vector3.UP
	return Vector3.ZERO


## ידית קנה המידה שמתאימה לידית ציר של ההזזה.
static func _scale_handle_of(axis_handle: Handle) -> Handle:
	match axis_handle:
		Handle.AXIS_X:
			return Handle.SCALE_X
		Handle.AXIS_Y:
			return Handle.SCALE_Y
		Handle.AXIS_Z:
			return Handle.SCALE_Z
	return Handle.NONE


static func _axis_index(handle: Handle) -> int:
	match handle:
		Handle.AXIS_X, Handle.SCALE_X, Handle.RESIZE_WIDTH:
			return 0
		Handle.AXIS_Y, Handle.SCALE_Y, Handle.RESIZE_HEIGHT:
			return 1
		Handle.AXIS_Z, Handle.SCALE_Z, Handle.RESIZE_LENGTH:
			return 2
	return 0


static func _handle_name(handle: Handle) -> String:
	match handle:
		Handle.AXIS_X:
			return "X"
		Handle.AXIS_Y:
			return "Y"
		Handle.AXIS_Z:
			return "Z"
		Handle.ROTATE_X:
			return "RotX"
		Handle.ROTATE_Y:
			return "RotY"
		Handle.ROTATE_Z:
			return "RotZ"
		Handle.SCALE_X:
			return "ScaleX"
		Handle.SCALE_Y:
			return "ScaleY"
		Handle.SCALE_Z:
			return "ScaleZ"
		Handle.GROUND:
			return "Ground"
		Handle.RESIZE_WIDTH:
			return "Width"
		Handle.RESIZE_LENGTH:
			return "Length"
		Handle.RESIZE_HEIGHT:
			return "Height"
		Handle.KADOR_SCALE:
			return "KadorScale"
		Handle.LACHITZA_MATICHAH:
			return "Matich"
	return ""


# ================================================================ ידיות הכדור

## בונה את ידיות הכדור: עיגול קנה מידה אחיד במרכז הכדור (טורקיז) וידית
## לחיצה/מתיחה (אדום) מעל הכדור.
func _build_ball_handles() -> void:
	if _ball_root == null:
		return

	# עיגול קנה המידה - טבעת אופקית במרכז הכדור שהולכת אחרי רדיוס הכדור.
	var ring_holder := Node3D.new()
	ring_holder.name = "BallKadorScale"
	var ring_mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = KADOR_RING_RADIUS - KADOR_RING_TUBE
	torus.outer_radius = KADOR_RING_RADIUS + KADOR_RING_TUBE
	torus.rings = KADOR_RING_SEGMENTS
	torus.ring_segments = 12
	ring_mesh.mesh = torus
	ring_mesh.material_override = _gizmo_material(KADOR_SCALE_COLOR)
	ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_holder.add_child(ring_mesh)
	_ball_root.add_child(ring_holder)
	_handle_nodes[Handle.KADOR_SCALE] = ring_holder
	_ball_holders.append({
		"handle": Handle.KADOR_SCALE, "node": ring_holder, "kind": "ring", "mesh": ring_mesh
	})

	# ידית לחיצה/מתיחה - חץ אנכי מעל הכדור.
	var arrow := Node3D.new()
	arrow.name = "BallMatich"
	arrow.transform = Transform3D(_basis_facing(Vector3.UP), Vector3.ZERO)
	var material := _gizmo_material(KADOR_MATICH_COLOR)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(KADOR_SHAFT_WIDTH, KADOR_SHAFT_WIDTH, KADOR_HANDLE_LENGTH - KADOR_TIP_LENGTH)
	shaft.mesh = shaft_mesh
	shaft.position = Vector3(0.0, 0.0, (KADOR_HANDLE_LENGTH - KADOR_TIP_LENGTH) * 0.5)
	shaft.material_override = material
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.add_child(shaft)
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(KADOR_TIP_SIZE, KADOR_TIP_SIZE, KADOR_TIP_LENGTH)
	tip.mesh = tip_mesh
	tip.position = Vector3(0.0, 0.0, KADOR_HANDLE_LENGTH - KADOR_TIP_LENGTH * 0.5)
	tip.material_override = material
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.add_child(tip)
	_ball_root.add_child(arrow)
	_handle_nodes[Handle.LACHITZA_MATICHAH] = arrow
	_ball_holders.append({
		"handle": Handle.LACHITZA_MATICHAH, "node": arrow, "kind": "arrow", "mesh": tip
	})


## מצמיד את ידיות הכדור בכל פריים: עיגול קנה המידה עוטף את הכדור במרכזו,
## וידית הלחיצה/מתיחה יושבת מעל הכדור. הגיזמו מוצג בגודל קבוע על המסך,
## ולכן מפצים בסקייל שלו כדי שההנדלים ייצמדו לגודל האמיתי.
func _update_ball_handles() -> void:
	if _ball_root == null or not _ball_root.visible or _ball_holders.is_empty():
		return
	var ball := _find_ball()
	if ball == null or not ball.has_method("get_dimensions"):
		return
	var dims: Vector3 = ball.get_dimensions()
	var gizmo_scale := maxf(scale.x, 0.001)
	# הידיות נצמדות למרכז הכדור הנוכחי בעולם. הגיזמו עצמו קפוא בזמן
	# הגרירה (כדי שנקודת הסכימה לא תזוז), אבל הכדור גדל סביב מרכזו -
	# ולכן הידיות עוקבות אחרי המרכז כדי להישאר על הכדור ולא "לברוח" ממנו.
	var center_world: Vector3 = ball.get_center() if ball.has_method("get_center") else global_position
	var center_local: Vector3 = (center_world - global_position) / gizmo_scale
	for entry in _ball_holders:
		var holder: Node3D = entry["node"]
		if entry["kind"] == "ring":
			# הטבעת עוטפת את הכדור בקו המשווה: הרדיוס שלה שווה לרדיוס הכדור.
			var ball_radius := maxf(dims.x, dims.z) * 0.5
			var mesh: MeshInstance3D = entry["mesh"]
			var wanted := ball_radius / maxf(KADOR_RING_RADIUS * gizmo_scale, 0.0001)
			mesh.scale = Vector3.ONE * maxf(wanted, 0.05)
			holder.position = center_local
		else:
			# ידית הלחיצה/מתיחה יושבת מעל הכדור.
			holder.position = center_local + Vector3(0.0, dims.y * 0.5, 0.0) / gizmo_scale


## עיגול קנה המידה: גרירה משנה את כל גודל הכדור (קנה מידה אחיד),
## לפי היחס בין מרחק העכבר ממרכז הכדור עכשיו למרחק בתחילת הגרירה.
func _kador_scale_drag(screen_position: Vector2) -> void:
	if _ball == null or not is_instance_valid(_ball):
		_ball = _find_ball()
	if _ball == null or not is_instance_valid(_ball) or _camera == null:
		return
	var center_screen := _camera.unproject_position(global_position)
	var distance := screen_position.distance_to(center_screen)
	var factor := clampf(
		distance / maxf(_ball_scale_start_distance, 1.0), KADOR_SCALE_MIN, KADOR_SCALE_MAX
	)
	if Input.is_key_pressed(KEY_SHIFT):
		factor = snappedf(factor, 0.25)
	var dims: Vector3 = _ball_start_dims * factor
	# הכדור גדל סביב מרכזו (ולא מהבסיס): הוא מתנפח סימטרית לכל הכיוונים,
	# ומרכזו נשאר בדיוק במקום שהגיזמו יושב בו.
	if _ball.has_method("set_dimensions_around_center"):
		_ball.set_dimensions_around_center(dims, _ball_center_height)
	else:
		_ball.set_dimensions(dims)


## ידית הלחיצה/מתיחה: גרירה מעלה מותחת (shape key "stretch"),
## גרירה מטה לוחצת (shape key "squash"), והמרכז הוא הצורה הרגילה.
func _lachitza_matichah_drag(screen_position: Vector2) -> void:
	if _ball == null or not is_instance_valid(_ball):
		_ball = _find_ball()
	if _ball == null or not is_instance_valid(_ball):
		return
	var moved := _ball_grab_point.y - screen_position.y
	var value := clampf(_ball_start_squash + moved * KADOR_SQUASH_PER_PIXEL, -1.0, 1.0)
	if Input.is_key_pressed(KEY_SHIFT):
		value = snappedf(value, 0.25)
	_ball.set_squash_stretch(value)
