class_name AssetCard
extends Button
## כרטיס אסט בבנק. גוררים אותו מהבנק אל תוך העולם כדי להציב את האסט.
##
## הכרטיס מעביר בגרירה Dictionary שמזהה את האסט, ושטח הקליטה של העולם
## (WorldDropArea) מזהה אותו ומציג לפיו אובייקט רפאים במקום העכבר.

## מזהה האסט שהכרטיס מייצג (נקבע בבניית הכרטיס).
var asset_id: StringName = &""
## התמונה הממוזערת של הכרטיס - מוצגת בזמן הגרירה.
var thumb_rect: TextureRect = null

## סוג המידע שעובר בגרירה, כדי ששטח הקליטה ידע שזה כרטיס מהבנק.
const DRAG_KIND := "studio_asset"
const PREVIEW_SIZE := Vector2(96, 96)


## נקרא אוטומטית על ידי Godot כשמתחילים לגרור את הכרטיס.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if asset_id == &"":
		return null
	set_drag_preview(_make_preview())
	return {"kind": DRAG_KIND, "asset_id": asset_id}


## תצוגה קטנה שעוקבת אחרי העכבר בזמן הגרירה.
func _make_preview() -> Control:
	# ה-holder יושב במקום העכבר, והפאנל מוסט בחצי גודלו כדי שהעכבר יהיה במרכזו.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = PREVIEW_SIZE
	panel.position = -PREVIEW_SIZE * 0.5
	panel.modulate = Color(1.0, 1.0, 1.0, 0.85)
	holder.add_child(panel)

	if thumb_rect != null and thumb_rect.texture != null:
		var picture := TextureRect.new()
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.texture = thumb_rect.texture
		picture.custom_minimum_size = PREVIEW_SIZE * 0.8
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(picture)
	else:
		var label := Label.new()
		label.text = text
		panel.add_child(label)

	return holder
