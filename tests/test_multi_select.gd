class_name TestMultiSelect
extends Node
## בדיקות לבחירה מרובה: Shift + קליק, מלבן בחירה, וגיזמו משותף אחד
## שמזיז ומסובב את כל העצמים הנבחרים יחד.

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


## בונה עולם קטן לבדיקה: שורש, מצלמה, גיזמו ומנוע בחירה.
func _make_world() -> Dictionary:
	var root := Node3D.new()
	add_child(root)

	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0.0, 6.0, 10.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)

	var selection: StudioSelection = SelectionScript.new()
	add_child(selection)
	selection.setup(camera, null, root, gizmo, null)

	return {"root": root, "camera": camera, "gizmo": gizmo, "selection": selection}


func test_shift_click_adds_and_removes() -> void:
	var world := _make_world()
	var root: Node3D = world["root"]
	var selection: StudioSelection = world["selection"]

	var first := _make_prop(root, "multi_a")
	var second := _make_prop(root, "multi_b")

	selection.select(first)
	assert(selection.selection_count() == 1, "Starts with a single selection")

	selection.toggle_in_selection(second)
	assert(selection.selection_count() == 2, "Shift+click must add the second object")
	assert(first.is_outlined() and second.is_outlined(), "Both selected objects must show the outline")

	selection.toggle_in_selection(first)
	assert(selection.selection_count() == 1, "Shift+click again must remove it")
	assert(not first.is_outlined(), "The removed object must lose its outline")
	assert(selection.get_selected() == second, "The remaining object stays selected")

	root.free()


func test_box_select_takes_only_props_inside() -> void:
	var world := _make_world()
	var root: Node3D = world["root"]
	var camera: Camera3D = world["camera"]
	var selection: StudioSelection = world["selection"]

	var left := _make_prop(root, "box_a")
	left.global_position = Vector3(-1.0, 0.0, 0.0)
	var right := _make_prop(root, "box_b")
	right.global_position = Vector3(1.0, 0.0, 0.0)
	var far := _make_prop(root, "box_far")
	far.global_position = Vector3(12.0, 0.0, 12.0)

	# מלבן סביב שני העצים הקרובים בלבד.
	var screen_left := camera.unproject_position(left.get_center())
	var screen_right := camera.unproject_position(right.get_center())
	var top_left := screen_left.min(screen_right) - Vector2(40.0, 40.0)
	var bottom_right := screen_left.max(screen_right) + Vector2(40.0, 40.0)
	selection._begin_box(top_left)
	selection._finish_box(bottom_right)

	var picked := selection.get_selection()
	assert(picked.has(left), "An object inside the box must join the selection")
	assert(picked.has(right), "Both objects inside the box must join the selection")
	assert(not picked.has(far), "An object outside the box must not be selected")
	assert(left.is_outlined(), "Box-selected objects get the outline")

	root.free()


func test_group_drag_moves_all_by_same_delta() -> void:
	var world := _make_world()
	var root: Node3D = world["root"]
	var camera: Camera3D = world["camera"]
	var gizmo: GizmoScript = world["gizmo"]
	var selection: StudioSelection = world["selection"]

	var first := _make_prop(root, "group_a")
	first.global_position = Vector3(0.0, 0.0, 0.0)
	var second := _make_prop(root, "group_b")
	second.global_position = Vector3(2.0, 0.0, 0.0)

	selection.set_selection([first, second])

	var start_screen := Vector2(800.0, 450.0)
	gizmo._begin_drag(
		GizmoScript.Handle.AXIS_X,
		camera.project_ray_origin(start_screen),
		camera.project_ray_normal(start_screen),
		first.global_position
	)
	var before_first := first.global_position
	var before_second := second.global_position

	gizmo.drag_to(Vector2(900.0, 450.0))

	var move_first := first.global_position - before_first
	var move_second := second.global_position - before_second
	assert(not move_first.is_zero_approx(), "The group must actually move")
	assert(
		move_first.is_equal_approx(move_second),
		"Every selected object must move by the exactly same delta"
	)

	root.free()


func test_group_rotation_uses_shared_pivot() -> void:
	var world := _make_world()
	var root: Node3D = world["root"]
	var gizmo: GizmoScript = world["gizmo"]
	var selection: StudioSelection = world["selection"]

	var first := _make_prop(root, "rot_a")
	first.global_position = Vector3(0.0, 0.0, 0.0)
	var second := _make_prop(root, "rot_b")
	second.global_position = Vector3(2.0, 0.0, 0.0)

	selection.set_selection([first, second])

	var pivot := (first.get_center() + second.get_center()) * 0.5
	var before_rel_first := first.global_position - pivot
	var before_rel_second := second.global_position - pivot

	gizmo._begin_ring_drag(GizmoScript.Handle.ROTATE_Y, pivot + Vector3(1.3, 0.0, 0.0))
	var ray_origin := pivot + Vector3(0.0, 10.0, 0.0)
	var target := pivot + Vector3(0.0, 0.0, -1.3)
	gizmo._rotate_drag(ray_origin, (target - ray_origin).normalized())

	var rel_first := first.global_position - pivot
	var rel_second := second.global_position - pivot
	assert(
		not rel_first.is_equal_approx(before_rel_first),
		"The objects must turn around the shared pivot"
	)
	assert(
		rel_first.is_equal_approx(-rel_second),
		"Both objects must stay opposite each other around the shared pivot"
	)

	root.free()
