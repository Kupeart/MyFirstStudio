class_name TimelineManager
extends Node
## ציר הזמן: מקליט את התנוחות (Transform) של העצים לאורך פריימים ומנגן
## אותן בחזרה - זה הלב של הסטופ-מושן.
##
## המודל: FRAME_COUNT משבצות (ברירת מחדל 24). כל משבצת היא מילון
## Prop -> Transform3D - כלומר איך העצם נראה באותו פריים. עצם שלא הוקלט
## בפריים מסוים פשוט לא מופיע במילון שלו.
##
## שני מצבי תצוגה בין ההקלטות:
##   Stepped - כל פריים מציג את ההקלטה האחרונה שאינה מאוחרת ממנו, כלומר
##             התנוחה "מחזיקה" עד ההקלטה הבאה (ברירת המחדל).
##   Spline  - מעבר רך ומתמשך: סיבוב ב-slerp, מיקום וגודל ב-lerp, ובמיקום
##             גם cubic_interpolate כשקיימות נקודות בקרה משני הצדדים.
##
## בצל (Onion Skin): רוח רפאים שקופה של הפריים הקודם ושל הפריים הבא,
## רק עבור העצם הנבחר - כדי לראות לאן הוא נע.
##
## כל הנתונים חיים כאן; חלון ציר הזמן רק שולח לכאן אותות ומציג את המצב.

## נשלח כשהפריים הנוכחי משתנה - בניגון או בבחירת פריים ידנית.
signal frame_changed(frame_index: int)
## נשלח כשמתחיל ניגון או נגמר.
signal state_changed(playing: bool)

## מספר הפריימים בציר (1 עד FRAME_COUNT).
const FRAME_COUNT := 24
## קצב הניגון ההתחלתי (פריימים בשנייה).
const DEFAULT_FPS := 12
## קצבי הניגון שמוצעים בממשק.
const FPS_CHOICES: Array[int] = [6, 12, 24]

## צבע רוח הרפאים של הפריים הקודם (כחלחל) ושל הפריים הבא (אדמדם).
const ONION_PREV_COLOR := Color(0.45, 0.75, 1.0, 0.32)
const ONION_NEXT_COLOR := Color(1.0, 0.5, 0.45, 0.32)

## מנוע הבחירה - ממנו נלקחים העצים המוקלטים, ואותו משחררים לפני ניגון.
var _selection: StudioSelection = null
## ההורה של רוחות הרפאים. בלעדיו הבצל לא מצייר כלום (למשל בבדיקות).
var _ghost_root: Node3D = null

## ההקלטות: FRAME_COUNT מילונים, כל אחד Prop -> Transform3D.
var _frames: Array[Dictionary] = []
## כל העצים שהוקלטו אי פעם - רק אותם מעדכנים בזמן ניגון.
var _keyed_props: Array[Node3D] = []

## הפריים הנוכחי: 1 עד FRAME_COUNT.
var current_frame := 1
## קצב הניגון הנוכחי.
var fps := DEFAULT_FPS
## האם מנגן כרגע.
var playing := false
## מצב האינטרפולציה: false = Stepped (החזקה), true = Spline (מעבר רך).
var spline_mode := false
## בצל: רוח רפאים של הפריים הקודם והבא של העצם הנבחר.
var onion_skin := false
## צילום אוטומטי: בסיום הזזה/סיבוב של עצם נבחר הוא נקלט לפריים הנוכחי.
var auto_frame := false

## כמה זמן עבר מאז הפריים האחרון בזמן ניגון.
var _accumulator := 0.0

## שתי רוחות הרפאים של הבצל (קודם / הבא) ואצל מי הן מוצגות.
var _ghost_prev: Node3D = null
var _ghost_next: Node3D = null
var _ghost_prop: Node3D = null


func _init() -> void:
	# הנתונים קיימים כבר לפני הכניסה לעץ, כדי שאפשר יהיה לבדוק את
	# המנהל בלי להוסיף אותו לסצנה.
	_reset_data()


func _ready() -> void:
	clear()


