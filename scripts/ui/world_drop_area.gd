class_name WorldDropArea
extends Control
## שטח שקוף שמכסה את כל המסך וקולט גרירה של כרטיס אסט מהבנק אל תוך העולם.
##
## הוא יושב *מתחת* לחלונות הממשק (בנק האסטים, חלון העזרה), ולכן גרירה מעל
## חלון כזה לא מגיעה לכאן בכלל, ושחרור שם פשוט מבטל את ההצבה.
##
## mouse_filter = PASS, כדי שלחיצות וגרירות של המצלמה ימשיכו לעבור למנוע
## התלת-ממד ולא ייבלעו על ידי השטח הזה.

## סוג המידע שמגיע מכרטיס בבנק.
const DRAG_KIND := "studio_asset"

## נשלח בכל תזוזת עכבר בזמן גרירה מעל העולם.
signal drag_moved(asset_id: StringName, screen_position: Vector2)
## נשלח כשהמשתמש שחרר את הכרטיס מעל העולם.
signal asset_dropped(asset_id: StringName, screen_position: Vector2)
## נשלח כשהגרירה הסתיימה בלי הצבה (ביטול או שחרור מחוץ לעולם).
signal drag_cancelled()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var asset_id := _asset_id_of(data)
	if asset_id == &"":
		return false
	drag_moved.emit(asset_id, get_viewport().get_mouse_position())
	return true


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var asset_id := _asset_id_of(data)
	if asset_id == &"":
		return
	asset_dropped.emit(asset_id, get_viewport().get_mouse_position())


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drag_cancelled.emit()


## מוציא את מזהה האסט מתוך המידע שהכרטיס החזיר בגרירה.
static func _asset_id_of(data: Variant) -> StringName:
	if typeof(data) != TYPE_DICTIONARY:
		return &""
	var info: Dictionary = data
	if info.get("kind", "") != DRAG_KIND:
		return &""
	return info.get("asset_id", &"")
