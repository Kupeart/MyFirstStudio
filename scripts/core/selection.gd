class_name StudioSelection
extends Node
## מנוע הבחירה: אפשר לבחור עצם אחד, או כמה עצמים יחד (כמו בבלנדר).
##
## הפעולות שהמשתמש יכול לעשות:
##   קליק שמאלי על עצם     = בחירה (קליק על אוויר מבטל בחירה)
##   Shift + קליק על עצם    = הוספה או הסרה של העצם מהבחירה
##   Shift + גרירה          = מלבן בחירה - כל מה שבתוכו מצטרף לבחירה
##   גרירת חץ בגיזמו       = הזזת כל העצמים הנבחרים בציר אחד
##   גרירת הידית המרכזית   = הזזה חופשית על הרצפה
##   גרירת טבעת סיבוב      = סיבוב כל הקבוצה סביב הציר
##   קליק ימני             = ביטול כל השינויים וחזרה למצב שלפני הבחירה
##   Delete                = מחיקת העצמים הנבחרים
##   Ctrl + D              = שכפול העצמים הנבחרים
##   Esc / ✓               = ביטול הבחירה (הסימון מוסר)
##
## כשנבחרים כמה עצמים - כולם מסומנים יחד, והגיזמו שלהם הוא גיזמו
## משותף אחד שיושב במרכז הקבוצה ומזיז/מסובב את כולם כאילו היו עצם אחד.

const PropScript := preload("res://scripts/core/prop.gd")
const CameraRigScript := preload("res://scripts/core/camera_rig.gd")
const GizmoScript := preload("res://scripts/core/move_gizmo.gd")
const PlacementScript := preload("res://scripts/core/placement.gd")
const ModelBoundsScript := preload("res://scripts/core/model_bounds.gd")

## כמה מעלות מסתובבים בקריאה ל-rotate_selected. הסיבוב במקלדת הוסר -
## החצים שייכים היום לציר הזמן (פריים קודם / פריים הבא).
const ROTATE_STEP := 15.0
## באיזה מרחק לאורך הקרן מחפשים עצם.
const RAY_LENGTH := 500.0
## כמה העצם המשוכפל מוזז מהמקור.
const DUPLICATE_OFFSET := Vector3(0.5, 0.0, 0.5)
## מתחת לגודל הזה (בפיקסלים) גרירת Shift נחשבת לקליק בודד.
const CLICK_BOX_MIN := 4.0

## נשלח כשהבחירה משתנה (מערך ריק = לא נבחר כלום).
signal selection_changed(items: Array)

var _camera: Camera3D = null
var _camera_rig: CameraRigScript = null
var _props_root: Node3D = null
var _gizmo: GizmoScript = null
var _placement: PlacementScript = null
var _box: SelectionBox = null
## העצמים הנבחרים - אחד, כמה, או כלום.
var _selection: Array[Node3D] = []
## הטרנספורמציה של כל עצם ברגע שנבחר - כדי שאפשר יהיה לבטל את כל השינויים.
var _start_transforms: Dictionary = {}
## מצב מלבן הבחירה (Shift + גרירה).
var _box_active := false
var _box_start := Vector2.ZERO


func setup(
	camera: Camera3D,
	camera_rig: CameraRigScript,
	props_root: Node3D,
	gizmo: GizmoScript,
	placement: PlacementScript
) -> void:
	_camera = camera
	_camera_rig = camera_rig
	_props_root = props_root
	_gizmo = gizmo
	_placement = placement
	if _gizmo != null:
		_gizmo.setup(camera)


## מחבר את שכבת הציור של מלבן הבחירה (rubber band).
func set_box(box: SelectionBox) -> void:
	_box = box


## העצם האחרון שנבחר (או null כשאין בחירה).
func get_selected() -> Node3D:
	if _selection.is_empty():
		return null
	return _selection[_selection.size() - 1]


## כל העצמים הנבחרים.
func get_selection() -> Array[Node3D]:
	return _selection


## כמה עצמים נבחרו.
func selection_count() -> int:
	return _selection.size()


## מרכז התיבה התוחמת של כל הנבחרים - שם יושב הגיזמו והממשק הצף.
func get_selection_center() -> Vector3:
	return _selection_bounds().get_center()


## גודל התיבה התוחמת של כל הנבחרים.
func get_selection_size() -> Vector3:
	return _selection_bounds().size


## התיבה התוחמת של כל העצמים הנבחרים יחד.
func _selection_bounds() -> AABB:
	var box := AABB()
	var first := true
	for prop in _selection:
		if not is_instance_valid(prop):
			continue
		var center: Vector3 = prop.global_position
		if prop.has_method("get_center"):
			center = prop.get_center()
		var size := Vector3.ZERO
		if prop.has_method("get_size"):
			size = prop.get_size()
		var prop_box := AABB(center - size * 0.5, size)
		if first:
			box = prop_box
			first = false
		else:
			box = box.merge(prop_box)
	return box


