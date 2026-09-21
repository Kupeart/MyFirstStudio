class_name AssetLibrary
extends RefCounted
## בנק האסטים: אוסף כל מה שהילדים יכולים להציב בעולם.
##
## המקור היחיד הוא קבצי המודל של המשתמש: כל קובץ .glb / .gltf / .tscn
## שיושב בתיקיית assets/models.
##   - שם התיקייה העליונה קובע את הקטגוריה (למשל Furnatures -> רהיטים).
##   - שם הקובץ קובע את שם האסט שמוצג לילדים.
##
## כדי להוסיף מודל לבנק: לייצא אותו מבלנדר כ-.glb ולשים אותו בתיקייה
## assets/models/<קטגוריה>/<שם>.glb. אין צורך לגעת בקוד.

const AssetDefScript := preload("res://scripts/core/asset_def.gd")
const ModelBoundsScript := preload("res://scripts/core/model_bounds.gd")
const ProceduralTableScript := preload("res://scripts/core/procedural_table.gd")
const ComputerDeskScript := preload("res://scripts/core/computer_desk.gd")

## התיקייה שממנה נטענים המודלים של המשתמש.
const MODELS_DIR := "res://assets/models"
## תת-התיקיות שאינן נסרקות אחרי מודלים. "ui" מכילה את ההנדלים
## של הגיזמו (עזרי מידול בלבד, לא אסט להצבה) ו-"thumbs" תמונות.
const IGNORED_DIRS := ["thumbs", "ui"]
## סיומות של קבצים שנחשבים למודל.
const MODEL_EXTENSIONS := ["glb", "gltf", "tscn"]

## תרגום שמות קטגוריות לעברית שמוצגת לילדים.
const CATEGORY_LABELS := {
	&"shapes": "צורות",
	&"furniture": "רהיטים",
	&"furnatures": "רהיטים",
	&"furnature": "רהיטים",
	&"furnitures": "רהיטים",
	&"walls": "קירות ורצפות",
	&"nature": "טבע",
	&"characters": "דמויות",
	&"props": "אביזרים",
	&"accessories": "אביזרים",
	&"accesories": "אביזרים",
	&"lights": "תאורה",
	&"models": "מודלים שלי",
}
## סדר הצגת הקטגוריות בבנק. "models" תמיד אחרונה.
const CATEGORY_ORDER := [&"shapes", &"furniture", &"walls", &"nature", &"characters", &"lights"]

var _assets: Array[AssetDefScript] = []
var _by_id: Dictionary = {}


func _init() -> void:
	scan()


## סורק את כל המקורות ובונה מחדש את רשימת האסטים.
func scan() -> void:
	_assets.clear()
	_by_id.clear()
	_scan_dir(MODELS_DIR, &"models", 0)


## כל האסטים שקיימים, לפי סדר ההצגה.
func get_all_assets() -> Array[AssetDefScript]:
	return _assets


## מחזיר את רשימת הקטגוריות שאין בהן ריקות, לפי סדר התצוגה.
func get_categories() -> Array[StringName]:
	var result: Array[StringName] = []

	# הקטגוריות המובנות, בסדר קבוע
	for category in CATEGORY_ORDER:
		if not get_assets_in_category(category).is_empty():
			result.append(category)

	# קטגוריות שהמשתמש יצר בתיקיות משלו (למשל "Furnatures")
	for def in _assets:
		if def.category != &"models" and not result.has(def.category):
			result.append(def.category)

	# קבצים שיושבים ישירות בתיקיית המודלים - אחרונים
	if not get_assets_in_category(&"models").is_empty():
		result.append(&"models")

	return result


func get_assets_in_category(category: StringName) -> Array[AssetDefScript]:
	var result: Array[AssetDefScript] = []
	for def in _assets:
		if def.category == category:
			result.append(def)
	return result


func get_asset(id: StringName) -> AssetDefScript:
	return _by_id.get(id, null) as AssetDefScript


func has_asset(id: StringName) -> bool:
	return _by_id.has(id)


