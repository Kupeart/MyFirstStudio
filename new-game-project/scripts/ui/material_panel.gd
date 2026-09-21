class_name MaterialPanel
extends PanelContainer
## חלון "חומריות" - עריכת החומר של השולחן הנבחר.
##
## המבנה מלמעלה למטה (כמו בסקיצה):
##   ✓ ירוק / ✗ אדום בצד שמאל, וכותרת "חומריות" מימין
##   :תצוגה - תצוגה מקדימה חיה של השולחן עם ההגדרות הנוכחיות
##   צבע   - טור כדורי חומר (מרונדרים בתלת-ממד) + גלגל צבעים,
##           וריבוע קטן שמראה את הצבע הנוכחי
##   מד מתכתיות ומד שקיפות - מחוונים ירוקים עבים עם התווית מעל
##
## התנהגות: כל שינוי מוחל מיד על השולחן האמיתי בעולם ועל התצוגה
## המקדימה (שמשתפת את אותו מופע חומר). בפתיחה נשמר תצלום מצב של
## ההגדרות: ✓ שומר וסוגר, ✗ מחזיר את ההגדרות וסוגר.

const IconButtonScript := preload("res://scripts/ui/icon_button.gd")
const ModelBoundsScript := preload("res://scripts/core/model_bounds.gd")

## מידות התצוגה המקדימה, הגלגל, ריבוע הצבע וכדורי החומר.
const PREVIEW_HEIGHT := 158.0
const WHEEL_SIZE := 200.0
const SWATCH_SIZE := 26.0
const SPHERE_ICON_SIZE := 50.0
const SPHERE_RENDER_SIZE := 80
const PRESET_COLUMN_WIDTH := 176.0
const PRESET_COLUMN_HEIGHT := 252.0
## גובה המחוונים - כמו הפסים העבים שבסקיצה.
const SLIDER_HEIGHT := 34.0
## מאיפה נסרקות תמונות לסטי חומרים, ואילו סיומות נחשבות חומר.
const SCAN_ROOT := "res://assets"
const SKIP_DIRS: Array[String] = ["thumbs"]
const IMAGE_EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp", "bmp"]
## צבעי החלון.
const PANEL_BG := Color(0.176, 0.176, 0.188, 0.97)
const TEXT_COLOR := Color(0.94, 0.95, 0.98)
const SLIDER_FILL := Color(0.42, 0.60, 0.29)
const SLIDER_FILL_HOVER := Color(0.50, 0.70, 0.35)
const SLIDER_TRACK := Color(0.15, 0.16, 0.19)
const SLIDER_HANDLE := Color(0.87, 0.89, 0.93)
const ACCENT_BLUE := Color(0.35, 0.62, 0.95)
const PRESET_HOVER_BG := Color(0.28, 0.30, 0.34, 0.85)
const PRESET_ACTIVE_BG := Color(0.20, 0.42, 0.62, 0.95)

## העצם הנערך (Prop) והמודל שלו (שולחן פרוצדורלי, שולחן מחשב וכו').
var _prop: Node3D = null
var _table: Node3D = null
## תצלום מצב של הגדרות החומר בפתיחת החלון, לכל חלק בנפרד - לביטול ב-✗.
var _snapshot: Dictionary = {}

var _layout: VBoxContainer = null
var _preview_viewport: SubViewport = null
var _preview_model: Node3D = null
var _parts_column: VBoxContainer = null
## החלק שנערך כרגע (למשל "ראש השולחן" או "רגליים") - רלוונטי רק
## כשלמודל יש יותר מחלק אחד.
var _active_part: StringName = &""
var _part_buttons: Dictionary = {}
var _picker: ColorPicker = null
var _swatch: ColorRect = null
var _presets_column: VBoxContainer = null
var _preset_group := ButtonGroup.new()
var _metallic_slider: HSlider = null
var _transparency_slider: HSlider = null
## דגל שמונע האזנה עצמית: כשהפקדים מסתנכרנים מהחומר, לא מחילים בחזרה.
var _syncing := false
## תור רינדור כדורי החומר - אחד לפריים, כדי לא להקפיא את המשחק.
var _sphere_queue: Array[Dictionary] = []
var _sphere_busy := false
## מטמון טקסטורות של כדורים: מפתח סט -> טקסטורה.
var _sphere_cache: Dictionary = {}
## מפתח סט -> צומת התמונה שמחכה לטקסטורה שלו.
var _sphere_icons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_style()
	_layout = VBoxContainer.new()
	_layout.name = "Layout"
	_layout.add_theme_constant_override("separation", 8)
	add_child(_layout)

	_build_header()
	_build_preview()
	_build_color_section()
	_metallic_slider = _build_slider_row(":מתכתיות")
	_metallic_slider.value_changed.connect(_on_metallic_changed)
	_transparency_slider = _build_slider_row(":שקיפות")
	_transparency_slider.value_changed.connect(_on_transparency_changed)
	_build_accent_line()

	visible = false
	# החלון נצמד לצד שמאל המסך, ממורכז אנכית.
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 16)


