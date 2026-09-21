class_name TestSelection
extends Node
## בדיקות למנוע הבחירה: כל בחירה מכניסה את העצם למצב רפאים,
## וביטול בחירה (או מעבר לעצם אחר) מניח אותו בחזרה על הרצפה.

const SelectionScript := preload("res://scripts/core/selection.gd")
const GizmoScript := preload("res://scripts/core/move_gizmo.gd")
const PropScript := preload("res://scripts/core/prop.gd")
const LibraryScript := preload("res://scripts/core/asset_library.gd")
const PlacementScript := preload("res://scripts/core/placement.gd")


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


func _make_selection(root: Node3D, gizmo: GizmoScript) -> StudioSelection:
	var selection: StudioSelection = SelectionScript.new()
	add_child(selection)
	selection.setup(null, null, root, gizmo, null)
	return selection


func test_select_marks_prop_with_outline() -> void:
	var root := Node3D.new()
	add_child(root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)
	var selection := _make_selection(root, gizmo)

	var prop := _make_prop(root, "marked")
	selection.select(prop)
	assert(selection.get_selected() == prop, "The prop must be selected")
	assert(prop.is_selected(), "The prop must be marked as selected")
	assert(prop.is_outlined(), "A selected prop must show the yellow outline")

	selection.select(null)
	assert(not prop.is_selected(), "Deselecting must clear the selection mark")
	assert(not prop.is_outlined(), "Deselecting must remove the outline")

	root.free()


func test_selecting_another_prop_clears_previous() -> void:
	var root := Node3D.new()
	add_child(root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)
	var selection := _make_selection(root, gizmo)

	var first := _make_prop(root, "first")
	var second := _make_prop(root, "second")
	selection.select(first)
	assert(first.is_outlined(), "The first prop must be outlined")
	selection.select(second)
	assert(not first.is_outlined(), "The previous prop must lose its outline")
	assert(second.is_outlined(), "The new prop must be outlined")
	assert(selection.get_selected() == second, "Selection must move to the new prop")

	root.free()


func test_cancel_edits_restores_everything() -> void:
	var root := Node3D.new()
	add_child(root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)
	var selection := _make_selection(root, gizmo)

	var prop := _make_prop(root, "cancel_test")
	selection.select(prop)
	var original := prop.global_transform

	# "עריכה": הזזה וסיבוב.
	prop.global_position = Vector3(4.0, 0.0, 4.0)
	prop.rotate_y(0.7)
	assert(not prop.global_transform.is_equal_approx(original), "Sanity: the prop must actually be edited")

	selection.cancel_edits()

	assert(prop.global_transform.is_equal_approx(original), "Edits must revert to the pre-selection transform")
	assert(selection.get_selected() == null, "Cancel must exit edit mode")
	assert(not prop.is_selected(), "The prop must be deselected")
	assert(not prop.is_outlined(), "The prop must lose its outline")

	root.free()


func test_duplicate_copies_current_transform() -> void:
	var root := Node3D.new()
	add_child(root)

	var library = LibraryScript.new()
	var placement = PlacementScript.new()
	root.add_child(placement)
	placement.setup(library, null, root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)

	var selection: StudioSelection = SelectionScript.new()
	add_child(selection)
	selection.setup(null, null, root, gizmo, placement)

	var assets: Array = library.get_all_assets()
	assert(not assets.is_empty(), "The asset library must contain at least one asset")
	var asset_id: StringName = assets[0].id

	var prop := _make_prop(root, String(asset_id))
	selection.select(prop)

	# "עריכה": הזזה וסיבוב של 90 מעלות - ואז שכפול.
	prop.global_position = Vector3(3.0, 0.0, 1.0)
	prop.rotate_y(PI * 0.5)
	var expected_basis := prop.global_basis
	var expected_position := prop.global_position + StudioSelection.DUPLICATE_OFFSET

	selection.duplicate_selected()

	var copy := selection.get_selected()
	assert(copy != null and copy != prop, "A copy must be created and selected")
	assert(
		copy.global_basis.is_equal_approx(expected_basis),
		"The copy must keep the source's rotation and dimensions at the moment of duplication"
	)
	assert(
		copy.global_position.is_equal_approx(expected_position),
		"The copy must be placed next to the source"
	)

	root.free()


func test_cancel_edits_stops_active_drag() -> void:
	var root := Node3D.new()
	add_child(root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)
	var selection := _make_selection(root, gizmo)

	var prop := _make_prop(root, "drag_cancel")
	selection.select(prop)
	var original := prop.global_transform

	# מדמה גרירת גיזמו באמצע: ידית פעילה והעצם כבר זז.
	gizmo._active = GizmoScript.Handle.AXIS_X
	gizmo._start_transforms.clear()
	gizmo._start_transforms.append(original)
	prop.global_position = Vector3(7.0, 0.0, 0.0)

	selection.cancel_edits()

	assert(prop.global_transform.is_equal_approx(original), "Everything must revert, including an in-progress drag")
	assert(not gizmo.is_dragging(), "The gizmo drag must be stopped")
	assert(selection.get_selected() == null, "Cancel must exit edit mode")

	root.free()
