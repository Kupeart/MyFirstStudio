class_name TestGizmo
extends Node

const GizmoScript := preload("res://scripts/core/move_gizmo.gd")


func test_gizmo_modes() -> void:
	var gizmo = GizmoScript.new()
	gizmo._ready()
	assert(gizmo.get_mode() == GizmoScript.GizmoMode.TRANSLATE, "Default mode must be TRANSLATE")
	assert(gizmo._arrows_root.visible == true, "Arrows must be visible in TRANSLATE mode")
	assert(gizmo._ring_origin.visible == false, "Rings must be hidden in TRANSLATE mode")

	gizmo.set_mode(GizmoScript.GizmoMode.ROTATE)
	assert(gizmo.get_mode() == GizmoScript.GizmoMode.ROTATE, "Mode must switch to ROTATE")
	assert(gizmo._arrows_root.visible == false, "Arrows must be hidden in ROTATE mode")
	assert(gizmo._ring_origin.visible == true, "Rings must be visible in ROTATE mode")
	gizmo.free()


func test_gizmo_rmb_cancel() -> void:
	var root := Node3D.new()
	add_child(root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)

	var mock_prop := Node3D.new()
	root.add_child(mock_prop)
	mock_prop.position = Vector3(5, 2, 8)
	var original_transform := mock_prop.global_transform

	gizmo._targets.clear()
	gizmo._targets.append(mock_prop)
	gizmo._start_transforms.clear()
	gizmo._start_transforms.append(original_transform)
	gizmo._active = GizmoScript.Handle.AXIS_X

	mock_prop.position = Vector3(100, 200, 300)
	assert(gizmo.is_dragging() == true, "Must be dragging")

	gizmo.cancel_drag()
	assert(gizmo.is_dragging() == false, "Must not be dragging after cancel")
	assert(mock_prop.global_transform == original_transform, "Transform must be reverted to original")

	root.free()


func test_rotation_math() -> void:
	var root := Node3D.new()
	add_child(root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)

	var mock_prop := Node3D.new()
	root.add_child(mock_prop)
	mock_prop.position = Vector3(0, 0, 0)
	gizmo._targets.clear()
	gizmo._targets.append(mock_prop)
	gizmo._begin_ring_drag(GizmoScript.Handle.ROTATE_Y, Vector3(1.3, 0, 0))

	assert(gizmo._active == GizmoScript.Handle.ROTATE_Y, "Must be active on ROTATE_Y")
	assert(gizmo._ring_plane_normal == Vector3.UP, "Normal for ROTATE_Y must be UP")
	assert(gizmo._ring_grab_vector.is_equal_approx(Vector3(1, 0, 0)), "Grab vector should point along X")

	# Simulate dragging to a point that is 90 deg counter-clockwise around UP (along -Z)
	var ray_origin := Vector3(0, 5, -5)
	var ray_dir := (Vector3(0, 0, -1.3) - ray_origin).normalized()
	gizmo._rotate_drag(ray_origin, ray_dir)

	# In ROTATE_Y: X rotated by 90 deg around +Y points to -Z.
	var rotated_x := mock_prop.global_basis * Vector3.RIGHT
	assert(rotated_x.is_equal_approx(Vector3(0, 0, -1)), "Prop should have rotated 90 deg around Y")

	root.free()


func test_ring_pick() -> void:
	var root := Node3D.new()
	add_child(root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)

	# נקודה על הטבעת הירוקה (מישור XZ) בזווית 45 מעלות - רחוקה מהטבעות האחרות.
	var y_point := Vector3(cos(0.25 * PI), 0.0, sin(0.25 * PI)) * 1.3
	var picked: int = gizmo._ring_at(y_point + Vector3(0.0, 5.0, 0.0), Vector3(0.0, -1.0, 0.0))
	assert(picked == GizmoScript.Handle.ROTATE_Y, "Ray over the Y ring must pick ROTATE_Y")
	assert(gizmo._picked_grab_point.distance_to(y_point) < 0.01, "Grab point must sit on the ring")

	# נקודה על הטבעת האדומה (מישור YZ).
	var x_point := Vector3(0.0, cos(0.25 * PI), sin(0.25 * PI)) * 1.3
	picked = gizmo._ring_at(x_point + Vector3(0.0, 5.0, 0.0), Vector3(0.0, -1.0, 0.0))
	assert(picked == GizmoScript.Handle.ROTATE_X, "Ray over the X ring must pick ROTATE_X")

	# נקודה על הטבעת הכחולה (מישור XY).
	var z_point := Vector3(cos(0.25 * PI), sin(0.25 * PI), 0.0) * 1.3
	picked = gizmo._ring_at(z_point + Vector3(0.0, 5.0, 0.0), Vector3(0.0, -1.0, 0.0))
	assert(picked == GizmoScript.Handle.ROTATE_Z, "Ray over the Z ring must pick ROTATE_Z")

	# קרן שעוברת בין הטבעות, קרוב למרכז אבל לא על אף טבעת.
	picked = gizmo._ring_at(Vector3(0.6, 5.0, 0.6), Vector3(0.0, -1.0, 0.0))
	assert(picked == GizmoScript.Handle.NONE, "Ray between the rings must not pick any ring")

	# קרן קרובה לטבעת אבל מחוץ לטווח התפיסה.
	picked = gizmo._ring_at(y_point * 0.7 + Vector3(0.0, 5.0, 0.0), Vector3(0.0, -1.0, 0.0))
	assert(picked == GizmoScript.Handle.NONE, "Ray far from the ring must not pick it")

	root.free()


