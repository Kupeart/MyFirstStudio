class_name TimelineManager
extends Node
## ציר הזמן: מקליט את התנוחות (Transform) של העצים לאורך פריימים ומנגן
## אותן בחזרה - זה הלב של הסטופ-מושן.
##
## המודל: FRAME_COUNT משבצות (ברירת מחדל 24). כל משבצת היא מילון
## Prop -> Transform3D - כלומר איך העצם נראה באותו פריים. עצם שלא הוקלט
## בפריים מסוים פשוט לא מופיע במילון שלו.
##
## ניגון במצב Stepped (ברירת המחדל): כל פריים מציג את ההקלטה האחרונה
## שאינה מאוחרת ממנו - התנוחה "מחזיקה" עד ההקלטה הבאה.
##
## מצב Spline ובצל (Onion Skin) הם כרגע Placeholder בלבד: הדגל נשמר כאן
## בשביל השלב הבא, אבל הניגון עדיין לא משתמש בהם.

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

## מנוע הבחירה - ממנו נלקחים העצים המוקלטים, ואותו משחררים לפני ניגון.
var _selection: StudioSelection = null

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
## Placeholder: מצב אינטרפולציה (Stepped / Spline) - לא משפיע עדיין.
var spline_mode := false
## Placeholder: בצל (Onion Skin) - לא משפיע עדיין.
var onion_skin := false

## כמה זמן עבר מאז הפריים האחרון בזמן ניגון.
var _accumulator := 0.0


func _init() -> void:
	# הנתונים קיימים כבר לפני הכניסה לעץ, כדי שאפשר יהיה לבדוק את
	# המנהל בלי להוסיף אותו לסצנה.
	_reset_data()


func _ready() -> void:
	clear()


## מחבר את מנוע הבחירה ומאפס את הציר.
func setup(selection: StudioSelection) -> void:
	_selection = selection
	clear()


# ------------------------------------------------------------------ נתונים

## מאפס את כל ההקלטות ואת הניגון.
func clear() -> void:
	_reset_data()
	current_frame = 1
	playing = false
	_accumulator = 0.0
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


## Placeholder: מצב האינטרפולציה (Stepped / Spline).
func set_spline_mode(on: bool) -> void:
	spline_mode = on


## Placeholder: בצל (Onion Skin).
func set_onion_skin(on: bool) -> void:
	onion_skin = on


## מחיל על העצים את התנוחות של הפריים הנתון (מצב Stepped).
func apply_frame(frame_index: int) -> void:
	var clamped := clampi(frame_index, 1, FRAME_COUNT)
	for prop in _keyed_props:
		if prop == null or not is_instance_valid(prop):
			continue
		var result: Array = _latest_transform(prop, clamped)
		if result[0]:
			var pose: Transform3D = result[1]
			prop.global_transform = pose
	_prune()


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


## ההקלטה האחרונה של העצם שאינה מאוחרת מהפריים הנתון.
## מחזיר [נמצא, Transform3D].
func _latest_transform(prop: Node3D, frame_index: int) -> Array:
	for index in range(frame_index, 0, -1):
		var slot := _frame_at(index)
		if slot.has(prop):
			return [true, slot[prop]]
	return [false, Transform3D()]


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