## השם בעברית שמוצג ללמשתמש עבור קטגוריה.
func get_category_label(category: StringName) -> String:
	if CATEGORY_LABELS.has(category):
		return CATEGORY_LABELS[category]
	# תיקייה שהמשתמש יצר ולא הוגדרה מראש - מציגים את שמה כפי שהוא
	return String(category).replace("_", " ")


## יוצר מופע חדש של האסט. מחזיר null אם משהו לא נמצא או לא נטען.
func instantiate_asset(id: StringName) -> Node3D:
	var def := get_asset(id)
	if def == null:
		push_warning("אסט לא נמצא: " + String(id))
		return null
	return instantiate_def(def)


## אסטים שנבנים בקוד במקום להיטען מקובץ מודל. המזהה שלהם זהה לשם
## הקובץ המקורי (בלי סיומת) כדי שהכרטיס בבנק ימשיך לעבוד כרגיל.
const PROCEDURAL_IDS: Array[StringName] = [&"simpletable"]

## מודלים של המשתמש שעוטפים בסקריפט שמוסיף להם שינוי גודל וחומריות.
## המזהה זהה לשם קובץ המודל (בלי סיומת), כמו באסטים הפרוצדורליים.
const WRAPPED_MODEL_SCRIPTS: Dictionary = {
	&"computerdesk": preload("res://scripts/core/computer_desk.gd"),
	&"proceduralchairbench": preload("res://scripts/core/procedural_chair_bench.gd"),
	&"beachball": preload("res://scripts/core/kador_yam.gd"),
	&"soccerball": preload("res://scripts/core/kador_regel.gd"),
	&"jellyball": preload("res://scripts/core/kador_slime.gd"),
	&"ironball": preload("res://scripts/core/kador_barzel.gd"),
}

## שמות תצוגה ידניים לאסטים ששמם נגזר משם הקובץ ויוצא לא קריא.
const DISPLAY_NAME_OVERRIDES: Dictionary = {
	&"proceduralchairbench": "כיסא / ספסל",
	&"beachball": "כדור ים",
	&"soccerball": "כדור רגל",
	&"jellyball": "כדור סליים",
	&"ironball": "כדור ברזל",
}


## יוצר מופע חדש מתוך כרטיס אסט קיים.
func instantiate_def(def: AssetDefScript) -> Node3D:
	# אסט פרוצדורלי - נבנה בקוד, נקודת המוצא שלו כבר בתחתית-המרכז.
	if PROCEDURAL_IDS.has(def.id):
		var procedural: Node3D = ProceduralTableScript.new()
		procedural.name = String(def.id)
		return procedural
	# מודל של המשתמש שעטוף בסקריפט שמוסיף לו התנהגויות (שינוי גודל
	# וחומריות). הסקריפט טוען את ה-GLB בעצמו ומיישר את נקודת המוצא
	# שלו לתחתית-המרכז, ולכן אין צורך ביישור האוטומטי הרגיל.
	if WRAPPED_MODEL_SCRIPTS.has(def.id):
		var wrapped: Node3D = (WRAPPED_MODEL_SCRIPTS[def.id] as GDScript).new()
		wrapped.name = String(def.id)
		return wrapped
	if not ResourceLoader.exists(def.scene_path):
		push_warning("קובץ המודל חסר: " + def.scene_path)
		return null
	var packed := load(def.scene_path) as PackedScene
	if packed == null:
		push_warning("לא ניתן לטעון את המודל: " + def.scene_path)
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_warning("המודל אינו Node3D: " + def.scene_path)
		return null
	instance.name = String(def.id)
	if def.auto_center:
		instance = _fix_origin(def, instance)
	return instance


## מזיז את המודל כך שנקודת המוצא שלו תהיה בתחתית-המרכז של הגיאומטריה.
## כך האובייקט יושב בדיוק על הרצפה ומסתובב סביב עצמו, גם אם בבלנדר הוא
## מוקם רחוק מנקודת הראשית.
func _fix_origin(def: AssetDefScript, instance: Node3D) -> Node3D:
	var bounds := ModelBoundsScript.combined_aabb(instance)
	if bounds.size == Vector3.ZERO:
		push_warning("למודל '%s' אין גיאומטריה שאפשר למדוד." % String(def.id))
		return instance

	_warn_about_size(def, bounds)

	var offset := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	if offset.length() < 0.01:
		return instance

	push_warning(
		"המודל '%s' אינו יושב על נקודת המוצא שלו (הזזה של %s מטר). המנוע מיישר אותו אוטומטית. עדיף לתקן בבלנדר: Origin צריך להיות בתחתית-המרכז." % [String(def.id), str(offset.snappedf(0.01))]
	)

	var wrapper := Node3D.new()
	wrapper.name = String(def.id)
	instance.position = -offset
	wrapper.add_child(instance)
	return wrapper