## בוחר עצם בודד. מעבירים null כדי לבטל את כל הבחירה.
## כל עצם שנבחר נכנס למצב עריכה: הוא מרחף וקצת שקוף, ומקבל גיזמו.
func select(prop: Node3D) -> void:
	if prop == null:
		set_selection([])
	elif _selection.size() == 1 and _selection[0] == prop:
		return
	else:
		set_selection([prop])


## מוסיף עצם לבחירה או מסיר אותו ממנה (Shift + קליק).
func toggle_in_selection(prop: Node3D) -> void:
	if prop == null or not is_instance_valid(prop):
		return
	var next: Array[Node3D] = []
	for current in _selection:
		next.append(current)
	var index := next.find(prop)
	if index >= 0:
		next.remove_at(index)
	else:
		next.append(prop)
	set_selection(next)


## מחליף את הבחירה בקבוצה חדשה של עצמים.
## עצמים שיצאו מהבחירה מפסיקים להיות מסומנים, והחדשים מסומנים.
func set_selection(props: Array) -> void:
	var next: Array[Node3D] = []
	for prop in props:
		if prop != null and is_instance_valid(prop) and not next.has(prop):
			next.append(prop)

	for old in _selection:
		if is_instance_valid(old) and not next.has(old):
			_leave_edit_mode(old)

	_selection = next

	for prop in _selection:
		if not _start_transforms.has(prop):
			_start_transforms[prop] = prop.global_transform
		_enter_edit_mode(prop)

	_update_gizmo_and_camera()
	selection_changed.emit(_selection.duplicate())


## כניסה למצב עריכה: העצם מסומן במתאר צהוב סביב הצללית שלו.
func _enter_edit_mode(prop: Node3D) -> void:
	prop.set_selected(true)


## יציאה ממצב עריכה: הסימון מוסר והעצם חוזר להיראות רגיל בדיוק כמו קודם.
func _leave_edit_mode(prop: Node3D) -> void:
	prop.set_selected(false)
	_start_transforms.erase(prop)


## מצמיד גיזמו משותף אחד לכל הנבחרים, וממקד את הסיבוב של המצלמה במרכזם.
func _update_gizmo_and_camera() -> void:
	if _gizmo != null:
		if _selection.is_empty():
			_gizmo.detach()
		else:
			_gizmo.attach_to_group(_selection)
	if _camera_rig != null and not _selection.is_empty():
		_camera_rig.set_pivot(get_selection_center())


func _input(event: InputEvent) -> void:
	# תנועת עכבר בזמן גרירת גיזמו או מלבן בחירה מטופלת כאן (לפני הממשק),
	# כדי שהגרירה לא תיעצר אם סמן העכבר עובר בדרך מעל חלון ממשק.
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	if _gizmo != null and _gizmo.is_dragging():
		_gizmo.drag_to(get_viewport().get_mouse_position())
	elif _box_active and _box != null:
		_box.update_to(get_viewport().get_mouse_position())


## האם מתבצעת כרגע גרירה של הגיזמו.
func is_dragging_gizmo() -> bool:
	return _gizmo != null and _gizmo.is_dragging()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		# קליק ימני: מבטל את כל השינויים - העצמים חוזרים בדיוק למצב שהיו בו
		# לפני שנבחרו (מיקום וסיבוב), נוחתים חזרה ויוצאים ממצב עריכה.
		# המקש הימני אינו מזיז את המצלמה - בשביל זה יש מקש אמצעי.
		if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			if _box_active:
				# מלבן בחירה באמצע - קליק ימני מבטל אותו בלי לגעת בבחירה.
				_box_active = false
				if _box != null:
					_box.finish()
				get_viewport().set_input_as_handled()
				return
			if not _selection.is_empty():
				cancel_edits()
			get_viewport().set_input_as_handled()
			return
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_on_left_press(button.shift_pressed)
			else:
				_on_left_release()
			return

	if event.is_action_pressed("delete_object"):
		delete_selected()
	elif event.is_action_pressed("duplicate_object"):
		duplicate_selected()
	elif event.is_action_pressed("cancel"):
		set_selection([])


## לחיצה שמאלית: קודם מנסים לתפוס ידית גיזמו (כדי ש-Shift+גרירה על ידית
## תמשיך להצמיד לרשת), ורק אם לא נתפסה ידית - Shift פותח מלבן בחירה.
func _on_left_press(with_shift: bool) -> void:
	var screen := get_viewport().get_mouse_position()
	if _gizmo != null and _gizmo.try_grab(screen):
		return
	if with_shift:
		_begin_box(screen)
		return
	select(prop_at_screen(screen))


