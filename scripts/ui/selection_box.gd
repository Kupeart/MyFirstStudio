class_name SelectionBox
extends Control
## מלבן הבחירה (rubber band) שנמתח בזמן גרירת Shift + עכבר שמאלי.
##
## הוא שכבת ציור שקופה מעל העולם: לא קולט עכבר בכלל, רק מצייר את המלבן
## לפי מה שמנוע הבחירה מבקש. צבע כחול חצי-שקוף עם מסגרת בהירה.

## צבע המילוי והמסגרת של המלבן.
const FILL_COLOR := Color(0.42, 0.72, 1.0, 0.12)
const BORDER_COLOR := Color(0.42, 0.72, 1.0, 0.85)
const BORDER_WIDTH := 1.5

var _active := false
var _origin := Vector2.ZERO
var _rect := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


## מתחיל מלבן חדש מנקודת הלחיצה.
func begin(at: Vector2) -> void:
	_origin = at
	_rect = Rect2(at, Vector2.ZERO)
	_active = true
	visible = true
	queue_redraw()


## מעדכן את המלבן לפי מיקום הסמן הנוכחי.
func update_to(at: Vector2) -> void:
	if not _active:
		return
	_rect = Rect2(_origin, at - _origin).abs()
	queue_redraw()


## המלבן הנוכחי (בפיקסלים של המסך) - משמש לבחירת העצמים שבתוכו.
func get_box() -> Rect2:
	return _rect


## האם מלבן בחירה פעיל כרגע.
func is_active() -> bool:
	return _active


## מסתיר את המלבן (הגרירה הסתיימה).
func finish() -> void:
	_active = false
	visible = false
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	draw_rect(_rect, FILL_COLOR, true)
	draw_rect(_rect, BORDER_COLOR, false, BORDER_WIDTH)
