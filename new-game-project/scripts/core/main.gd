class_name StudioMain
extends Node3D
## השורש של הסטודיו.
##
## כאן תלויים המנועים השונים, כל אחד בשלב שלו:
##   מנוע ההצבה (placement) - גרירת כרטיס מהבנק אל תוך העולם
##   מנוע הבחירה (selection) - בחירת עצם בודד או קבוצה והזזתם בגיזמו
##   בקרות העצם (object_controls) - אייקוני עריכה משני צידי העצם הנבחר
##   חלונות הצד - בנק האסטים וההסבר, נפתחים מכפתורים קטנים בפינות
##   מנוע התאורה (lighting) - שלב מאוחר יותר
##   ציר הזמן ולכידת הפריימים (timeline) - שלב מאוחר יותר
##   שמירה/טעינה (project_io) - שלב מאוחר יותר

const CameraRigScript := preload("res://scripts/core/camera_rig.gd")
const LibraryScript := preload("res://scripts/core/asset_library.gd")
const AssetBankScript := preload("res://scripts/ui/asset_bank.gd")
const PlacementScript := preload("res://scripts/core/placement.gd")
const SelectionScript := preload("res://scripts/core/selection.gd")
const GizmoScript := preload("res://scripts/core/move_gizmo.gd")
const DropAreaScript := preload("res://scripts/ui/world_drop_area.gd")
const ObjectControlsScript := preload("res://scripts/ui/object_controls.gd")
const SidePanelButtonScript := preload("res://scripts/ui/side_panel_button.gd")
const MaterialPanelScript := preload("res://scripts/ui/material_panel.gd")

## כל האובייקטים שהמשתמש הציב יושבים תחת הצומת הזה.
@onready var props_root: Node3D = $World/Props
## כל גופי התאורה שהמשתמש הציב יושבים תחת הצומת הזה.
@onready var lights_root: Node3D = $World/Lights
## שורש העולם - כל ההצמדות לגריד מחושבות ממנו.
@onready var build_root: Node3D = $World
@onready var camera_rig: CameraRigScript = $CameraRig
@onready var asset_bank: AssetBankScript = $UI/AssetBank
@onready var drop_area: DropAreaScript = $UI/WorldDropArea
@onready var placement: PlacementScript = $Placement
@onready var selection: SelectionScript = $Selection
@onready var move_gizmo: GizmoScript = $MoveGizmo
@onready var status_label: Label = $UI/StatusLabel
@onready var object_controls: ObjectControlsScript = $UI/ObjectControls
@onready var selection_box: SelectionBox = $UI/SelectionBox
@onready var help_panel: PanelContainer = $UI/HelpPanel
@onready var bank_button: SidePanelButtonScript = $UI/BankButton
@onready var help_button: SidePanelButtonScript = $UI/HelpButton
@onready var world_button: SidePanelButtonScript = $UI/WorldButton
@onready var camera_button: SidePanelButtonScript = $UI/CameraButton
@onready var timeline_button: SidePanelButtonScript = $UI/TimelineButton
@onready var material_panel: MaterialPanelScript = $UI/MaterialPanel

## בנק האסטים של הפרויקט.
var library: LibraryScript = null


func _ready() -> void:
	library = LibraryScript.new()
	asset_bank.setup(library)
	placement.setup(library, camera_rig.camera, props_root)
	selection.setup(camera_rig.camera, camera_rig, props_root, move_gizmo, placement)
	selection.set_box(selection_box)
	selection.selection_changed.connect(_on_selection_changed)
	# גרירה מהבנק: כל תזוזה מזיזה את אובייקט הרפאים על הרצפה.
	drop_area.drag_moved.connect(placement.show_ghost_at)
	drop_area.asset_dropped.connect(_on_asset_dropped)
	drop_area.drag_cancelled.connect(placement.cancel_drag)
	# אייקוני העריכה של העצם הנבחר - משני צדדיו.
	object_controls.setup(move_gizmo, camera_rig.camera, selection)
	object_controls.confirmed.connect(_on_toolbar_confirm)
	object_controls.duplicate_requested.connect(_on_toolbar_duplicate)
	object_controls.delete_requested.connect(_on_toolbar_delete)
	object_controls.materials_requested.connect(_on_materials_requested)
	move_gizmo.mode_changed.connect(_on_gizmo_mode_changed)
	# חלונות הצד סגורים בהתחלה - נפתחים מהכפתורים שבפינות.
	help_panel.visible = false
	asset_bank.visible = false
	material_panel.visible = false
	bank_button.pressed.connect(_on_bank_button)
	help_button.pressed.connect(_on_help_button)
	# כפתורי הפינות החדשים: בחירת עולם, מצב מצלמה וציר הזמן. הפיצ'רים
	# עצמם ייבנו בהמשך - בינתיים הכפתורים רק מסבירים מה יקרה.
	world_button.pressed.connect(_on_world_button)
	camera_button.pressed.connect(_on_camera_button)
	timeline_button.pressed.connect(_on_timeline_button)
	_on_selection_changed([])


