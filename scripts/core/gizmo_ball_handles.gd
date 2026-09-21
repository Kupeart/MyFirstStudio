class_name GizmoBallHandles
extends RefCounted
## Ball-specific gizmo handles for HEIGHT and SQUASH_STRETCH

const HEIGHT = "HEIGHT"
const SQUASH_STRETCH = "SQUASH_STRETCH"

## Apply height scaling (Y-axis only, keeping base on floor)
static func apply_height_scale(target: Node3D, factor: float) -> void:
	if not target:
		return
	factor = maxf(0.1, factor)
	target.scale.y = factor

## Apply squash/stretch via shape keys
static func apply_squash_stretch(simple_ball: Node3D, value: float) -> void:
	# value: -1 = full squash, 0 = neutral, +1 = full stretch
	if not simple_ball or not simple_ball is SimpleBall:
		return
	
	value = clampf(value, -1.0, 1.0)
	
	# Get the visible mesh
	var visible_mesh: MeshInstance3D = null
	var assembly = simple_ball.get_child(0) if simple_ball.get_child_count() > 0 else null
	if assembly:
		for child in assembly.get_children():
			var mesh_inst = child as MeshInstance3D
			if mesh_inst and mesh_inst.visible:
				visible_mesh = mesh_inst
				break
	
	if not visible_mesh or not visible_mesh.mesh:
		return
	
	var mesh = visible_mesh.mesh as ArrayMesh
	if not mesh:
		return
	
	# Find and blend squash/stretch shape keys
	var squash_idx = _get_blend_shape_index(mesh, "squash")
	var stretch_idx = _get_blend_shape_index(mesh, "stretch")
	
	if value < 0 and squash_idx >= 0:
		# Squash
		visible_mesh.set_blend_shape_value(squash_idx, -value)
		if stretch_idx >= 0:
			visible_mesh.set_blend_shape_value(stretch_idx, 0.0)
	elif value > 0 and stretch_idx >= 0:
		# Stretch
		visible_mesh.set_blend_shape_value(stretch_idx, value)
		if squash_idx >= 0:
			visible_mesh.set_blend_shape_value(squash_idx, 0.0)
	else:
		# Neutral
		if squash_idx >= 0:
			visible_mesh.set_blend_shape_value(squash_idx, 0.0)
		if stretch_idx >= 0:
			visible_mesh.set_blend_shape_value(stretch_idx, 0.0)

static func _get_blend_shape_index(mesh: ArrayMesh, name: String) -> int:
	for i in range(mesh.get_blend_shape_count()):
		if mesh.get_blend_shape_name(i) == name:
			return i
	return -1
