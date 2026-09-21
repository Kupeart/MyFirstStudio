class_name TestModeToggle
extends Node
## בדיקות לבקרות העצם הנבחר (object_controls): האייקונים מופיעים משני
## צידי העצם ורק כשיש בחירה, ולחיצה על כפתור מצב מחליפה את מצב הגיזמו -
## כולל מצב קנה המידה החדש.

const ControlsScript := preload("res://scripts/ui/object_controls.gd")
const SelectionScript := preload("res://scripts/core/selection.gd")
const GizmoScript := preload("res://scripts/core/move_gizmo.gd")
const PropScript := preload("res://scripts/core/prop.gd")


func _make_prop(parent: Node3D, id_hint: String) -> Prop:
	var model := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	mesh.mesh = box
	model.add_child(mesh)
	var prop: Prop = PropScript.new()
	parent.add_child(prop)
	prop.setup(StringName(id_hint), "בדיקה", model)
	return prop


func test_controls_follow_selection() -> void:
	var controls = ControlsScript.new()

	var root := Node3D.new()
	add_child(root)

	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0.0, 3.0, 6.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)

	var selection: StudioSelection = SelectionScript.new()
	add_child(selection)
	selection.setup(camera, null, root, gizmo, null)

	add_child(controls)
	controls.setup(gizmo, camera, selection)

	controls._process(0.0)
	assert(not controls.visible, "Controls must be hidden when nothing is selected")

	var prop := _make_prop(root, "toggled")
	selection.select(prop)
	controls._process(0.0)
	assert(controls.visible, "Controls must be visible when a prop is selected")

	# עמודת האייקונים מימין לאובייקט, וארגז הכלים משמאלו.
	var screen_center := camera.unproject_position(prop.get_center())
	assert(
		controls._right_box.position.x > screen_center.x,
		"The icon column must be placed to the right of the selected object"
	)
	assert(
		controls._toolbox.position.x < screen_center.x,
		"The toolbox must be placed to the left of the selected object"
	)

	selection.select(null)
	controls._process(0.0)
	assert(not controls.visible, "Controls must hide again after deselecting")

	root.free()


func test_controls_switch_gizmo_mode() -> void:
	var root := Node3D.new()
	add_child(root)

	var camera := Camera3D.new()
	root.add_child(camera)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)

	var selection: StudioSelection = SelectionScript.new()
	add_child(selection)
	selection.setup(camera, null, root, gizmo, null)

	var controls = ControlsScript.new()
	add_child(controls)
	controls.setup(gizmo, camera, selection)

	assert(int(gizmo.get_mode()) == int(GizmoScript.GizmoMode.TRANSLATE), "Starts in TRANSLATE")
	controls._on_mode_pressed(int(GizmoScript.GizmoMode.ROTATE))
	assert(int(gizmo.get_mode()) == int(GizmoScript.GizmoMode.ROTATE), "Clicking rotate switches mode")
	controls._on_mode_pressed(int(GizmoScript.GizmoMode.SCALE))
	assert(
		int(gizmo.get_mode()) == int(GizmoScript.GizmoMode.SCALE),
		"Clicking scale must switch to the new scale mode"
	)
	controls._on_mode_pressed(int(GizmoScript.GizmoMode.TRANSLATE))
	assert(int(gizmo.get_mode()) == int(GizmoScript.GizmoMode.TRANSLATE), "Clicking move switches back")

	root.free()