## כפתור הכיסא - פותח או סוגר את בנק האסטים.
func _on_bank_button() -> void:
	_toggle_panel(asset_bank)


## כפתור סימן השאלה - פותח או סוגר את חלון ההסבר.
func _on_help_button() -> void:
	_toggle_panel(help_panel)


## כפתור בחירת העולם (שמאל למעלה) - הפיצ'ר ייבנה בהמשך.
func _on_world_button() -> void:
	status_label.text = "בחירת עולם תיפתח בהמשך - בינתיים בונים בעולם הזה"


## כפתור מצב המצלמה (ימין למטה) - הפיצ'ר ייבנה בהמשך.
func _on_camera_button() -> void:
	status_label.text = "מצב מצלמה ייפתח בהמשך - בינתיים המצלמה נשלטת בעכבר ובמקלדת"


## כפתור ציר הזמן (ימין למטה) - בינתיים רק מחליף סמליל (סגור / פתוח).
func _on_timeline_button() -> void:
	var open := not timeline_button.is_timeline_open()
	timeline_button.set_timeline_open(open)
	if open:
		status_label.text = "ציר הזמן ייפתח כאן בהמשך"
	else:
		status_label.text = "ציר הזמן סגור"


## מציג או מסתיר חלון צד, עם הופעה חלקה קצרה.
func _toggle_panel(panel: Control) -> void:
	if panel.visible:
		panel.visible = false
		return
	panel.visible = true
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(panel, "modulate", Color.WHITE, 0.15)


## המשתמש שחרר כרטיס מהבנק מעל העולם - העצם נוצר במקום העכבר ונבחר מיד,
## כך שהוא מסומן במתאר צהוב ומוכן להזזה.
func _on_asset_dropped(asset_id: StringName, screen_position: Vector2) -> void:
	var prop := placement.finish_drop(asset_id, screen_position)
	if prop == null:
		return
	selection.select(prop)


## הנח - מניח את העצם במקום ומסיים את הבחירה.
func _on_toolbar_confirm() -> void:
	selection.select(null)


## שכפול - יוצר עותק מוצק של העצם הנבחר.
func _on_toolbar_duplicate() -> void:
	selection.duplicate_selected()


## מחיקה - מוחק את העצם הנבחר.
func _on_toolbar_delete() -> void:
	selection.delete_selected()


## ארגז הכלים - פותח את חלון החומריות של העצם הנבחר (כרגע: שולחנות).
func _on_materials_requested() -> void:
	var prop := selection.get_selected()
	if prop == null:
		return
	if not prop.has_method("get_model"):
		return
	var model: Node3D = prop.get_model()
	if model == null or not is_instance_valid(model) or not model.has_method("get_material_parts"):
		status_label.text = "עיצוב חומרים זמין לשולחנות - בחרו שולחן"
		return
	material_panel.open_for(prop)


## מה שכתוב למטה על המסך - מה נבחר ומה אפשר לעשות איתו.
func _on_selection_changed(items: Array) -> void:
	# חלון החומריות נסגר עם ביטול אם השולחן שנערך כבר לא נבחר.
	if material_panel != null and material_panel.is_open():
		if not items.has(material_panel.get_prop()):
			material_panel.cancel_and_close()
	if items.is_empty():
		status_label.text = "גררו כרטיס מהבנק אל העולם כדי להציב עצם. Shift + קליק או גרירה לבחירת כמה עצמים"
		return
	var mode_text := "חצים להזזה"
	var snap_text := "Shift להצמדה לרשת (0.5 מ')"
	if move_gizmo.get_mode() == GizmoScript.GizmoMode.ROTATE:
		mode_text = "טבעות לסיבוב"
		snap_text = "Shift לסיבוב ב-15 מעלות"
	elif move_gizmo.get_mode() == GizmoScript.GizmoMode.SCALE:
		mode_text = "גרירת הנדל משנה גודל"
		snap_text = "Shift מצמד לרבע מטר"
	if items.size() > 1:
		status_label.text = "נבחרו %d עצמים - %s, %s, קליק ימני לביטול" % [items.size(), mode_text, snap_text]
		return
	var prop: Node3D = items[0]
	status_label.text = "נבחר: %s  -  %s, %s, Shift + קליק לבחירת עוד עצמים" % [prop.display_name, mode_text, snap_text]


func _on_gizmo_mode_changed(_new_mode: int) -> void:
	if selection != null and selection.selection_count() > 0:
		_on_selection_changed(selection.get_selection())