## אזהרה ידידותית אם המודל נראה לא בקנה מידה של מטרים.
## בבלנדר 1 יחידה = 1 מטר, ולכן רהיט אמור להיות בערך 0.4-2 מטר.
func _warn_about_size(def: AssetDefScript, bounds: AABB) -> void:
	var longest := maxf(maxf(bounds.size.x, bounds.size.y), bounds.size.z)
	if longest <= 4.0:
		return
	push_warning(
		"המודל '%s' גדול מאוד (%.2f x %.2f x %.2f מטר). אם הוא אמור להיות רהיט, הוא כנראה לא בקנה מידה של מטרים: בבלנדר 1 יחידה = 1 מטר, ומתקנים עם S ואז Ctrl+A -> Apply All Transforms." % [
			String(def.id), bounds.size.x, bounds.size.y, bounds.size.z
		]
	)


func _register(def: AssetDefScript) -> void:
	if _by_id.has(def.id):
		push_warning("מזהה אסט כפול, מתעלמים מהשני: " + String(def.id))
		return
	_assets.append(def)
	_by_id[def.id] = def


## סורק תיקייה. שם תת-התיקייה ברמה העליונה (מתחת ל-assets/models) הוא הקטגוריה.
func _scan_dir(dir_path: String, category: StringName, depth: int) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("לא ניתן לפתוח תיקייה: " + dir_path)
		return

	for file_name in dir.get_files():
		var extension := file_name.get_extension().to_lower()
		if MODEL_EXTENSIONS.has(extension):
			_add_model_file(dir_path.path_join(file_name), category, file_name)

	for sub_dir in dir.get_directories():
		if IGNORED_DIRS.has(sub_dir.to_lower()) or sub_dir.begins_with("."):
			continue
		# ברמה העליונה שם התיקייה הופך לקטגוריה; עמוק יותר נשארים באותה קטגוריה.
		var child_category := category
		if depth == 0:
			child_category = StringName(sub_dir.to_lower())
		_scan_dir(dir_path.path_join(sub_dir), child_category, depth + 1)


func _add_model_file(file_path: String, category: StringName, file_name: String) -> void:
	var def: AssetDefScript = AssetDefScript.new()
	def.id = StringName(file_name.get_basename().to_lower())
	if DISPLAY_NAME_OVERRIDES.has(def.id):
		def.display_name = DISPLAY_NAME_OVERRIDES[def.id]
	else:
		def.display_name = _pretty_name(file_name.get_basename())
	def.category = category
	def.scene_path = file_path
	_register(def)