## שחרור שמאלי: מסיים מלבן בחירה או גרירת גיזמו.
func _on_left_release() -> void:
	if _box_active:
		_finish_box(get_viewport().get_mouse_position())
		return
	if _gizmo != null:
		_gizmo.release()


## מתחיל מלבן בחירה (rubber band) מנקודת הלחיצה.
func _begin_box(at: Vector2) -> void:
	_box_active = true
	_box_start = at
	if _box != null:
		_box.begin(at)


## מסיים את מלבן הבחירה.
## לחיצה קצרה בלי גרירה מתנהגת כמו Shift+קליק (מוסיפה או מסירה עצם בודד),
## וגרירה אמיתית מוסיפה לבחירה כל עצם שהתיבה שלו על המסך נוגעת במלבן.
func _finish_box(at: Vector2) -> void:
	var rect := Rect2(_box_start, at - _box_start).abs()
	_box_active = false
	if _box != null:
		_box.finish()

	if rect.size.x < CLICK_BOX_MIN and rect.size.y < CLICK_BOX_MIN:
		toggle_in_selection(prop_at_screen(at))
		return

	if _camera == null:
		return
	var next: Array[Node3D] = []
	for current in _selection:
		next.append(current)
	for prop in _all_props():
		if next.has(prop):
			continue
		var center: Vector3 = prop.global_position
		if prop.has_method("get_center"):
			center = prop.get_center()
		var size := Vector3.ZERO
		if prop.has_method("get_size"):
			size = prop.get_size()
		if ModelBoundsScript.screen_box(_camera, center, size).intersects(rect):
			next.append(prop)
	set_selection(next)


## כל העצמים שהוצבו בעולם.
func _all_props() -> Array:
	var out: Array = []
	if _props_root == null:
		return out
	for child in _props_root.get_children():
		if child.is_in_group(PropScript.GROUP):
			out.append(child)
	return out


## מבטל את כל השינויים שנעשו לעצמים מאז שנבחרו:
## מחזיר כל אחד מהם למיקום ולסיבוב שהיו לו לפני הבחירה, מוריד אותם
## מהרחף (נהיים מוצקים שוב) ויוצא ממצב עריכה.
func cancel_edits() -> void:
	if _selection.is_empty():
		return
	# אם הגרירה באמצע - עוצרים אותה קודם, ואז מחזירים את המצב המקורי.
	if _gizmo != null and _gizmo.is_dragging():
		_gizmo.cancel_drag()
	for prop in _selection:
		if is_instance_valid(prop) and _start_transforms.has(prop):
			prop.global_transform = _start_transforms[prop]
	if _gizmo != null:
		_gizmo.refresh()
	set_selection([])


## מוחק את כל העצמים הנבחרים.
func delete_selected() -> void:
	if _selection.is_empty():
		return
	var doomed: Array[Node3D] = []
	for prop in _selection:
		doomed.append(prop)
	set_selection([])
	for prop in doomed:
		if is_instance_valid(prop):
			prop.queue_free()


## משכפל את כל העצמים הנבחרים ובוחר את ההעתקים.
## כל העתק זהה למקור ברגע השכפול - גם בסיבוב וגם במידות.
func duplicate_selected() -> void:
	if _selection.is_empty() or _placement == null:
		return
	var copies: Array[Node3D] = []
	for prop in _selection:
		if not is_instance_valid(prop):
			continue
		var copy := _placement.spawn_copy_of(prop, prop.global_position + DUPLICATE_OFFSET)
		if copy != null:
			copies.append(copy)
	if not copies.is_empty():
		set_selection(copies)


## מסובב את כל העצמים הנבחרים סביב הציר האנכי שלהם.
## שים לב: הסיבוב במקלדת הוסר - החצים מעבירים עכשיו בין פריימים בציר הזמן.
## הפונקציה נשארה API ציבורי, וסיבוב בפועל נעשה בטבעות הגיזמו ובסרגל הצף.
func rotate_selected(degrees: float) -> void:
	if _selection.is_empty():
		return
	for prop in _selection:
		if is_instance_valid(prop):
			prop.rotate_y(deg_to_rad(degrees))
	if _gizmo != null:
		_gizmo.refresh()


## מה נמצא מתחת לנקודה על המסך - מחזיר את העצם הראשון שהקרן פוגעת בו.
func prop_at_screen(screen_position: Vector2) -> Node3D:
	if _camera == null:
		return null
	var from := _camera.project_ray_origin(screen_position)
	var to := from + _camera.project_ray_normal(screen_position) * RAY_LENGTH
	var space := _camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, PropScript.LAYER)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	return _prop_of(hit.get("collider"))


## עולה מהגוף הפיזי שנלחץ אל העצם שאליו הוא שייך.
func _prop_of(node: Object) -> Node3D:
	var current := node as Node
	while current != null:
		if current.is_in_group(PropScript.GROUP):
			return current as Node3D
		current = current.get_parent()
	return null
