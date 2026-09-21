class_name AssetBank
extends PanelContainer
## בנק האסטים: חלון הבחירה של הילדים.
##
## מציג קטגוריות, כרטיס לכל אסט עם תמונה ממוזערת, ותצוגה מקדימה תלת-ממדית
## מסתובבת של האסט הנבחר. כדי להציב אסט בעולם - גוררים את הכרטיס שלו
## אל תוך שטח התלת-ממד.
##
## התמונות הממוזערות נוצרות אוטומטית מהמודל ונשמרות ב-assets/models/thumbs,
## כדי שבפעם הבאה הן נטענות מיד.

const LibraryScript := preload("res://scripts/core/asset_library.gd")
const ModelBoundsScript := preload("res://scripts/core/model_bounds.gd")
const AssetCardScript := preload("res://scripts/ui/asset_card.gd")

## תיקיית התמונות הממוזערות (נשמרות גם לדיסק).
const THUMB_DIR := "res://assets/models/thumbs"
const THUMB_SIZE := 256
## גודל כרטיס אסט - מותאם לשלושה כרטיסים בשורה בתוך הבנק.
const CARD_SIZE := Vector2(98, 122)
## גובה התמונה הממוזערת בתוך הכרטיס.
const CARD_THUMB_HEIGHT := 74
## כמה מהר האסט הנבחר מסתובב בתצוגה המקדימה (מעלות לשנייה).
const PREVIEW_SPIN := 22.0

## נשלח כשהמשתמש בוחר אסט בבנק (לוחץ על הכרטיס שלו).
signal asset_selected(def: Resource)

@onready var _categories_box: HFlowContainer = $Layout/CategoriesBox
@onready var _preview_viewport: SubViewport = $Layout/PreviewContainer/PreviewViewport
@onready var _card_grid: GridContainer = $Layout/ScrollArea/CardGrid
@onready var _status_label: Label = $Layout/StatusLabel

var _library: LibraryScript = null
var _selected_def: Resource = null
var _card_group := ButtonGroup.new()
## תווית התצוגה של כל קטגוריה (נקבעת פעם אחת בבנייה).
var _category_labels: Dictionary = {}
var _preview_pivot: Node3D = null
var _preview_camera: Camera3D = null
var _thumb_queue: Array[Dictionary] = []
var _thumb_busy := false


func _ready() -> void:
	_preview_viewport.own_world_3d = true
	_build_preview_world()


func _process(delta: float) -> void:
	if _preview_pivot != null and _preview_pivot.get_child_count() > 0:
		_preview_pivot.rotation.y += deg_to_rad(PREVIEW_SPIN) * delta

	if not _thumb_busy and not _thumb_queue.is_empty():
		_thumb_busy = true
		var job: Dictionary = _thumb_queue.pop_front()
		_generate_thumbnail(job["def"], job["rect"])


## מחבר את הבנק לספרייה ובונה את התצוגה. נקרא מהשורש של הסטודיו.
func setup(library: LibraryScript) -> void:
	_library = library
	_build_categories()
	var categories := _library.get_categories()
	if categories.is_empty():
		_status_label.text = "לא נמצאו אסטים"
		return
	_show_category(categories[0])
	_status_label.text = "%d אסטים בבנק - גררו כרטיס אל העולם" % _library.get_all_assets().size()


## האסט שנבחר כרגע בבנק (או null).
func get_selected_asset() -> Resource:
	return _selected_def


func _build_categories() -> void:
	for child in _categories_box.get_children():
		_categories_box.remove_child(child)
		child.queue_free()

	var categories := _library.get_categories()
	# אם לקטגוריה של המשתמש יש אותה תווית בעברית כמו קטגוריה מובנית
	# (למשל תיקיית "Furnatures" מול "רהיטים" המובנית) - מוסיפים "שלי".
	var used_labels: Array[String] = []
	for category in categories:
		var label := _library.get_category_label(category)
		if used_labels.has(label):
			label += " שלי"
		used_labels.append(label)
		_category_labels[category] = label

		var button := Button.new()
		button.text = label
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 34)
		button.set_meta("category", category)
		button.pressed.connect(_on_category_pressed.bind(category))
		_categories_box.add_child(button)

	_refresh_category_chips()


func _refresh_category_chips() -> void:
	for chip in _categories_box.get_children():
		var button := chip as Button
		if button != null:
			button.button_pressed = StringName(button.get_meta("category")) == _current_category_id


var _current_category_id: StringName = &""


func _show_category(category: StringName) -> void:
	_current_category_id = category
	_refresh_category_chips()

	for child in _card_grid.get_children():
		_card_grid.remove_child(child)
		child.queue_free()

	var assets := _library.get_assets_in_category(category)
	for def in assets:
		_card_grid.add_child(_make_card(def))

	# בחירה ראשונה אוטומטית, כדי שהתצוגה המקדימה לא תישאר ריקה
	if not assets.is_empty():
		_select_asset(assets[0])