## שמות העצמים מוצגים בעברית גם כשקובץ המודל נקרא באנגלית.
##
## איך השם נבנה: מפרקים את שם הקובץ למילים, המילה האחרונה באנגלית היא
## הראשית (SimpleTable = Table של Simple), ובאנגלית התואר בא לפני העצם
## ובעברית אחריו - ולכן התוצאה היא "שולחן פשוט".
##
## מילה שלא נמצאת באף מילון מתועתקת אוטומטית לאותיות עבריות, כך שבמסך
## תמיד יופיע עברית ולא אנגלית.
##
## שם עצם: "תרגום|m" או "תרגום|f" - האות קובעת את המין, כדי ששם התואר
## שאחריו יקבל את הצורה הנכונה (שולחן פשוט / ספה פשוטה).
const NOUN_HEBREW := {
	"table": "שולחן|m", "desk": "שולחן|m", "chair": "כיסא|m", "stool": "שרפרף|m",
	"sofa": "ספה|f", "couch": "ספה|f", "bed": "מיטה|f", "lamp": "מנורה|f",
	"shelf": "מדף|m", "bookshelf": "ספרייה|f", "cabinet": "ארון|m", "cupboard": "ארון|m",
	"wardrobe": "ארון בגדים|m", "door": "דלת|f", "window": "חלון|m", "rug": "שטיח|m",
	"carpet": "שטיח|m", "plant": "צמח|m", "wall": "קיר|m", "floor": "רצפה|f",
	"ceiling": "תקרה|f", "box": "קופסה|f", "crate": "ארגז|m", "ball": "כדור|m",
	"cube": "קובייה|f", "block": "קובייה|f", "sphere": "כדור|m", "cylinder": "גליל|m",
	"cone": "חרוט|m", "book": "ספר|m", "tv": "טלוויזיה|f", "television": "טלוויזיה|f",
	"screen": "מסך|m", "monitor": "מסך|m", "computer": "מחשב|m", "laptop": "מחשב נייד|m",
	"keyboard": "מקלדת|f", "mouse": "עכבר|m", "printer": "מדפסת|f", "fridge": "מקרר|m",
	"refrigerator": "מקרר|m", "stove": "כיריים|f", "oven": "תנור|m", "sink": "כיור|m",
	"mirror": "מראה|f", "clock": "שעון|m", "picture": "תמונה|f", "frame": "מסגרת|f",
	"vase": "אגרטל|m", "candle": "נר|m", "tree": "עץ|m", "bush": "שיח|m",
	"flower": "פרח|m", "rock": "סלע|m", "stone": "אבן|f", "fence": "גדר|f",
	"stairs": "מדרגות|f", "stair": "מדרגה|f", "pillow": "כרית|f", "blanket": "שמיכה|f",
	"curtain": "וילון|m", "lock": "מנעול|m", "key": "מפתח|m", "tool": "כלי|m",
	"barrel": "חבית|f", "sign": "שלט|m", "light": "אור|m", "bench": "ספסל|m",
	"counter": "דלפק|m", "plate": "צלחת|f", "cup": "כוס|f", "mug": "ספל|m",
	"bottle": "בקבוק|m", "pot": "סיר|m", "pan": "מחבת|f", "radio": "רדיו|m",
	"speaker": "רמקול|m", "camera": "מצלמה|f", "phone": "טלפון|m", "machine": "מכונה|f",
	"toy": "צעצוע|m", "ramp": "רמפה|f", "platform": "במה|f", "furniture": "רהיט|m",
}

## שם תואר: "צורת זכר|צורת נקבה".
const MODIFIER_HEBREW := {
	"simple": "פשוט|פשוטה", "small": "קטן|קטנה", "little": "קטן|קטנה", "tiny": "זעיר|זעירה",
	"big": "גדול|גדולה", "large": "גדול|גדולה", "tall": "גבוה|גבוהה", "low": "נמוך|נמוכה",
	"short": "קצר|קצרה", "long": "ארוך|ארוכה", "wide": "רחב|רחבה", "narrow": "צר|צרה",
	"old": "ישן|ישנה", "new": "חדש|חדשה", "modern": "מודרני|מודרנית",
	"classic": "קלאסי|קלאסית", "wooden": "מעץ|מעץ", "metal": "ממתכת|ממתכת",
	"plastic": "מפלסטיק|מפלסטיק", "glass": "מזכוכית|מזכוכית",
	"red": "אדום|אדומה", "blue": "כחול|כחולה", "green": "ירוק|ירוקה", "yellow": "צהוב|צהובה",
	"black": "שחור|שחורה", "white": "לבן|לבנה", "gray": "אפור|אפורה", "grey": "אפור|אפורה",
	"brown": "חום|חומה", "orange": "כתום|כתומה", "purple": "סגול|סגולה", "pink": "ורוד|ורודה",
	"round": "עגול|עגולה", "square": "מרובע|מרובעת", "heavy": "כבד|כבדה", "lightweight": "קל|קלה",
	"dark": "כהה|כהה", "bright": "בהיר|בהירה", "soft": "רך|רכה", "fancy": "מפואר|מפוארת",
	"clean": "נקי|נקייה", "nice": "נחמד|נחמדה", "cute": "חמוד|חמודה",
}