## מחבר את מנוע הבחירה ואת ההורה של רוחות הרפאים (אופציונלי) ומאפס את הציר.
func setup(selection: StudioSelection, ghost_root: Node3D = null) -> void:
	_selection = selection
	_ghost_root = ghost_root
	# שינוי בחירה מרענן את הבצל. הציר מקשיב בעצמו, כדי שלא יהיה תלוי
	# במי שקורא לו - בחירה חדשה מקבלת רוחות, וביטול בחירה מסיר אותן.
	if _selection != null and not _selection.selection_changed.is_connected(_on_selection_changed):
		_selection.selection_changed.connect(_on_selection_changed)
	clear()


# ------------------------------------------------------------------ נתונים

## מאפס את כל ההקלטות ואת הניגון.
func clear() -> void:
	_reset_data()
	current_frame = 1
	playing = false
	_accumulator = 0.0
	_clear_ghosts()
	frame_changed.emit(current_frame)
	state_changed.emit(false)


## מספר הפריימים בציר.
func get_frame_count() -> int:
	return FRAME_COUNT


## האם הוקלט משהו בפריים הנתון (ברירת מחדל: הפריים הנוכחי).
func has_key(frame_index: int = -1) -> bool:
	var index := current_frame if frame_index < 0 else frame_index
	return not _frame_at(index).is_empty()


## האם העצם הזה מוקלט אי פעם בציר.
func is_prop_keyed(prop: Node3D) -> bool:
	return _keyed_props.has(prop)


## האם הוקלט משהו בכלל בציר (יש מה לנגן).
func has_any_keys() -> bool:
	return not _keyed_props.is_empty()


## כל הפריימים שיש בהם הקלטה כלשהי (למשל לסימון על סרגל הפריימים).
func get_keyed_frames() -> Array[int]:
	var keyed: Array[int] = []
	for index in range(1, FRAME_COUNT + 1):
		if not _frame_at(index).is_empty():
			keyed.append(index)
	return keyed


## ההקלטה של פריים (מילון Prop -> Transform3D).
func _frame_at(frame_index: int) -> Dictionary:
	return _frames[clampi(frame_index - 1, 0, FRAME_COUNT - 1)]


func _reset_data() -> void:
	_frames.clear()
	for index in FRAME_COUNT:
		_frames.append({})
	_keyed_props.clear()


# ------------------------------------------------------------------ הקלטה

## מקליט את העצים הנתונים בפריים הנוכחי, ומחזיר כמה עצים נקלטו.
## המשתמש קורא לזה בלחיצה על "לכידת פריים" עם העצים הנבחרים.
func capture(props: Array) -> int:
	var slot := _frame_at(current_frame)
	var recorded := 0
	for prop in props:
		if prop == null or not is_instance_valid(prop) or not (prop is Node3D):
			continue
		var node := prop as Node3D
		slot[node] = node.global_transform
		if not _keyed_props.has(node):
			_keyed_props.append(node)
		recorded += 1
	# העצם אולי נרשם בציר בדיוק עכשיו - ואם הבצל דלוק מגיעות לו רוחות.
	if recorded > 0:
		refresh_onion()
	return recorded


# ------------------------------------------------------------------ ניגון

## קובע את הפריים הנוכחי ומחיל על העולם את התנוחות שלו (scrubbing).
func set_current_frame(frame_index: int) -> void:
	var clamped := clampi(frame_index, 1, FRAME_COUNT)
	if clamped == current_frame:
		return
	_frame_to(clamped)


## מעבר לפריים הבא.
func next_frame() -> void:
	_frame_to(current_frame + 1)


## מעבר לפריים הקודם.
func previous_frame() -> void:
	_frame_to(current_frame - 1)


## מעבר ל-Keyframe הבא - הפריים הקרוב שיש בו הקלטה כלשהי.
func next_key() -> void:
	var index := _any_key_after(current_frame)
	if index < 0:
		return
	_frame_to(index)


## מעבר ל-Keyframe הקודם - הפריים הקרוב שיש בו הקלטה כלשהי.
func previous_key() -> void:
	var index := _any_key_before(current_frame)
	if index < 0:
		return
	_frame_to(index)