func _make_card(def: Resource) -> Button:
	var card: Button = AssetCardScript.new()
	card.custom_minimum_size = CARD_SIZE
	card.toggle_mode = true
	card.button_group = _card_group
	card.clip_text = true
	card.tooltip_text = def.display_name
	card.asset_id = def.id

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 8.0
	layout.offset_top = 8.0
	layout.offset_right = -8.0
	layout.offset_bottom = -8.0
	layout.add_theme_constant_override("separation", 4)
	card.add_child(layout)

	var thumbnail := TextureRect.new()
	thumbnail.name = "Thumbnail"
	thumbnail.custom_minimum_size = Vector2(0, CARD_THUMB_HEIGHT)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(thumbnail)

	var name_label := Label.new()
	name_label.name = "AssetName"
	name_label.text = def.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 12)
	layout.add_child(name_label)

	card.thumb_rect = thumbnail
	card.pressed.connect(_select_asset.bind(def))
	_request_thumbnail(def, thumbnail)
	return card


func _select_asset(def: Resource) -> void:
	_selected_def = def
	_update_preview()
	asset_selected.emit(def)


func _on_category_pressed(category: StringName) -> void:
	_show_category(category)


# ---------------------------------------------------------------- תצוגה מקדימה

func _build_preview_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.13, 0.14, 0.16, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.88, 0.95, 1.0)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	_preview_viewport.add_child(world_env)

	_preview_viewport.add_child(_make_key_light())
	_preview_viewport.add_child(_make_fill_light())

	_preview_pivot = Node3D.new()
	_preview_pivot.name = "PreviewPivot"
	_preview_viewport.add_child(_preview_pivot)

	_preview_camera = Camera3D.new()
	_preview_camera.name = "PreviewCamera"
	_preview_camera.fov = 42.0
	_preview_camera.near = 0.02
	_preview_camera.far = 200.0
	_preview_viewport.add_child(_preview_camera)
	_preview_camera.make_current()


func _make_key_light() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.light_energy = 1.15
	light.shadow_enabled = false
	light.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	return light


func _make_fill_light() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.light_energy = 0.35
	light.shadow_enabled = false
	light.rotation_degrees = Vector3(-15.0, -140.0, 0.0)
	return light


func _update_preview() -> void:
	for child in _preview_pivot.get_children():
		_preview_pivot.remove_child(child)
		child.queue_free()
	_preview_pivot.rotation = Vector3.ZERO

	if _selected_def == null:
		return

	var instance := _library.instantiate_def(_selected_def)
	if instance == null:
		return
	_preview_pivot.add_child(instance)
	frame_camera_on(_preview_camera, _bounds_of(instance))


## התיבה התוחמת של אסט. מודל עם shape keys (כמו הכדורים) מספק את
## הגיאומטריה הבסיסית, כדי שהמיסגור לא יהיה מנופח.
static func _bounds_of(node: Node3D) -> AABB:
	if node != null and node.has_method("get_base_bounds"):
		return node.get_base_bounds()
	return ModelBoundsScript.combined_aabb(node)


## ממקם את המצלמה כך שכל מה שבתוך התיבה התוחמת ייכנס לפריים.
static func frame_camera_on(camera: Camera3D, bounds: AABB) -> void:
	if bounds.size == Vector3.ZERO:
		return
	var center := bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 0.05)
	var distance := radius / tan(deg_to_rad(camera.fov * 0.5)) * 1.35
	camera.position = center + Vector3(1.0, 0.55, 1.45).normalized() * distance
	camera.look_at(center, Vector3.UP)


# ---------------------------------------------------------------- תמונות ממוזערות

func _request_thumbnail(def: Resource, target: TextureRect) -> void:
	var path := THUMB_DIR.path_join(String(def.id) + ".png")
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			target.texture = texture
			return
	_thumb_queue.append({"def": def, "rect": target})


## מצייר את האסט ב-SubViewport נסתר, שומר PNG ומעדכן את הכרטיס.
## פועל פעם אחת לכל אסט - בהמשך הדורות זה נטען מהקובץ.
func _generate_thumbnail(def: Resource, target: TextureRect) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(THUMB_SIZE, THUMB_SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)

	var environment := Environment.new()
	# רקע שקוף: התמונה הממוזערת נשמרת עם ערוץ אלפא, כדי שהכרטיס ייראה נקי
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.88, 0.95, 1.0)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	viewport.add_child(world_env)
	viewport.add_child(_make_key_light())
	viewport.add_child(_make_fill_light())

	var instance := _library.instantiate_def(def)
	if instance == null:
		viewport.queue_free()
		_thumb_busy = false
		return
	viewport.add_child(instance)

	var camera := Camera3D.new()
	camera.fov = 42.0
	viewport.add_child(camera)
	camera.make_current()
	frame_camera_on(camera, _bounds_of(instance))

	# ממתינים שהרינדור יסתיים ואז לוקחים את התמונה
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()

	if is_instance_valid(target) and target.is_inside_tree():
		target.texture = ImageTexture.create_from_image(image)

	if not image.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(THUMB_DIR))
		var error := image.save_png(ProjectSettings.globalize_path(THUMB_DIR.path_join(String(def.id) + ".png")))
		if error != OK:
			push_warning("לא ניתן לשמור תמונה ממוזערת עבור " + String(def.id))

	viewport.queue_free()
	_thumb_busy = false