## כללי תעתוק מאנגלית לאותיות עבריות - רשת ביטחון למילה שאינה במילון.
## הזוגות הארוכים קודם, כדי למשל ש-"ch" ייתפס לפני "c".
const TRANSLIT_RULES := [
	["sch", "ש"], ["tch", "צ׳"], ["ch", "צ׳"], ["sh", "ש"], ["th", "ת"], ["ph", "פ"],
	["ck", "ק"], ["qu", "קו"], ["oo", "ו"], ["ou", "או"], ["ee", "י"], ["ea", "י"],
	["ai", "יי"], ["ay", "יי"], ["a", "א"], ["b", "ב"], ["c", "ק"], ["d", "ד"],
	["e", "ה"], ["f", "פ"], ["g", "ג"], ["h", "ה"], ["i", "י"], ["j", "ג׳"],
	["k", "ק"], ["l", "ל"], ["m", "מ"], ["n", "נ"], ["o", "ו"], ["p", "פ"],
	["q", "ק"], ["r", "ר"], ["s", "ס"], ["t", "ט"], ["u", "ו"], ["v", "ב"],
	["w", "ו"], ["x", "קס"], ["y", "י"], ["z", "ז"],
]


## "SimpleTable" -> "שולחן פשוט", "ComputerDesk" -> "שולחן מחשב".
func _pretty_name(base_name: String) -> String:
	var words := _split_words(base_name)
	if words.is_empty():
		return base_name

	# המילה האחרונה היא הראשית; היא קובעת גם את המין לתואר שאחריה.
	var head_key := words[words.size() - 1].to_lower()
	var head := ""
	var feminine := false
	if NOUN_HEBREW.has(head_key):
		var head_parts := String(NOUN_HEBREW[head_key]).split("|")
		head = head_parts[0]
		feminine = head_parts.size() > 1 and head_parts[1] == "f"
	else:
		head = _transliterate(head_key)

	var modifiers: Array[String] = []
	for i in words.size() - 1:
		modifiers.append(_translate_modifier(words[i], feminine))

	if modifiers.is_empty():
		return head
	return head + " " + " ".join(modifiers)


## מתרגם מילת לוואי (תואר, או שם עצם שמתפקד כתואר) ומתאים אותה למין הראשית.
func _translate_modifier(word: String, feminine: bool) -> String:
	var key := word.to_lower()
	if MODIFIER_HEBREW.has(key):
		var forms := String(MODIFIER_HEBREW[key]).split("|")
		if feminine and forms.size() > 1:
			return forms[1]
		return forms[0]
	# מילה לא מוכרת היא אולי שם עצם שמשמש כתואר - למשל "Computer" ב-ComputerDesk.
	if NOUN_HEBREW.has(key):
		return String(NOUN_HEBREW[key]).split("|")[0]
	return _transliterate(key)


## מפרק שם קובץ למילים: לפי מפרידים ובגבול בין אות קטנה לגדולה.
## ספרות נזרקות ("Table2" נשאר "Table").
func _split_words(base_name: String) -> Array[String]:
	var cleaned := base_name.replace("_", " ").replace("-", " ")
	var words: Array[String] = []
	for chunk in cleaned.split(" ", false):
		var current := ""
		var previous := ""
		for i in chunk.length():
			var ch := chunk[i]
			var is_digit := ch >= "0" and ch <= "9"
			if is_digit:
				if not current.is_empty():
					words.append(current)
					current = ""
				previous = ""
				continue
			var is_upper := ch == ch.to_upper() and ch != ch.to_lower()
			if is_upper and not current.is_empty() and previous == previous.to_lower():
				words.append(current)
				current = ""
			current += ch
			previous = ch
		if not current.is_empty():
			words.append(current)
	return words


## מתעתק מילה באנגלית לאותיות עבריות - גיבוי בלבד.
func _transliterate(word: String) -> String:
	var out := ""
	var i := 0
	while i < word.length():
		var matched := false
		for rule in TRANSLIT_RULES:
			var pattern: String = rule[0]
			if word.substr(i, pattern.length()) == pattern:
				out += rule[1]
				i += pattern.length()
				matched = true
				break
		if not matched:
			out += word[i]
			i += 1
	return out
