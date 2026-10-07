class_name Joker3D
extends SubViewportContainer
## The Joker as a small 3D jester (placeholder until Phase 7 art), rendered in its own
## viewport and drawn over the table. Built from primitive meshes in code.
##
## Animations:
## - idle: bobs and sways its hat bells;
## - eyeing (set_eyed): turns head and body toward the players it would hit, narrows
##   its brows, and glances between them when several are tied;
## - attack: winds up, lunges toward the targets and emits `struck` at the peak so
##   the table can draw the hit.

signal struck

const VIEW_SIZE: Vector2i = Vector2i(240, 230)
## Screen distance that maps to the largest head turn.
const TURN_REACH: float = 520.0
const GLANCE_SECONDS: float = 1.3
## Arms hang a little away from the robe.
const REST_ARM: float = 0.5

var element: Element.Type = Element.Type.NORMAL
## Screen points the Joker is eyeing (global canvas coordinates).
var eyed_points: Array[Vector2] = []
var attacking: bool = false

var _viewport: SubViewport
var _body: Node3D
var _head: Node3D
var _pupils: Node3D
var _brows: Array[MeshInstance3D] = []
var _arms: Array[Node3D] = []
var _bells: Array[Node3D] = []
var _rim: OmniLight3D
var _robe_mat: StandardMaterial3D
var _hat_mats: Array[StandardMaterial3D] = []
var _time: float = 0.0
var _yaw: float = 0.0
var _pitch: float = 0.0
var _brow_angle: float = 0.0
var _glance: int = 0
var _glance_time: float = 0.0
var _tween: Tween


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(VIEW_SIZE)
	size = Vector2(VIEW_SIZE)
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_build_scene()
	set_element(Element.Type.NORMAL)


func set_element(p_element: Element.Type) -> void:
	element = p_element
	var tint: Color = UiStyle.type_color(element).lightened(0.15)
	_robe_mat.albedo_color = tint
	_hat_mats[0].albedo_color = tint
	_hat_mats[1].albedo_color = Color(0.32, 0.12, 0.42)
	_rim.light_color = tint.lightened(0.3)


## Look at these screen points (none: scan the room).
func set_eyed(points: Array[Vector2]) -> void:
	if points != eyed_points:
		eyed_points = points
		_glance = 0
		_glance_time = 0.0