## מתחיל ניגון מהפריים הראשון.
func play() -> void:
	if playing:
		return
	# בזמן ניגון העצים זזים לבד, ובחירה פתוחה תגרום לגיזמו לרדוף אחריהם
	# ולמנוע הבחירה "לזכור" תנוחה שכבר לא נכונה. מסירים אותה דרך ה-API
	# הציבורי של מנוע הבחירה - בלי לפגוע בו.
	if _selection != null and _selection.selection_count() > 0:
		_selection.set_selection([])
	playing = true
	_accumulator = 0.0
	_frame_to(1)
	state_changed.emit(true)


## עוצר את הניגון במקום שבו הוא נמצא.
func stop() -> void:
	if not playing:
		return
	playing = false
	_accumulator = 0.0
	state_changed.emit(false)


## קובע את קצב הניגון (פריימים בשנייה).
func set_fps(value: int) -> void:
	fps = maxi(value, 1)


## מצב האינטרפולציה: Stepped (החזקה) או Spline (מעבר רך).
## מחיל מיד את הפריים הנוכחי, כדי שהשינוי ייראה בלי לזוז.
func set_spline_mode(on: bool) -> void:
	if spline_mode == on:
		return
	spline_mode = on
	apply_frame(current_frame)


## בצל: רוח רפאים של הפריים הקודם ושל הפריים הבא של העצם הנבחר.
func set_onion_skin(on: bool) -> void:
	if onion_skin == on:
		return
	onion_skin = on
	refresh_onion()


## צילום אוטומטי: כל סיום הזזה/סיבוב של עצם נבחר נקלט לפריים הנוכחי.
func set_auto_frame(on: bool) -> void:
	auto_frame = on


func is_spline_mode() -> bool:
	return spline_mode


func is_onion_skin() -> bool:
	return onion_skin


func is_auto_frame() -> bool:
	return auto_frame


## מחיל על העצים את התנוחות של הפריים הנתון, לפי מצב האינטרפולציה.
func apply_frame(frame_index: int) -> void:
	var clamped := clampi(frame_index, 1, FRAME_COUNT)
	for prop in _keyed_props:
		if prop == null or not is_instance_valid(prop):
			continue
		var result: Array = _pose_at(prop, clamped)
		if result[0]:
			var pose: Transform3D = result[1]
			prop.global_transform = pose
	_prune()
	refresh_onion()


func _process(delta: float) -> void:
	if not playing:
		return
	var step := 1.0 / maxf(float(fps), 1.0)
	_accumulator += delta
	while _accumulator >= step:
		_accumulator -= step
		if current_frame >= FRAME_COUNT:
			stop()
			return
		_frame_to(current_frame + 1)


## עובר לפריים, מחיל את התנוחה שלו ומודיע לממשק.
func _frame_to(frame_index: int) -> void:
	current_frame = clampi(frame_index, 1, FRAME_COUNT)
	apply_frame(current_frame)
	frame_changed.emit(current_frame)


## התנוחה של העצם בפריים הנתון, לפי מצב האינטרפולציה.
## מחזיר [נמצא, Transform3D].
func _pose_at(prop: Node3D, frame_index: int) -> Array:
	if spline_mode:
		return _spline_transform(prop, frame_index)
	return _latest_transform(prop, frame_index)


## ההקלטה האחרונה של העצם שאינה מאוחרת מהפריים הנתון (מצב Stepped).
## מחזיר [נמצא, Transform3D].
func _latest_transform(prop: Node3D, frame_index: int) -> Array:
	var index := _key_index_at_or_before(prop, frame_index)
	if index < 0:
		return [false, Transform3D()]
	return [true, _frame_at(index)[prop]]