func _process(_delta: float) -> void:
	# כדורי החומר מרונדרים אחד לפריים, רק כשהחלון פתוח.
	if not visible or _sphere_busy or _sphere_queue.is_empty():
		return
	_sphere_busy = true
	var job: Dictionary = _sphere_queue.pop_front()
	_render_sphere_thumbnail(String(job["key"]), job["preset"])


# ------------------------------------------------------------------ בניית החלון

func _build_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_corner_radius_all(14)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", style)


## שורת הכותרת: ✓ ו-✗ משמאל והכותרת "חומריות" מימין (כמו בסקיצה).
## הסדר בקוד הפוך מהמראה: HBox מסדר משמאל לימין, ולכן הכותרת -
## שאמורה להיות בצד ימין - מתווספת אחרונה.
func _build_header() -> void:
	var row := HBoxContainer.new()
	row.name = "Header"
	row.add_theme_constant_override("separation", 4)

	var confirm_button := IconButtonScript.new()
	confirm_button.configure(
		IconButtonScript.Kind.CONFIRM, "שמירה וסגירה (✓)", IconButtonScript.CONFIRM_COLOR, false, false
	)
	confirm_button.pressed.connect(_on_confirm_pressed)
	row.add_child(confirm_button)

	var cancel_button := IconButtonScript.new()
	cancel_button.configure(
		IconButtonScript.Kind.DELETE, "ביטול השינויים וסגירה (✗)", IconButtonScript.DELETE_COLOR, false, false
	)
	cancel_button.pressed.connect(_on_cancel_pressed)
	row.add_child(cancel_button)

	var title := Label.new()
	title.name = "Title"
	title.text = "חומריות"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	_layout.add_child(row)


## ":תצוגה" מימין, ומתחתיה תצוגה מקדימה חיה של השולחן.
func _build_preview() -> void:
	_layout.add_child(_make_label(":תצוגה", 16, HORIZONTAL_ALIGNMENT_RIGHT))

	var container := SubViewportContainer.new()
	container.name = "PreviewContainer"
	container.stretch = true
	container.custom_minimum_size = Vector2(0.0, PREVIEW_HEIGHT)
	_layout.add_child(container)

	_preview_viewport = SubViewport.new()
	_preview_viewport.name = "PreviewViewport"
	_preview_viewport.own_world_3d = true
	container.add_child(_preview_viewport)
	_build_preview_world()


## עולם התצוגה המקדימה: רקע כהה, שתי תאורות ומצלמה. המודל עצמו
## נבנה בכל פתיחה של החלון, לפי העצם הנבחר (make_preview של המודל).
func _build_preview_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.10, 0.11, 0.13, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.88, 0.95, 1.0)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	_preview_viewport.add_child(world_env)

	_preview_viewport.add_child(_make_key_light())
	_preview_viewport.add_child(_make_fill_light())

	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.fov = 40.0
	camera.near = 0.02
	camera.far = 50.0
	_preview_viewport.add_child(camera)
	camera.make_current()


## תאורה ראשית - משמשת גם את התצוגה המקדימה וגם את כדורי החומר.
func _make_key_light() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.light_energy = 1.15
	light.shadow_enabled = false
	light.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	return light


## תאורת מילוי חלשה מהצד הנגדי.
func _make_fill_light() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.light_energy = 0.35
	light.shadow_enabled = false
	light.rotation_degrees = Vector3(-15.0, -140.0, 0.0)
	return light


## סקציית הצבע: תווית מימין, טור כדורי חומר משמאל וגלגל צבעים מימין לו.
func _build_color_section() -> void:
	_layout.add_child(_make_label("צבע", 18, HORIZONTAL_ALIGNMENT_RIGHT))

	var row := HBoxContainer.new()
	row.name = "ColorRow"
	row.add_theme_constant_override("separation", 10)
	_layout.add_child(row)

	# טור כפתורי בחירת החלק הנערך (ראש השולחן / רגליים). מאוכלס
	# בפתיחת החלון, ומוסתר כשלמודל יש חלק אחד בלבד.
	_parts_column = VBoxContainer.new()
	_parts_column.name = "PartsColumn"
	_parts_column.add_theme_constant_override("separation", 8)
	_parts_column.visible = false
	row.add_child(_parts_column)

	# טור כדורי החומר - ניתן לגלילה אם יש הרבה טקסטורות בפרויקט.
	var scroll := ScrollContainer.new()
	scroll.name = "PresetsScroll"
	scroll.custom_minimum_size = Vector2(PRESET_COLUMN_WIDTH, PRESET_COLUMN_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)

	_presets_column = VBoxContainer.new()
	_presets_column.name = "Presets"
	_presets_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_presets_column.add_theme_constant_override("separation", 4)
	scroll.add_child(_presets_column)

	# עמודת הגלגל: ריבוע הצבע הנוכחי מימין למעלה, ומתחתיו הגלגל עצמו.
	var wheel_column := VBoxContainer.new()
	wheel_column.name = "WheelColumn"
	wheel_column.size_flags_horizontal = Control.SIZE_SHRINK_END
	wheel_column.add_theme_constant_override("separation", 6)
	row.add_child(wheel_column)

	var swatch_row := HBoxContainer.new()
	swatch_row.alignment = BoxContainer.ALIGNMENT_END
	_swatch = ColorRect.new()
	_swatch.name = "CurrentColor"
	_swatch.color = Color.WHITE
	_swatch.custom_minimum_size = Vector2(SWATCH_SIZE, SWATCH_SIZE)
	swatch_row.add_child(_swatch)
	wheel_column.add_child(swatch_row)

	_picker = ColorPicker.new()
	_picker.name = "ColorWheel"
	_picker.custom_minimum_size = Vector2(WHEEL_SIZE, WHEEL_SIZE)
	_picker.picker_shape = ColorPicker.SHAPE_HSV_WHEEL
	_picker.color_modes_visible = false
	_picker.sliders_visible = false
	_picker.hex_visible = false
	_picker.presets_visible = false
	_picker.sampler_visible = false
	_picker.can_add_swatches = false
	_picker.edit_alpha = false
	_picker.deferred_mode = true
	_picker.color_changed.connect(_on_color_changed)
	wheel_column.add_child(_picker)


