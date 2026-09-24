class_name SidePanelButton
extends IconButton
## כפתור קטן וקבוע בפינת המסך, עם אייקון תמונה, שפותח חלון צד או מציין
## פיצ'ר שיגיע בהמשך:
##   שמאל למעלה   - בנק האסטים, ומתחתיו בחירת עולם
##   ימין למעלה   - חלון ההסבר
##   ימין למטה    - מצב מצלמה וציר הזמן (סגור / פתוח)
##
## האייקונים מוצגים כפי שהם - בלי רקע כהה מאחוריהם.

## סוג החלון או הפיצ'ר שהכפתור מפעיל.
## (!) הסדר חשוב: המזהים של הכפתורים הקיימים בסצנה נשמרים כמו שהם.
enum Slot { ASSET_BANK, HELP, WORLD, CAMERA, TIMELINE }

## גודל כפתור הפינה.
const BUTTON_SIZE := Vector2(56.0, 56.0)

## סוג הציור של כל כפתור - משמש רק כגיבוי אם חסרה תמונת אייקון.
const KINDS := {
	Slot.ASSET_BANK: Kind.CHAIR,
	Slot.HELP: Kind.HELP,
	Slot.WORLD: Kind.NONE,
	Slot.CAMERA: Kind.NONE,
	Slot.TIMELINE: Kind.NONE,
}

## אייקון התמונה של כל כפתור (הקבצים ב-assets/2DUI/Icons).
const ICONS := {
	Slot.ASSET_BANK: preload("res://assets/2DUI/Icons/AssetLibraryIcon.png"),
	Slot.HELP: preload("res://assets/2DUI/Icons/InfoIcon.png"),
	Slot.WORLD: preload("res://assets/2DUI/Icons/WorldIcon.png"),
	Slot.CAMERA: preload("res://assets/2DUI/Icons/CameraIcon.png"),
	Slot.TIMELINE: preload("res://assets/2DUI/Icons/TimelineClosedIcon.png"),
}
## סמליל ציר הזמן כשהוא פתוח (מתחלף עם הסמליל הסגור).
const TIMELINE_OPEN_ICON := preload("res://assets/2DUI/Icons/TimelineOpenIcon.png")

## טקסט העזרה שמוצג בריחוף על כל כפתור.
const TOOLTIPS := {
	Slot.ASSET_BANK: "בנק האסטים",
	Slot.HELP: "הסבר - שליטה בתוכנה",
	Slot.WORLD: "בחירת עולם - בקרוב",
	Slot.CAMERA: "מצב מצלמה - בקרוב",
	Slot.TIMELINE: "פתיחת ציר הזמן",
}

## איזה חלון או פיצ'ר הכפתור הזה מפעיל (נקבע בסצנה).
@export var slot: Slot = Slot.ASSET_BANK

## האם ציר הזמן מסומן כפתוח (רלוונטי לכפתור ציר הזמן בלבד).
var _timeline_open := false


func _ready() -> void:
	# הכפתורים האלה תמיד בהירים ובלי רקע מאחוריהם: רואים את האייקון עצמו.
	configure(int(KINDS.get(slot, Kind.NONE)), TOOLTIPS.get(slot, ""), PLAIN_COLOR, false, false)
	set_icon_texture(ICONS.get(slot) as Texture2D)
	custom_minimum_size = BUTTON_SIZE
	super()


## מציג את סמליל ציר הזמן המתאים: סגור כברירת מחדל, פתוח כשהציר נפתח.
func set_timeline_open(open: bool) -> void:
	_timeline_open = open
	if slot != Slot.TIMELINE:
		return
	set_icon_texture(TIMELINE_OPEN_ICON if open else ICONS[Slot.TIMELINE])
	tooltip_text = "סגירת ציר הזמן" if open else TOOLTIPS[Slot.TIMELINE]


## האם ציר הזמן מסומן כפתוח.
func is_timeline_open() -> bool:
	return _timeline_open