## Lunge at `targets` (screen points). Emits `struck` at the moment of impact.
func attack(targets: Array[Vector2]) -> void:
	if not targets.is_empty():
		_look_toward(targets[0], 1.0)
	attacking = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	# Wind up: lean back, arms up, swell.
	_tween.set_parallel()
	_tween.tween_property(_body, "rotation:x", -0.32, 0.28).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_body, "scale", Vector3.ONE * 1.1, 0.28)
	_tween.tween_property(_arms[0], "rotation:z", -2.5, 0.28)
	_tween.tween_property(_arms[1], "rotation:z", 2.5, 0.28)
	_tween.tween_property(_rim, "light_energy", 5.0, 0.28)
	# Strike: snap forward.
	_tween.chain().tween_property(_body, "rotation:x", 0.42, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_tween.tween_property(_body, "position:z", 0.45, 0.1)
	_tween.tween_property(_arms[0], "rotation:z", -1.2, 0.1)
	_tween.tween_property(_arms[1], "rotation:z", 1.2, 0.1)
	_tween.tween_property(_arms[0], "rotation:x", -1.3, 0.1)
	_tween.tween_property(_arms[1], "rotation:x", -1.3, 0.1)
	_tween.chain().tween_callback(func() -> void: struck.emit())
	# Recover.
	_tween.chain().tween_interval(0.22)
	_tween.chain().tween_property(_body, "rotation:x", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_body, "position:z", 0.0, 0.45)
	_tween.tween_property(_body, "scale", Vector3.ONE, 0.45)
	for arm: Node3D in _arms:
		_tween.tween_property(arm, "rotation:x", 0.0, 0.45)
	_tween.tween_property(_arms[0], "rotation:z", -REST_ARM, 0.45)
	_tween.tween_property(_arms[1], "rotation:z", REST_ARM, 0.45)
	_tween.tween_property(_rim, "light_energy", 1.6, 0.45)
	_tween.chain().tween_callback(func() -> void: attacking = false)


## A quick hop, for when a card changes the Joker.
func react() -> void:
	if attacking:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_body, "scale", Vector3(1.12, 0.9, 1.12), 0.1)
	_tween.tween_property(_body, "scale", Vector3(0.94, 1.12, 0.94), 0.12)
	_tween.tween_property(_body, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	# Idle bob and bell sway.
	_body.position.y = sin(_time * 2.2) * 0.035
	for i: int in _bells.size():
		_bells[i].rotation.z = sin(_time * 3.0 + i * 1.7) * 0.12
	if not attacking:
		if eyed_points.is_empty():
			_look(sin(_time * 0.6) * 0.45, -0.05, 0.0, delta)
		else:
			_glance_time += delta
			if _glance_time >= GLANCE_SECONDS:
				_glance_time = 0.0
				_glance = (_glance + 1) % eyed_points.size()
			_look_toward(eyed_points[_glance % eyed_points.size()], delta)
	_head.rotation.y = _yaw
	_head.rotation.x = _pitch
	_body.rotation.y = _yaw * 0.25
	_pupils.position = Vector3(clampf(_yaw * 0.035, -0.035, 0.035), -_pitch * 0.03, 0)
	_brows[0].rotation.z = -_brow_angle
	_brows[1].rotation.z = _brow_angle


func _look_toward(point: Vector2, delta: float) -> void:
	var offset: Vector2 = point - get_global_rect().get_center()
	var yaw: float = clampf(atan2(offset.x, TURN_REACH), -0.75, 0.75)
	var pitch: float = clampf(atan2(offset.y, TURN_REACH * 1.4), -0.2, 0.45)
	_look(yaw, pitch, 0.35, delta)


func _look(yaw: float, pitch: float, brow: float, delta: float) -> void:
	var weight: float = clampf(delta * 6.0, 0.0, 1.0)
	_yaw = lerpf(_yaw, yaw, weight)
	_pitch = lerpf(_pitch, pitch, weight)
	_brow_angle = lerpf(_brow_angle, brow, weight)


# --- Building the model ---------------------------------------------------------------

func _build_scene() -> void:
	var root := Node3D.new()
	_viewport.add_child(root)

	var camera := Camera3D.new()
	camera.fov = 30.0
	root.add_child(camera)
	camera.position = Vector3(0, 1.2, 5.3)
	camera.look_at_from_position(camera.position, Vector3(0, 1.12, 0))

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.5, 0.6)
	env.environment.ambient_light_energy = 0.55
	root.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.15
	sun.rotation = Vector3(deg_to_rad(-35), deg_to_rad(25), 0)
	root.add_child(sun)
	_rim = OmniLight3D.new()
	_rim.position = Vector3(0, 1.8, -1.4)
	_rim.omni_range = 4.5
	_rim.light_energy = 1.6
	root.add_child(_rim)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.5, 0.8, 2.0)
	fill.omni_range = 5.0
	fill.light_energy = 0.5
	fill.light_color = Color(0.7, 0.75, 1.0)
	root.add_child(fill)

	_body = Node3D.new()
	root.add_child(_body)
	_robe_mat = _mat(Color.WHITE)
	_hat_mats = [_mat(Color.WHITE), _mat(Color.WHITE)]
	var gold := _mat(Color(0.95, 0.75, 0.25), 0.6, 0.35)
	var white := _mat(Color(0.97, 0.95, 0.92))
	var skin := _mat(Color(0.98, 0.92, 0.86))
	var dark := _mat(Color(0.08, 0.05, 0.1))
	var red := _mat(Color(0.9, 0.12, 0.15), 0.0, 0.3)

	# Robe, belt and the ruffled collar.
	var robe := CylinderMesh.new()
	robe.top_radius = 0.28
	robe.bottom_radius = 0.58
	robe.height = 1.0
	_add(_body, robe, _robe_mat, Vector3(0, 0.52, 0))
	# Diamond patches on the robe front.
	for i: int in 3:
		var patch := BoxMesh.new()
		patch.size = Vector3(0.16, 0.16, 0.02)
		var node: MeshInstance3D = _add(_body, patch, _hat_mats[1] if i % 2 == 0 else gold,
				Vector3(0, 0.3 + i * 0.24, 0.44 - i * 0.07))
		node.rotation = Vector3(-0.28, 0, PI / 4.0)
	var belt := TorusMesh.new()
	belt.inner_radius = 0.36
	belt.outer_radius = 0.44
	_add(_body, belt, gold, Vector3(0, 0.62, 0))
	for i: int in 12:
		var angle: float = i * TAU / 12.0
		var frill := SphereMesh.new()
		frill.radius = 0.1
		frill.height = 0.2
		var node: MeshInstance3D = _add(_body, frill, white if i % 2 == 0 else _hat_mats[1],
				Vector3(sin(angle) * 0.27, 1.04, cos(angle) * 0.27))
		node.scale = Vector3(1.0, 0.55, 1.0)

	# Arms pivot at the shoulders.
	for side: int in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(0.36 * side, 0.92, 0)
		arm.rotation.z = REST_ARM * side
		_body.add_child(arm)
		var sleeve := CapsuleMesh.new()
		sleeve.radius = 0.085
		sleeve.height = 0.55
		_add(arm, sleeve, _robe_mat, Vector3(0, -0.28, 0))
		var hand := SphereMesh.new()
		hand.radius = 0.1
		hand.height = 0.2
		_add(arm, hand, white, Vector3(0, -0.6, 0))
		_arms.append(arm)

	# Head on a neck pivot, so it can turn on its own.
	_head = Node3D.new()
	_head.position = Vector3(0, 1.1, 0)
	_body.add_child(_head)
	var face := SphereMesh.new()
	face.radius = 0.36
	face.height = 0.72
	_add(_head, face, skin, Vector3(0, 0.34, 0))
	for side: int in [-1, 1]:
		var eye := SphereMesh.new()
		eye.radius = 0.085
		eye.height = 0.17
		var white_eye: MeshInstance3D = _add(_head, eye, white, Vector3(0.13 * side, 0.42, 0.29))
		white_eye.scale = Vector3(1, 1.15, 0.6)
		var cheek := SphereMesh.new()
		cheek.radius = 0.06
		cheek.height = 0.12
		_add(_head, cheek, _mat(Color(0.95, 0.5, 0.55)), Vector3(0.21 * side, 0.27, 0.27)).scale = Vector3(1, 0.6, 0.4)
		var brow := BoxMesh.new()
		brow.size = Vector3(0.15, 0.035, 0.03)
		var brow_node: MeshInstance3D = _add(_head, brow, dark, Vector3(0.13 * side, 0.56, 0.31))
		_brows.append(brow_node)
	# Brows tilt inward (index 0 is the left one).
	_pupils = Node3D.new()
	_head.add_child(_pupils)
	for side: int in [-1, 1]:
		var pupil := SphereMesh.new()
		pupil.radius = 0.042
		pupil.height = 0.084
		_add(_pupils, pupil, dark, Vector3(0.13 * side, 0.42, 0.345))
	var nose := SphereMesh.new()
	nose.radius = 0.075
	nose.height = 0.15
	_add(_head, nose, red, Vector3(0, 0.33, 0.37))
	# The grin: a row of dark beads along an arc.
	for i: int in 7:
		var t: float = (i - 3) / 3.0
		var bead := SphereMesh.new()
		bead.radius = 0.025
		bead.height = 0.05
		_add(_head, bead, dark, Vector3(t * 0.15, 0.2 - (1.0 - t * t) * 0.05, 0.33 - absf(t) * 0.04))

	# Three-pointed jester hat with bells.
	var band := TorusMesh.new()
	band.inner_radius = 0.26
	band.outer_radius = 0.34
	_add(_head, band, gold, Vector3(0, 0.58, 0))
	for i: int in 3:
		var angle: float = (i - 1) * 0.95
		var point := Node3D.new()
		point.position = Vector3(0, 0.6, 0)
		point.rotation.z = -angle
		_head.add_child(point)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.16
		cone.height = 0.55 if i == 1 else 0.48
		_add(point, cone, _hat_mats[i % 2], Vector3(0, cone.height / 2.0, 0))
		var bell_pivot := Node3D.new()
		bell_pivot.position = Vector3(0, cone.height, 0)
		point.add_child(bell_pivot)
		var bell := SphereMesh.new()
		bell.radius = 0.06
		bell.height = 0.12
		_add(bell_pivot, bell, gold, Vector3(0, 0.04, 0))
		_bells.append(bell_pivot)


func _add(parent: Node3D, mesh: Mesh, surface: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = surface
	node.position = at
	parent.add_child(node)
	return node


func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.7) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat
