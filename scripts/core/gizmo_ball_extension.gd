class_name GizmoBallExtension
extends RefCounted
## Extension to move_gizmo.gd to support SimpleBall-specific handles: HEIGHT and SQUASH_STRETCH
## This is called from move_gizmo's _build_scale() and drag_to() methods

# Handle types for balls (these would be added to move_gizmo.Handle enum)
enum BallHandle {
	HEIGHT = 200,      # Yellow arrow pointing up
	SQUASH_STRETCH = 201,  # Red arrow horizontal (squash/stretch)
}

## Check if a target is SimpleBall
static func is_simple_ball(target: Node3D) -> bool:
	if target == null:
		return false
	return target.get_script() and target.get_script().get_class_name() == "SimpleBall"

## Get the visible mesh for a SimpleBall
static func get_visible_mesh(simple_ball: Node3D) -> MeshInstance3D:
	if not is_simple_ball(simple_ball):
		return null
	# Find the visible mesh instance
	for child in simple_ball.get_children():
		var node = child as Node3D
		if node and node.name == "Assembly":
			for mesh_child in node.get_children():
				var mesh_inst = mesh_child as MeshInstance3D
				if mesh_inst and mesh_inst.visible:
					return mesh_inst
	return null

## Get blend shape index by name
static func get_blend_shape_index(mesh_inst: MeshInstance3D, name: String) -> int:
	if not mesh_inst or not mesh_inst.mesh:
		return -1
	var mesh = mesh_inst.mesh as ArrayMesh
	if not mesh:
		return -1
	for i in range(mesh.get_blend_shape_count()):
		if mesh.get_blend_shape_name(i) == name:
			return i
	return -1

## Apply squash/stretch blend shape
static func apply_squash_stretch(simple_ball: Node3D, value: float) -> void:
	if not is_simple_ball(simple_ball):
		return
	var mesh_inst = get_visible_mesh(simple_ball)
	if not mesh_inst:
		return
	
	# Clamp value to [-1, 1]
	value = clampf(value, -1.0, 1.0)
	
	# Try to find and blend squash/stretch shape keys
	var squash_idx = get_blend_shape_index(mesh_inst, "squash")
	var stretch_idx = get_blend_shape_index(mesh_inst, "stretch")
	
	if value < 0 and squash_idx >= 0:
		# Squash: negative value
		mesh_inst.set_blend_shape_value(squash_idx, -value)
		if stretch_idx >= 0:
			mesh_inst.set_blend_shape_value(stretch_idx, 0.0)
	elif value > 0 and stretch_idx >= 0:
		# Stretch: positive value
		mesh_inst.set_blend_shape_value(stretch_idx, value)
		if squash_idx >= 0:
			mesh_inst.set_blend_shape_value(squash_idx, 0.0)
	else:
		# Neutral
		if squash_idx >= 0:
			mesh_inst.set_blend_shape_value(squash_idx, 0.0)
		if stretch_idx >= 0:
			mesh_inst.set_blend_shape_value(stretch_idx, 0.0)

## Apply height scaling (uniform Y-axis scaling, keeping base on floor)
static func apply_height_scale(target: Node3D, factor: float) -> void:
	if not target:
		return
	factor = maxf(0.1, factor)  # Clamp minimum
	target.scale = Vector3(1.0, factor, 1.0)
