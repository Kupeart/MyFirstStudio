class_name IconButton
extends Button
## כפתור אייקון גנרי שמצייר את הסמל שלו בקוד (draw_line / draw_arc / draw_polygon).
##
## למה לצייר ולא להשתמש בתמונות או בתווי טקסט: הסמלים ⤧ ו-↻ לא קיימים
## בגופנים העבריים, וקבצי תמונה דורשים ניהול נכסים. ציור בקוד עובד בכל
## גופן, בכל רזולוציה, ומאפשר לשנות את כל האייקונים במקום אחד.
##
## שני סוגי כפתור:
##   toggle_style = true  - כפתור מצב (כמו הזזה/סיבוב): כבוי = סמל עמום,
##                          פעיל = רקע כחול + סמל בהיר.
##   toggle_style = false - כפתור פעולה (שכפול/אישור/מחיקה/חלונות):
##                          הסמל תמיד בהיר.

enum Kind { MOVE, ROTATE, SCALE, RESIZE, DUPLICATE, CONFIRM, DELETE, TOOLBOX, CHAIR, HELP, NONE }

## גדלים: עם רקע מעוגל או סמל בלבד (כמו ה-✓ וה-✗ בסקיצה).
const SIZE_BOXED := Vector2(46.0, 46.0)
const SIZE_BARE := Vector2(40.0, 40.0)
## כמה מגודל הכפתור תופס אייקון תמונה (השאר נשאר שוליים).
const TEXTURE_INSET := 0.95

## צבע הסמלים במצב רגיל (כחול-ציאן כמו בסקיצה).
const ICON_COLOR := Color(0.42, 0.72, 1.0)
## שקיפות הסמל כשמצב כבוי.
const IDLE_ALPHA := 0.38
## רקע הכפתור: פעיל / רגיל / ריחוף / לחוץ.
const ACTIVE_BG := Color(0.12, 0.30, 0.50, 0.90)
const IDLE_BG := Color(0.08, 0.09, 0.12, 0.55)
## כפתור פעולה (לא מצב) מקבל רקע כהה ואטום יותר - כמו בסקיצה.
const ACTION_BG := Color(0.10, 0.11, 0.14, 0.92)
const HOVER_BG := Color(0.15, 0.38, 0.62, 0.90)
const PRESSED_BG := Color(0.42, 0.72, 1.0, 0.45)
## צבעים לסמלים צבעוניים במיוחד (אישור ירוק, מחיקה אדומה).
const CONFIRM_COLOR := Color(0.44, 0.92, 0.5)
const DELETE_COLOR := Color(0.96, 0.42, 0.40)
const PLAIN_COLOR := Color(0.92, 0.94, 0.98)
const CORNER_RADIUS := 6.0

var icon_kind: Kind = Kind.MOVE
## אייקון תמונה (PNG מ-assets/2DUI/Icons) שמחליף את הסמל המצויר בקוד.
## null = מציירים את הסמל בקוד כרגיל.
var icon_texture: Texture2D = null
## האם יש רקע מעוגל מאחורי הסמל.
var boxed := true
## האם הסמל מתעמעם כשלא פעיל (כפתור מצב) או תמיד בהיר (כפתור פעולה).
var toggle_style := true
var active := false
var icon_color := ICON_COLOR


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = SIZE_BOXED if boxed else SIZE_BARE
	_apply_style()
	queue_redraw()


## מגדיר את הכפתור. אפשר לקרוא לזה לפני או אחרי הוספה לעץ.
func configure(
	kind_value: Kind,
	tip: String,
	color: Color = ICON_COLOR,
	with_background: bool = true,
	is_toggle: bool = true,
	texture: Texture2D = null
) -> void:
	icon_kind = kind_value
	tooltip_text = tip
	icon_color = color
	boxed = with_background
	toggle_style = is_toggle
	icon_texture = texture
	custom_minimum_size = SIZE_BOXED if boxed else SIZE_BARE
	if is_inside_tree():
		_apply_style()
	queue_redraw()


## מחליף את אייקון התמונה של הכפתור (למשל סמליל ציר זמן סגור/פתוח).
func set_icon_texture(texture: Texture2D) -> void:
	icon_texture = texture
	queue_redraw()


## מדליק או מכבה את מצב "פעיל" של הכפתור.
func set_active(on: bool) -> void:
	if active == on:
		return
	active = on
	if boxed:
		_apply_style()
	queue_redraw()