## מעבר רך בין שתי ההקלטות שמקיפות את הפריים (מצב Spline): סיבוב ב-slerp,
## מיקום וגודל ב-lerp - ובמיקום cubic_interpolate כשקיימות נקודות בקרה משני
## הצדדים (הקלטה שלפני הקודמת וזו שאחרי הבאה), לתנועה בקשת רציפה.
## בקצוות הציר, כשאין הקלטה משני הצדדים, נופל בחזרה להחזקה כמו Stepped.
## מחזיר [נמצא, Transform3D].
func _spline_transform(prop: Node3D, frame_index: int) -> Array:
	var prev_index := _key_index_at_or_before(prop, frame_index)
	var next_index := _key_index_at_or_after(prop, frame_index)
	if prev_index < 0 and next_index < 0:
		return [false, Transform3D()]
	if prev_index < 0:
		return [true, _frame_at(next_index)[prop]]
	if next_index < 0 or next_index == prev_index:
		return [true, _frame_at(prev_index)[prop]]

	var from: Transform3D = _frame_at(prev_index)[prop]
	var to: Transform3D = _frame_at(next_index)[prop]
	var weight := float(frame_index - prev_index) / float(next_index - prev_index)

	var before_index := _key_index_at_or_before(prop, prev_index - 1)
	var after_index := _key_index_at_or_after(prop, next_index + 1)
	var origin := from.origin.lerp(to.origin, weight)
	if before_index > 0 and after_index > 0:
		var control_before: Vector3 = _frame_at(before_index)[prop].origin
		var control_after: Vector3 = _frame_at(after_index)[prop].origin
		origin = from.origin.cubic_interpolate(
			to.origin, control_before, control_after, weight
		)

	var from_quat := from.basis.orthonormalized().get_rotation_quaternion()
	var to_quat := to.basis.orthonormalized().get_rotation_quaternion()
	var rotation := from_quat.slerp(to_quat, weight)
	var scale := from.basis.get_scale().lerp(to.basis.get_scale(), weight)
	return [true, Transform3D(Basis(rotation).scaled(scale), origin)]


## הפריים הקרוב ביותר עם הקלטה של העצם שאינו אחרי הפריים הנתון. -1 אם אין.
func _key_index_at_or_before(prop: Node3D, frame_index: int) -> int:
	for index in range(mini(frame_index, FRAME_COUNT), 0, -1):
		if _frame_at(index).has(prop):
			return index
	return -1


## הפריים הקרוב ביותר עם הקלטה של העצם שאינו לפני הפריים הנתון. -1 אם אין.
func _key_index_at_or_after(prop: Node3D, frame_index: int) -> int:
	for index in range(maxi(frame_index, 1), FRAME_COUNT + 1):
		if _frame_at(index).has(prop):
			return index
	return -1


## הפריים הקרוב שיש בו הקלטה כלשהי, אחרי הפריים הנתון. -1 אם אין.
func _any_key_after(frame_index: int) -> int:
	for index in range(frame_index + 1, FRAME_COUNT + 1):
		if not _frame_at(index).is_empty():
			return index
	return -1


## הפריים הקרוב שיש בו הקלטה כלשהי, לפני הפריים הנתון. -1 אם אין.
func _any_key_before(frame_index: int) -> int:
	for index in range(frame_index - 1, 0, -1):
		if not _frame_at(index).is_empty():
			return index
	return -1


## מסלק מההקלטות עצים שכבר נמחקו מהעולם.
func _prune() -> void:
	var alive: Array[Node3D] = []
	for prop in _keyed_props:
		if prop != null and is_instance_valid(prop):
			alive.append(prop)
	_keyed_props = alive
	for slot in _frames:
		for key in slot.keys():
			if key == null or not is_instance_valid(key):
				slot.erase(key)


# ------------------------------------------------------------------ בצל

## כל שינוי בבחירה מרענף את הבצל: עצם חדש מקבל רוחות משלו, וביטול הבחירה
## מסיר אותן מיד.
func _on_selection_changed(_items: Array) -> void:
	refresh_onion()


## מרענן את רוחות הרפאים של הבצל: מציג אותן לעצם הנבחר (אם צריך) ומסיר
## אותן בכל מקרה אחר. נקרא בכל מעבר פריים, בכל שינוי בחירה ובכיבוי הבצל.
func refresh_onion() -> void:
	var prop := _onion_target()
	if prop == null:
		_clear_ghosts()
		return
	_ensure_ghosts(prop)
	_place_ghost(_ghost_prev, prop, current_frame - 1)
	_place_ghost(_ghost_next, prop, current_frame + 1)