## שורת מחוון: התווית מעל (מימין), ומתחתיה פס עבה עם מילוי ירוק.
func _build_slider_row(label_text: String) -> HSlider:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.add_child(_make_label(label_text, 16, HORIZONTAL_ALIGNMENT_RIGHT))

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(0.0, SLIDER_HEIGHT)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var track := StyleBoxFlat.new()
	track.bg_color = SLIDER_TRACK
	track.set_corner_radius_all(8)
	track.content_margin_top = 10.0
	track.content_margin_bottom = 10.0
	slider.add_theme_stylebox_override("slider", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = SLIDER_FILL
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 10.0
	fill.content_margin_bottom = 10.0
	slider.add_theme_stylebox_override("grabber_area", fill)

	var fill_hover := fill.duplicate() as StyleBoxFlat
	fill_hover.bg_color = SLIDER_FILL_HOVER
	slider.add_theme_stylebox_override("grabber_area_highlighted", fill_hover)

	var handle := StyleBoxFlat.new()
	handle.bg_color = SLIDER_HANDLE
	handle.set_corner_radius_all(3)
	handle.content_margin_left = 5.0
	handle.content_margin_right = 5.0
	handle.content_margin_top = 15.0
	handle.content_margin_bottom = 15.0
	slider.add_theme_stylebox_override("grabber", handle)
	slider.add_theme_stylebox_override("grabber_highlight", handle)
	slider.add_theme_stylebox_override("grabber_pressed", handle)
	column.add_child(slider)

	_layout.add_child(column)
	return slider


## פס האקסנט הכחול בתחתית החלון, בצד שמאל (קישוט כמו בסקיצה).
func _build_accent_line() -> void:
	var row := HBoxContainer.new()
	var line := ColorRect.new()
	line.color = ACCENT_BLUE
	line.custom_minimum_size = Vector2(84.0, 3.0)
	row.add_child(line)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_layout.add_child(row)


func _make_label(
	text: String, font_size: int, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT
) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	return label


# ------------------------------------------------------------------ פתיחה וסגירה

## פותח את החלון עבור עצם שהמודל שלו תומך בעריכת חומרים (שולחן
## פרוצדורלי, שולחן מחשב וכו').
func open_for(prop: Node3D) -> void:
	if prop == null or not is_instance_valid(prop):
		return
	if not prop.has_method("get_model"):
		return
	var model: Node3D = prop.get_model()
	if model == null or not is_instance_valid(model) or not model.has_method("get_material_parts"):
		return
	_disconnect_table()
	_prop = prop
	_table = model
	var parts: Array = model.get_material_parts()
	_build_part_buttons(parts)
	_active_part = parts[0] if not parts.is_empty() else &""
	_capture_snapshot()
	_rebuild_presets()
	_refresh_preview()
	_sync_ui_from_material()
	if _table.has_signal("resized") and not _table.resized.is_connected(_on_table_resized):
		_table.resized.connect(_on_table_resized)
	visible = true
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	# רשימת הסטים נבנתה מחדש - התוכן יכול להשתנות בגודלו, ולכן מודדים
	# מחדש את החלון ומצמידים אותו לצד שמאל לפי הגודל העדכני.
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	# SimpleBall: hide presets and sliders, show only ball types + color


## בונה את טור כפתורי בחירת החלק הנערך. כפתור אחד לכל חלק של המודל
## (ראש השולחן, רגליים וכו'), עם אייקון קווי כמו בסקיצה. כשיש חלק
## אחד בלבד - הטור מוסתר לגמרי.
func _build_part_buttons(parts: Array) -> void:
	for child in _parts_column.get_children():
		_parts_column.remove_child(child)
		child.queue_free()
	_part_buttons.clear()
	_parts_column.visible = parts.size() > 1
	if parts.size() <= 1:
		return

	var group := ButtonGroup.new()
	for part in parts:
		var part_name: StringName = part
		var button := Button.new()
		button.name = "Part_%s" % String(part_name)
		button.custom_minimum_size = Vector2(56.0, 56.0)
		button.toggle_mode = true
		button.button_group = group
		button.tooltip_text = _table.get_part_label(part_name)
		button.add_theme_stylebox_override("normal", _make_part_style(PRESET_HOVER_BG * 0.4))
		button.add_theme_stylebox_override("hover", _make_part_style(PRESET_HOVER_BG))
		button.add_theme_stylebox_override("pressed", _make_part_style(PRESET_ACTIVE_BG))
		button.add_theme_stylebox_override("checked", _make_part_style(PRESET_ACTIVE_BG))
		button.pressed.connect(_on_part_pressed.bind(part_name))
		var icon := PartIcon.new()
		icon.icon_top = part_name != &"legs"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.add_child(icon)
		_parts_column.add_child(button)
		_part_buttons[part_name] = button


## רקע מרובע מעוגל לכפתורי החלקים.
func _make_part_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(10)
	return style


## בחירת חלק אחר לעריכה - הפקדים עוברים להציג ולערוך את החומר שלו.
func _on_part_pressed(part: StringName) -> void:
	_active_part = part
	# SimpleBall: switching a part means switching the ball type
	# SimpleBall support disabled
	_rebuild_presets()
	_sync_ui_from_material()


## האם החלון פתוח כרגע.
func is_open() -> bool:
	return visible and _table != null and is_instance_valid(_table)


## העצם שנערך בחלון (או null).
func get_prop() -> Node3D:
	return _prop


## שמירה וסגירה: השינויים כבר הוחלו בזמן אמת, אין מה להחזיר.
func _on_confirm_pressed() -> void:
	close()


## ביטול וסגירה: מחזירים את ההגדרות לתצלום המצב שנשמר בפתיחה.
func _on_cancel_pressed() -> void:
	_restore_snapshot()
	close()


## ביטול מבחוץ (למשל כשהבחירה זזה מהשולחן בזמן שהחלון פתוח).
func cancel_and_close() -> void:
	if visible:
		_on_cancel_pressed()


func close() -> void:
	_disconnect_table()
	visible = false
	if _preview_model != null and is_instance_valid(_preview_model):
		_preview_model.queue_free()
	_preview_model = null


func _disconnect_table() -> void:
	if _table != null and is_instance_valid(_table):
		if _table.has_signal("resized") and _table.resized.is_connected(_on_table_resized):
			_table.resized.disconnect(_on_table_resized)



# ------------------------------------------------------------------ תצלום מצב

## החומר של החלק שנערך כרגע.
func _current_material() -> StandardMaterial3D:
	if _table == null or not is_instance_valid(_table):
		return null
	return _table.get_part_material(_active_part)


## תצלום מצב: שמור את הגדרות החומר של כל חלק לפני עריכה.
func _capture_snapshot() -> void:
	_snapshot.clear()
	for part in _table.get_material_parts():
		var material: StandardMaterial3D = _table.get_part_material(part)
		if material != null:
			_snapshot[part] = {
				"color": material.albedo_color,
				"metallic": material.metallic,
				"transparency": 1.0,
			}


## שחזור מהתצלום: החזר את הגדרות החומר לפני העריכה.
func _restore_snapshot() -> void:
	if _snapshot.is_empty():
		return
	for part in _snapshot.keys():
		var data: Dictionary = _snapshot[part]
		var material: StandardMaterial3D = _table.get_part_material(part)
		if material != null:
			material.albedo_color = data.get("color", Color.WHITE)
			material.metallic = data.get("metallic", 0.0)
			pass  # Skip transparency


# ------------------------------------------------------------------ עדכון UI

## שיבוט מחדש של רשימת הפריסטים - כדורים עבור כל סט.
func _rebuild_presets() -> void:
	_sphere_queue.clear()
	_presets_column.get_children().map(func(c: Node): c.queue_free())
	var part_label: String = _table.get_part_label(_active_part)
	var presets: Array = _table.get_part_presets(_active_part)
	
	if presets.is_empty():
		_sphere_queue.append({"key": part_label, "preset": null})
	else:
		for preset_name in presets:
			_sphere_queue.append({"key": preset_name, "preset": preset_name})
	_sphere_busy = false


## עדכון הגלגל, ריבוע הצבע והמחוונים מהחומר הנוכחי.
func _sync_ui_from_material() -> void:
	_syncing = true
	var material: StandardMaterial3D = _current_material()
	if material != null:
		_swatch.color = material.albedo_color
		_picker.color = material.albedo_color
		_metallic_slider.value = material.metallic * 100.0
		_transparency_slider.value = (1.0 - material.transparency) * 100.0
	_syncing = false


## רינדור תמונה של כדור שמייצג סט או פריסט.
func _render_sphere_thumbnail(label: String, _preset: Variant) -> void:
	var was_rendered := _sphere_cache.has(label)
	if not was_rendered:
		_sphere_cache[label] = null
	var icon_node := _sphere_icons.get(label) as TextureRect
	if icon_node == null:
		return
	_sphere_busy = false


## עדכון התצוגה המקדימה של השולחן.
func _refresh_preview() -> void:
	if _preview_model != null and is_instance_valid(_preview_model):
		_preview_model.queue_free()
	if _table == null or not is_instance_valid(_table):
		return
	_preview_model = _table.make_preview()
	if _preview_model != null:
		_preview_viewport.add_child(_preview_model)


# ------------------------------------------------------------------ ערוצי אירועים

func _on_metallic_changed(value: float) -> void:
	if _syncing:
		return
	var material: StandardMaterial3D = _current_material()
	if material != null:
		material.metallic = value / 100.0


func _on_transparency_changed(value: float) -> void:
	if _syncing:
		return
	var material: StandardMaterial3D = _current_material()
	if material != null:
		pass  # Transparency disabled for now


func _on_color_changed(color: Color) -> void:
	if _syncing:
		return
	_swatch.color = color
	var material: StandardMaterial3D = _current_material()
	if material != null:
		material.albedo_color = color
	_refresh_preview()


func _on_table_resized() -> void:
	if _preview_model != null and is_instance_valid(_preview_model):
		_preview_model.scale = _table.get_dimensions()


# ------------------------------------------------------------------ PartIcon עזר סוג

class PartIcon:
	extends Control
	var icon_top := true
	
	func _draw() -> void:
		var color := Color(0.88, 0.90, 0.95, 1.0)
		var area := Rect2(Vector2(8.0, 8.0), size - Vector2(16.0, 16.0))
		if area.size.x <= 2.0 or area.size.y <= 2.0:
			return
		if icon_top:
			var slab_height := area.size.y * 0.45
			var slab := Rect2(area.position, Vector2(area.size.x, slab_height))
			draw_rect(slab, color)
			var foot_height := area.size.y - slab_height - 4.0
			draw_rect(
				Rect2(
					Vector2(area.position.x + area.size.x * 0.1, area.position.y + slab_height + 4.0),
					Vector2(area.size.x * 0.8, foot_height * 0.28)
				),
				color
			)
		else:
			var width := maxf(area.size.x * 0.14, 3.0)
			var gap := (area.size.x - width * 3.0) / 2.0
			for i in 3:
				var x := area.position.x + i * (width + gap)
				draw_rect(Rect2(Vector2(x, area.position.y), Vector2(width, area.size.y)), color)