## סגנון הרקע של הכפתור לפי מצב פעיל/כבוי/ריחוף.
func _apply_style() -> void:
	if not boxed:
		for state in ["normal", "hover", "pressed"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		return

	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(CORNER_RADIUS)
	if active:
		normal.bg_color = ACTIVE_BG
	elif toggle_style:
		normal.bg_color = IDLE_BG
	else:
		normal.bg_color = ACTION_BG
	if active:
		normal.set_border_width_all(2)
		normal.border_color = Color(icon_color.r, icon_color.g, icon_color.b, 0.75)
	add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = ACTIVE_BG if active else HOVER_BG
	add_theme_stylebox_override("hover", hover)

	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color = PRESSED_BG
	add_theme_stylebox_override("pressed", pressed_style)


# ------------------------------------------------------------------ ציור

func _draw() -> void:
	var center := size * 0.5
	var extent := minf(size.x, size.y)
	var color := icon_color
	if toggle_style:
		color.a = 1.0 if active else IDLE_ALPHA

	# כפתור עם אייקון תמונה מצייר את התמונה עצמה במקום הסמל המצויר בקוד.
	if icon_texture != null:
		_draw_texture_icon(center, extent, color)
		return

	match icon_kind:
		Kind.MOVE:
			_draw_move(center, extent * 0.33, color)
		Kind.ROTATE:
			_draw_rotate(center, extent * 0.28, color)
		Kind.SCALE:
			_draw_scale(center, extent * 0.34, color)
		Kind.RESIZE:
			_draw_resize(center, extent * 0.34, color)
		Kind.DUPLICATE:
			_draw_duplicate(center, extent * 0.30, color)
		Kind.CONFIRM:
			_draw_check(center, extent * 0.30, color)
		Kind.DELETE:
			_draw_cross(center, extent * 0.28, color)
		Kind.TOOLBOX:
			_draw_toolbox(center, extent * 0.30, color)
		Kind.CHAIR:
			_draw_chair(center, extent * 0.30, color)
		Kind.HELP:
			_draw_help(center, extent, color)


## מצייר אייקון תמונה במרכז הכדור, מוקטן כך שייכנס בריבוע שגודלו
## TEXTURE_INSET מגודל הכפתור, בלי לעוות את יחס הגובה-רוחב שלו.
func _draw_texture_icon(center: Vector2, extent: float, color: Color) -> void:
	var tex_size := icon_texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var box := extent * TEXTURE_INSET
	var fit := minf(box / tex_size.x, box / tex_size.y)
	var draw_size := tex_size * fit
	draw_texture_rect(icon_texture, Rect2(center - draw_size * 0.5, draw_size), false, color)


## ארבעה חצים מהמרכז לכל הכיוונים - סמל ההזזה.
func _draw_move(center: Vector2, length: float, color: Color) -> void:
	var head := length * 0.45
	var shaft_end := length - head * 0.55
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var end := center + dir * shaft_end
		draw_line(center - dir * 2.0, end, color, 4.0, true)
		var side := Vector2(-dir.y, dir.x)
		var tip := center + dir * length
		var base := center + dir * (length - head)
		draw_colored_polygon(
			PackedVector2Array([tip, base + side * head * 0.62, base - side * head * 0.62]), color
		)


## שתי קשתות עם ראשי חצים - סמל הסיבוב.
func _draw_rotate(center: Vector2, radius: float, color: Color) -> void:
	var gap := deg_to_rad(60.0)
	for offset: float in [0.0, PI]:
		var start := offset + gap * 0.5
		var end := offset + PI - gap * 0.5
		draw_arc(center, radius, start, end, 32, color, 4.0, true)
		_arrow_head(center, radius, end, color)


## ריבוע קטן במרכז וארבעה חצים יוצאים באלכסון - סמל קנה המידה.
func _draw_scale(center: Vector2, length: float, color: Color) -> void:
	var core := length * 0.28
	draw_rect(Rect2(center - Vector2(core, core), Vector2(core, core) * 2.0), color, true)
	var head := length * 0.42
	for raw_dir: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var dir := raw_dir.normalized()
		var tip := center + dir * length
		var base := tip - dir * head
		draw_line(center + dir * (core + 1.5), base, color, 3.0, true)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(
			PackedVector2Array([tip, base + side * head * 0.55, base - side * head * 0.55]), color
		)


## שלושה חצים עם ראשים מרובעים - סמל שינוי הגודל של השולחן הפרוצדורלי
## (בדיוק כמו שלושת החצים שעל השולחן עצמו).
func _draw_resize(center: Vector2, length: float, color: Color) -> void:
	var head := length * 0.3
	for raw_dir: Vector2 in [Vector2.UP, Vector2(-0.78, 0.62), Vector2(0.78, 0.62)]:
		var dir := raw_dir.normalized()
		var tip := center + dir * length
		var shaft_end := tip - dir * head
		var side := Vector2(-dir.y, dir.x)
		draw_line(center + dir * 2.0, shaft_end, color, 3.6, true)
		# ראש מרובע: ריבוע שממשיך את המוט, כמו ראשי החצים על השולחן.
		draw_colored_polygon(
			PackedVector2Array(
				[
					tip + side * head * 0.55,
					tip - side * head * 0.55,
					shaft_end - side * head * 0.55,
					shaft_end + side * head * 0.55,
				]
			),
			color
		)
	draw_rect(Rect2(center - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), color, true)


## שני ריבועים חופפים - סמל השכפול.
func _draw_duplicate(center: Vector2, half: float, color: Color) -> void:
	var shift := Vector2(half * 0.34, half * 0.34)
	var back := Rect2(center - Vector2(half, half) - shift, Vector2(half, half) * 2.0)
	draw_rect(back, color, false, 2.6, true)
	var front := Rect2(center - Vector2(half, half) + shift, Vector2(half, half) * 2.0)
	draw_rect(front, color, false, 2.6, true)


## סימן אישור.
func _draw_check(center: Vector2, arm: float, color: Color) -> void:
	var a := center + Vector2(-arm * 0.95, arm * 0.05)
	var b := center + Vector2(-arm * 0.25, arm * 0.75)
	var c := center + Vector2(arm * 1.0, -arm * 0.75)
	draw_polyline(PackedVector2Array([a, b, c]), color, 5.0, true)


## סימן מחיקה (X).
func _draw_cross(center: Vector2, arm: float, color: Color) -> void:
	draw_line(center + Vector2(-arm, -arm), center + Vector2(arm, arm), color, 5.0, true)
	draw_line(center + Vector2(-arm, arm), center + Vector2(arm, -arm), color, 5.0, true)


## ארגז כלים עם ידית ומפתח ברגים בפנים.
func _draw_toolbox(center: Vector2, scale_hint: float, color: Color) -> void:
	var width := scale_hint * 1.7
	var height := scale_hint * 1.1
	var case := Rect2(
		center - Vector2(width * 0.5, height * 0.1), Vector2(width, height * 0.8)
	)
	draw_rect(case, color, false, 2.6, true)
	var handle := Rect2(
		center - Vector2(width * 0.17, height * 0.55), Vector2(width * 0.34, height * 0.5)
	)
	draw_rect(handle, color, false, 2.6, true)
	# מפתח ברגים קטן במרכז התיבה.
	var wrench_a := center + Vector2(-width * 0.17, height * 0.12)
	var wrench_b := center + Vector2(width * 0.17, -height * 0.14)
	draw_line(wrench_a, wrench_b, color, 2.6, true)
	draw_circle(wrench_a, 2.6, color, false, 2.0, true)


## כיסא פשוט - סמל בנק האסטים.
func _draw_chair(center: Vector2, scale_hint: float, color: Color) -> void:
	var width := scale_hint * 0.95
	var height := scale_hint * 1.55
	# משענת גב
	draw_rect(
		Rect2(center + Vector2(-width * 0.55, -height), Vector2(width * 0.34, height * 1.02)), color, true
	)
	# מושב
	draw_rect(
		Rect2(center + Vector2(-width * 0.78, -height * 0.16), Vector2(width * 1.56, height * 0.22)),
		color,
		true
	)
	# רגליים
	draw_line(
		center + Vector2(-width * 0.62, height * 0.06),
		center + Vector2(-width * 0.62, height * 0.62),
		color,
		3.2,
		true
	)
	draw_line(
		center + Vector2(width * 0.62, height * 0.06),
		center + Vector2(width * 0.62, height * 0.62),
		color,
		3.2,
		true
	)


## סימן שאלה - סמל חלון ההסבר. מצויר בגופן (תו קיים בכל גופן).
func _draw_help(center: Vector2, extent: float, color: Color) -> void:
	var font := get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := int(extent * 0.66)
	if font != null:
		var glyph := "?"
		var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
		draw_string(font, pos, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		return
	# גיבוי בקווים, למקרה שאין גופן בכלל.
	draw_arc(center + Vector2(0.0, -extent * 0.14), extent * 0.15, PI * 0.85, PI * 2.3, 20, color, 3.0, true)
	draw_line(center + Vector2(0.0, extent * 0.03), center + Vector2(0.0, extent * 0.12), color, 3.0, true)
	draw_circle(center + Vector2(0.0, extent * 0.22), 2.2, color, true)


## ראש חץ בקצה קשת סיבוב - מצביע לכיוון ההתקדמות שלה.
func _arrow_head(center: Vector2, radius: float, angle: float, color: Color) -> void:
	var tip := center + Vector2(cos(angle), sin(angle)) * radius
	var tangent := Vector2(-sin(angle), cos(angle))
	var side := Vector2(-tangent.y, tangent.x)
	var back := tip - tangent * 8.0
	draw_colored_polygon(PackedVector2Array([tip + tangent * 2.5, back + side * 5.0, back - side * 5.0]), color)