func test_ring_pick_respects_scale() -> void:
	var root := Node3D.new()
	add_child(root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)
	gizmo.scale = Vector3.ONE * 2.0

	# נקודה על הטבעת המצוירת, שהרדיוס שלה מוכפל בקנה המידה (1.3 * 2).
	var scaled_point := Vector3(cos(0.25 * PI), 0.0, sin(0.25 * PI)) * 1.3 * 2.0
	var picked: int = gizmo._ring_at(scaled_point + Vector3(0.0, 8.0, 0.0), Vector3(0.0, -1.0, 0.0))
	assert(picked == GizmoScript.Handle.ROTATE_Y, "Ray over the scaled Y ring must pick ROTATE_Y")

	# נקודה ברדיוס הלא-מכויל כבר לא אמורה להיתפס.
	var unscaled_point := Vector3(cos(0.25 * PI), 0.0, sin(0.25 * PI)) * 1.3
	picked = gizmo._ring_at(unscaled_point + Vector3(0.0, 8.0, 0.0), Vector3(0.0, -1.0, 0.0))
	assert(picked == GizmoScript.Handle.NONE, "The unscaled radius must no longer trigger")

	root.free()


func test_axis_pick_respects_scale() -> void:
	var root := Node3D.new()
	add_child(root)

	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0.0, 4.0, 9.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)
	gizmo.setup(camera)
	gizmo.scale = Vector3.ONE * 2.0

	var prop := Node3D.new()
	root.add_child(prop)
	gizmo._targets.clear()
	gizmo._targets.append(prop)

	# נקודה לאורך חץ ה-X המצויר - אורכו מוכפל עם קנה המידה.
	var world_point := Vector3(2.0, 0.0, 0.0)
	var screen_point := camera.unproject_position(world_point)
	var handle: int = gizmo._handle_at_screen(screen_point)
	assert(handle == GizmoScript.Handle.AXIS_X, "The scaled X arrow must be grabbable along its whole length")

	root.free()


func test_scale_handles_and_picking() -> void:
	var root := Node3D.new()
	add_child(root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)

	# הידיות נבנו ונרשמו לזיהוי ריחוף.
	assert(gizmo._scale_root != null, "The scale gizmo root must exist")
	assert(gizmo._handle_nodes.has(GizmoScript.Handle.SCALE_X), "Scale X handle must be built")
	assert(gizmo._handle_nodes.has(GizmoScript.Handle.SCALE_Y), "Scale Y handle must be built")
	assert(gizmo._handle_nodes.has(GizmoScript.Handle.SCALE_Z), "Scale Z handle must be built")
	assert(gizmo._handle_nodes.has(GizmoScript.Handle.SCALE_UNIFORM), "The uniform scale handle must be built")

	# קרן אל המרכז - תופסת את הידית האחידה.
	var picked: int = gizmo._scale_handle_at(Vector3(0.0, 5.0, 0.0), Vector3(0.0, -1.0, 0.0))
	assert(picked == GizmoScript.Handle.SCALE_UNIFORM, "A ray at the center must pick the uniform handle")

	# קרן אל נקודה לאורך ציר X - תופסת את ידית ה-X.
	picked = gizmo._scale_handle_at(Vector3(1.0, 5.0, 0.0), Vector3(0.0, -1.0, 0.0))
	assert(picked == GizmoScript.Handle.SCALE_X, "A ray along the X axis must pick the X scale handle")

	# קרן רחוק מכל הידיות - לא תופסת כלום.
	picked = gizmo._scale_handle_at(Vector3(5.0, 5.0, 5.0), Vector3(0.0, -1.0, 0.0))
	assert(picked == GizmoScript.Handle.NONE, "A ray away from the gizmo must pick nothing")

	root.free()


