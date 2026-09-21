class_name SidePanelButton
extends IconButton
## כפתור קטן וקבוע בפינת המסך, שפותח וסוגר חלון צד:
##   כיסא (שמאל למעלה)  - בנק האסטים
##   סימן שאלה (ימין למעלה) - חלון ההסבר

## סוג החלון שהכפתור מפעיל.
enum Slot { ASSET_BANK, HELP }

## איזה חלון הכפתור הזה מפעיל (נקבע בסצנה).
@export var slot: Slot = Slot.ASSET_BANK


func _ready() -> void:
	# הכפתורים האלה תמיד בהירים - הם לא מייצגים מצב שנדלק ונכבה.
	if slot == Slot.HELP:
		configure(Kind.HELP, "הסבר - שליטה בתוכנה", PLAIN_COLOR, true, false)
	else:
		configure(Kind.CHAIR, "בנק האסטים", PLAIN_COLOR, true, false)
	super()
