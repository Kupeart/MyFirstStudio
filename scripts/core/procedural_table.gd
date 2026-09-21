class_name ProceduralTable
extends Node3D
## שולחן שנבנה כולו בקוד, בלפני מודל מבלנדר.
##
## המבנה:
##   ProceduralTable (Node3D - נקודת המוצא בתחתית-המרכז, כמו כל מודל)
##     ├─ Top   (MeshInstance3D - לוח הראש)
##     └─ Leg1..Leg4 (MeshInstance3D - ארבע רגליים בפינות)
##
## שינוי הגודל הוא פרוצדורלי:
##   - רוחב (X) ואורך (Z) משנים רק את לוח הראש; הרגליים רק זזות
##     לפינות החדשות, וגודלן ועובי הראש נשארים קבועים.
##   - גובה (Y) משנה רק את אורך הרגליים, והראש עולה יחד איתן.
##
## הטקסטורה לא נמתחת לעולם: כל תיבה נבנית עם UV שנפרש לפי המידות
## האמיתיות של הפאה - כל מטר בעולם = אותה כמות טקסטורה, בכל גודל
## (ראו make_box_mesh). בפאות הצד, ציר ה-V של הטקסטורה תמיד אנכי,
## כך שכיוון הסיבים של העץ עקבי בכל השולחן.
##
## לכל שולחן יש מופע StandardMaterial3D משלו - אותו עורך חלון החומריות.

## נשלח אחרי כל שינוי מידות (לריענון תיבת ההתנגשות והתצוגה המקדימה).
signal resized

## מידות ברירת מחדל של שולחן אוכל (במטרים).
const DEFAULT_WIDTH := 1.2
const DEFAULT_LENGTH := 0.8
const DEFAULT_HEIGHT := 0.75
## עובי לוח הראש ורוחב רגל - קבועים, לא משתנים בשינוי גודל.
const TOP_THICKNESS := 0.05
const LEG_SIZE := 0.08
## כמה מטרים בעולם תופסת חזרה אחת של הטקסטורה.
const TEXTURE_TILE := 1.0
## גבולות שינוי הגודל - כדי שהשולחן תמיד יישאר שולחן.
const MIN_WIDTH := 0.4
const MAX_WIDTH := 6.0
const MIN_LENGTH := 0.4
const MAX_LENGTH := 6.0
const MIN_HEIGHT := 0.2
const MAX_HEIGHT := 2.0

## הגדרות הפאות: לכל פאה - הנורמל שלה ושני צירי ה-UV.
## הכלל: u × v = normal, ובכל פאות הצד v = "למעלה" (ציר V אנכי),
## כדי שכיוון סיבי העץ יהיה עקבי בכל היקף השולחן.
const FACES: Array[Dictionary] = [
	{"normal": Vector3(1, 0, 0), "u": Vector3(0, 0, -1), "v": Vector3(0, 1, 0)},
	{"normal": Vector3(-1, 0, 0), "u": Vector3(0, 0, 1), "v": Vector3(0, 1, 0)},
	{"normal": Vector3(0, 1, 0), "u": Vector3(1, 0, 0), "v": Vector3(0, 0, -1)},
	{"normal": Vector3(0, -1, 0), "u": Vector3(1, 0, 0), "v": Vector3(0, 0, 1)},
	{"normal": Vector3(0, 0, 1), "u": Vector3(1, 0, 0), "v": Vector3(0, 1, 0)},
	{"normal": Vector3(0, 0, -1), "u": Vector3(-1, 0, 0), "v": Vector3(0, 1, 0)},
]

## טקסטורת העץ שממנה נבנה החומר ברירת המחדל.
const DEFAULT_TEXTURE := "res://assets/models/Furnatures/Textures/WoodTXT1.jpg"

## המידות הנוכחיות (במטרים): x=רוחב, y=גובה, z=אורך.
var dimensions := Vector3(DEFAULT_WIDTH, DEFAULT_HEIGHT, DEFAULT_LENGTH)
## החומר המשותף לכל חלקי השולחן - אותו עורך חלון החומריות.
var table_material: StandardMaterial3D = null

var _top: MeshInstance3D = null
var _legs: Array[MeshInstance3D] = []


func _ready() -> void:
	_build_material()
	_top = MeshInstance3D.new()
	_top.name = "Top"
	add_child(_top)
	for i in 4:
		var leg := MeshInstance3D.new()
		leg.name = "Leg%d" % (i + 1)
		add_child(leg)
		_legs.append(leg)
	_rebuild()
	# הגיאומטריה נבנתה רק עכשיו (ה-Prop לא יכול היה למדוד אותה עדיין) -
	# מודיעים שהמידות "השתנו" כדי שתיבת ההתנגשות תיבנה מחדש.
	resized.emit()


func _build_material() -> void:
	table_material = StandardMaterial3D.new()
	var texture := load(DEFAULT_TEXTURE) as Texture2D
	if texture != null:
		table_material.albedo_texture = texture
	table_material.roughness = 0.7


## המידות הנוכחיות: x=רוחב, y=גובה, z=אורך.
func get_dimensions() -> Vector3:
	return dimensions