func test_scale_keeps_base_on_floor() -> void:
	var root := Node3D.new()
	add_child(root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)

	var prop := Node3D.new()
	root.add_child(prop)
	prop.position = Vector3(2.0, 0.0, 3.0)

	gizmo.attach_to_group([prop])
	gizmo._capture_targets()
	gizmo._apply_scale(Vector3.ONE * 2.0)

	assert(is_equal_approx(prop.global_position.y, 0.0), "Scaling must keep the base on the floor")
	assert(
		prop.global_basis.get_scale().is_equal_approx(Vector3.ONE * 2.0),
		"The object must actually be scaled by the factor"
	)

	root.free()


func test_scale_gizmo_is_local() -> void:
	var root := Node3D.new()
	add_child(root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)

	var prop := Node3D.new()
	root.add_child(prop)
	prop.rotate_y(deg_to_rad(30.0))

	gizmo.attach_to_group([prop])

	# הגיזמו מסתובב יחד עם העצם - הצירים שלו הם הצירים המקומיים של העצם.
	var expected := prop.global_basis.orthonormalized()
	assert(
		gizmo._scale_rotation.is_equal_approx(expected),
		"The scale gizmo must rotate with the selected object"
	)
	assert(
		gizmo._scale_root.basis.is_equal_approx(expected),
		"The scale handles must be drawn along the object's local axes"
	)

	# קרן שעוברת לאורך הציר המקומי של X (המסובב) תופסת את ידית X.
	var local_x := (prop.global_basis * Vector3.RIGHT).normalized()
	var probe := local_x * 0.8
	var picked: int = gizmo._scale_handle_at(probe + Vector3(0.0, 5.0, 0.0), Vector3(0.0, -1.0, 0.0))
	assert(
		picked == GizmoScript.Handle.SCALE_X,
		"A ray over the rotated local X handle must pick it"
	)

	root.free()


func test_rotated_object_scales_without_shear() -> void:
	var root := Node3D.new()
	add_child(root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)

	var prop := Node3D.new()
	root.add_child(prop)
	prop.rotate_y(deg_to_rad(30.0))

	gizmo.attach_to_group([prop])
	gizmo._capture_targets()
	gizmo._apply_scale(Vector3(3.0, 1.0, 1.0))

	var b := prop.global_basis
	assert(absf(b.x.dot(b.y)) < 0.001, "Scaling must not shear the object (X vs Y)")
	assert(absf(b.x.dot(b.z)) < 0.001, "Scaling must not shear the object (X vs Z)")
	assert(absf(b.y.dot(b.z)) < 0.001, "Scaling must not shear the object (Y vs Z)")
	assert(is_equal_approx(b.x.length(), 3.0), "The local X axis must be stretched by the factor")
	assert(is_equal_approx(b.y.length(), 1.0), "The local Y axis must stay as it was")
	assert(is_equal_approx(b.z.length(), 1.0), "The local Z axis must stay as it was")

	root.free()


func test_group_scale_spreads_around_pivot() -> void:
	var root := Node3D.new()
	add_child(root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)

	var first := Node3D.new()
	root.add_child(first)
	var second := Node3D.new()
	root.add_child(second)
	second.position = Vector3(2.0, 0.0, 0.0)

	gizmo.attach_to_group([first, second])
	assert(
		gizmo.global_position.is_equal_approx(Vector3(1.0, 0.0, 0.0)),
		"The shared pivot sits at the group base center"
	)

	gizmo._capture_targets()
	gizmo._apply_scale(Vector3.ONE * 2.0)

	assert(
		first.global_position.is_equal_approx(Vector3(-1.0, 0.0, 0.0)),
		"The first object must move away from the shared pivot"
	)
	assert(
		second.global_position.is_equal_approx(Vector3(3.0, 0.0, 0.0)),
		"The second object must move away from the shared pivot too"
	)

	root.free()


func test_hover_style() -> void:
	var root := Node3D.new()
	add_child(root)

	var gizmo = GizmoScript.new()
	root.add_child(gizmo)

	gizmo._set_hovered(GizmoScript.Handle.AXIS_X)
	var node := gizmo._handle_nodes[GizmoScript.Handle.AXIS_X] as Node3D
	assert(node != null, "Axis X must be registered as a handle node")
	assert(is_equal_approx(node.scale.x, GizmoScript.HOVER_SCALE_BOOST), "Hovered handle must be enlarged")

	var mesh := node.get_child(0) as MeshInstance3D
	assert(mesh != null and mesh.material_override != null, "Hovered handle must have a highlight material")
	var mat := mesh.material_override as StandardMaterial3D
	assert(mat != null and mat.albedo_color.r > GizmoScript.X_COLOR.r, "Hover material must be brighter than the base color")

	gizmo._set_hovered(GizmoScript.Handle.NONE)
	assert(is_equal_approx(node.scale.x, 1.0), "Unhovered handle must return to normal size")
	var restored := (mesh.material_override as StandardMaterial3D)
	assert(restored != null and restored.albedo_color.is_equal_approx(GizmoScript.X_COLOR), "Unhovered handle must restore its original color")

	root.free()