## מספר רוחות הרפאים שמוצגות כרגע (לבדיקות ולממשק).
func get_ghost_count() -> int:
	if _ghost_root == null:
		return 0
	var count := 0
	for child in _ghost_root.get_children():
		if child is Node3D and (child as Node3D).visible:
			count += 1
	return count


## העצם שעבורו מציירים רוחות: רק כשנבחר עצם אחד בדיוק והוא מוקלט בציר.
func _onion_target() -> Node3D:
	if not onion_skin or _selection == null or _selection.selection_count() != 1:
		return null
	var prop := _selection.get_selected()
	if prop == null or not is_instance_valid(prop) or not is_prop_keyed(prop):
		return null
	return prop


## בונה את רוחות הרפאים לעצם הנתון. הבנייה יקרה יחסית, ולכן היא נעשית
## רק כשהעצם הנבחר מתחלף; מעבר בין פריימים רק מזיז את הרוחות הקיימות.
func _ensure_ghosts(prop: Node3D) -> void:
	if _ghost_root == null or not is_instance_valid(_ghost_root):
		return
	if _ghost_prop == prop and _ghost_prev != null and _ghost_next != null:
		return
	_clear_ghosts()
	_ghost_prev = _make_ghost(prop, "OnionPrev", ONION_PREV_COLOR)
	_ghost_next = _make_ghost(prop, "OnionNext", ONION_NEXT_COLOR)
	_ghost_prop = prop


## שכפול של המודל בלבד - בלי תיבת ההתנגשות ובלי קבוצת העצים, כך שהרוח
## לא ניתנת לבחירה ולא משתתפת בפיזיקה. כל המשטחים מקבלים חומר אחיד ושקוף.
func _make_ghost(prop: Node3D, ghost_name: String, color: Color) -> Node3D:
	if not prop.has_method("get_model"):
		return null
	var model: Node3D = prop.get_model()
	if model == null or not is_instance_valid(model):
		return null
	var ghost := model.duplicate() as Node3D
	if ghost == null:
		return null
	ghost.name = ghost_name
	# המודל יושב בתוך העצם עם תנוחה משלו - שומרים אותה כדי לחשב נכון
	# את התנוחה העולמית של הרוח בכל פריים.
	ghost.set_meta("model_local", model.transform)
	var material := _make_ghost_material(color)
	for mesh in _meshes_of(ghost):
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_root.add_child(ghost)
	return ghost


## חומר הרוח: אחיד, בלי תאורה, שקוף למחצה.
func _make_ghost_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## ממקם רוח בתנוחה של הפריים הנתון, ומסתיר אותה כשאין לפריים הזה תנוחה
## (בקצוות הציר). הפריים 0 והפריים שאחרי הסוף פשוט נעלמים.
func _place_ghost(ghost: Node3D, prop: Node3D, frame_index: int) -> void:
	if ghost == null or not is_instance_valid(ghost):
		return
	if frame_index < 1 or frame_index > FRAME_COUNT:
		ghost.visible = false
		return
	var result: Array = _pose_at(prop, frame_index)
	ghost.visible = result[0]
	if result[0]:
		var pose: Transform3D = result[1]
		var local: Transform3D = ghost.get_meta("model_local")
		ghost.global_transform = pose * local


## מוציא את הרוחות מהעץ ומשחרר אותן. ההסרה מהעץ מיידית, כדי שספירת
## הילדים תהיה נכונה מיד (queue_free לבדו משאיר אותן עד סוף הפריים).
func _clear_ghosts() -> void:
	for ghost in [_ghost_prev, _ghost_next]:
		if ghost != null and is_instance_valid(ghost):
			if ghost.get_parent() != null:
				ghost.get_parent().remove_child(ghost)
			ghost.queue_free()
	_ghost_prev = null
	_ghost_next = null
	_ghost_prop = null


## כל ה-MeshInstance3D שבתוך צומת (מודל של עצם יכול להיות בנוי מכמה חלקים).
func _meshes_of(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	var mesh := node as MeshInstance3D
	if mesh != null:
		meshes.append(mesh)
	for child in node.get_children():
		meshes.append_array(_meshes_of(child))
	return meshes