## קובע מידות חדשות. כל ציר מוצמד לגבולות הבטיחות בנפרד, כך שאי
## אפשר לשבור את השולחן. משמיט אות resized רק אם באמת השתנה משהו.
func set_dimensions(new_dimensions: Vector3) -> void:
	var clamped := Vector3(
		clampf(new_dimensions.x, MIN_WIDTH, MAX_WIDTH),
		clampf(new_dimensions.y, MIN_HEIGHT, MAX_HEIGHT),
		clampf(new_dimensions.z, MIN_LENGTH, MAX_LENGTH)
	)
	if clamped == dimensions:
		return
	dimensions = clamped
	_rebuild()
	resized.emit()


## מחליף את החומר של השולחן (משמש את התצוגה המקדימה בחלון החומריות,
## שמשתפת את אותו מופע חומר עם השולחן האמיתי).
func set_material(material: StandardMaterial3D) -> void:
	table_material = material
	_apply_material()


func get_material() -> StandardMaterial3D:
	return table_material


# ---------------------------------------------------------- ממשק חלקי חומר
# חלון החומריות עובד עם "חלקים" - לשולחן הפרוצדורלי יש חלק אחד.

## כל חלקי החומר שאפשר לערוך (כאן: השולחן כולו).
func get_material_parts() -> Array[StringName]:
	return [&"table"]


## השם שמוצג לילדים לכל חלק.
func get_part_label(_part: StringName) -> String:
	return "השולחן"


## החומר של חלק מסוים.
func get_part_material(_part: StringName) -> StandardMaterial3D:
	return table_material


## מחליף את החומר של חלק מסוים.
func set_part_material(_part: StringName, material: StandardMaterial3D) -> void:
	set_material(material)


## אילו סטים מותר להחיל על החלק - רשימה ריקה = הכל מותר.
func get_part_presets(_part: StringName) -> Array[String]:
	return []


## מופע חדש של אותו מודל, לתצוגה המקדימה בחלון החומריות.
## הפאנל מוסיף אותו לעץ ואז מסנכרן אליו מידות וחומרים.
func make_preview() -> Node3D:
	var preview := ProceduralTable.new()
	preview.name = "Preview"
	return preview


## מרענן את החומר על כל חלקי השולחן (נקרא גם אחרי בנייה מחדש).
func _apply_material() -> void:
	if table_material == null:
		return
	_top.material_override = table_material
	for leg in _legs:
		leg.material_override = table_material


## בונה מחדש את הגיאומטריה לפי המידות הנוכחיות. הצמתים עצמם נשארים
## (רק הרשת מוחלפת), כדי שמסגרת הבחירה והחומרים לא יאבדו.
func _rebuild() -> void:
	var width := dimensions.x
	var height := dimensions.y
	var length := dimensions.z

	# הראש: רוחב ואורך משתנים, העובי קבוע. הראש מרחף על גבי הרגליים.
	_top.mesh = make_box_mesh(Vector3(width, TOP_THICKNESS, length))
	_top.position = Vector3(0.0, height - TOP_THICKNESS * 0.5, 0.0)

	# הרגליים: אורכן נגזר מהגובה, רוחבן קבוע. הן יושבות מתחת לפינות
	# הראש וזזות החוצה ופנימה יחד עם הרוחב והאורך.
	var leg_length := height - TOP_THICKNESS
	var leg_mesh := make_box_mesh(Vector3(LEG_SIZE, leg_length, LEG_SIZE))
	var leg_x := width * 0.5 - LEG_SIZE * 0.5
	var leg_z := length * 0.5 - LEG_SIZE * 0.5
	for i in _legs.size():
		var leg := _legs[i]
		leg.mesh = leg_mesh
		leg.position = Vector3(
			leg_x if (i & 1) != 0 else -leg_x,
			leg_length * 0.5,
			leg_z if (i & 2) != 0 else -leg_z
		)
	_apply_material()


## בונה תיבה עם UV פרוצדורלי: לכל פאה, ה-UV נפרש על פי המידות האמיתיות
## של אותה פאה בעולם, בחיתוך למרחב הטקסטורה (TEXTURE_TILE מטר לחזרה).
## תוצאה: הטקסטורה לא נמתחת בשום גודל, ומרכז כל פאה ממורכז בתמונה.
static func make_box_mesh(size: Vector3, tile: float = TEXTURE_TILE) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	for face: Dictionary in FACES:
		var normal: Vector3 = face["normal"]
		var u_dir: Vector3 = face["u"]
		var v_dir: Vector3 = face["v"]
		var u_extent := absf(u_dir.dot(size))
		var v_extent := absf(v_dir.dot(size))
		# מרכז הפאה על פני התיבה - המרחק מהמרכז לאורך ציר הנורמל.
		var face_center := normal * absf(half.dot(normal))

		# ארבע הפינות של הפאה וה-UV שלהן (ממורכז - מרכז הפאה במרכז הטקסטורה).
		var corners: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for j in 2:
			for i in 2:
				corners.append(
					face_center
					+ u_dir * (i - 0.5) * u_extent
					+ v_dir * (j - 0.5) * v_extent
				)
				uvs.append(
					Vector2(
						(float(i) - 0.5) * u_extent / tile + 0.5,
						(float(j) - 0.5) * v_extent / tile + 0.5
					)
				)
		# שני משולשים בכיוון סיבוב עם השעון (מבט מבחוץ) - זו המוסכמה של
		# Godot לפאות קדמיות, ובלעדיה כל פאה חיצונית מסוננת והתיבה
		# נראית הפוכה מבפנים.
		for triangle in [[0, 3, 1], [0, 2, 3]]:
			for index in triangle:
				tool.set_normal(normal)
				tool.set_uv(uvs[index])
				tool.add_vertex(corners[index])
	return tool.commit()
