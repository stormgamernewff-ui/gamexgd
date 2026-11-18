extends CharacterBody3D

@export var walk_speed := 5.6
@export var sprint_speed := 9.4
@export var jump_velocity := 5.2
@export var mouse_sensitivity := 0.0024

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var lantern_glow: OmniLight3D = $Head/LanternGlow
@onready var lantern_spot: SpotLight3D = $Head/LanternSpot

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var stamina := 100.0
var lantern_on := true
var can_move := false
var bob_time := 0.0
var yaw := 0.0
var pitch := 0.0

func set_active(active: bool) -> void:
	can_move = active
	if active:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event: InputEvent) -> void:
	if not can_move:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.35, 1.35)
		rotation.y = yaw
		head.rotation.x = pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			lantern_on = not lantern_on
			lantern_glow.visible = lantern_on
			lantern_spot.visible = lantern_on
		elif event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not can_move:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	input_dir = input_dir.normalized()

	var sprinting := Input.is_key_pressed(KEY_SHIFT) and input_dir.length() > 0.1 and stamina > 2.0
	var speed := sprint_speed if sprinting else walk_speed
	if sprinting:
		stamina = maxf(0.0, stamina - delta * 24.0)
	else:
		stamina = minf(100.0, stamina + delta * 16.0)

	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction != Vector3.ZERO:
		velocity.x = lerpf(velocity.x, direction.x * speed, minf(1.0, delta * 10.0))
		velocity.z = lerpf(velocity.z, direction.z * speed, minf(1.0, delta * 10.0))
	else:
		velocity.x = lerpf(velocity.x, 0.0, minf(1.0, delta * 10.0))
		velocity.z = lerpf(velocity.z, 0.0, minf(1.0, delta * 10.0))

	move_and_slide()

	if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.6:
		bob_time += delta * (12.0 if sprinting else 8.0)
		camera.position.y = sin(bob_time) * (0.065 if sprinting else 0.04)
	else:
		camera.position.y = lerpf(camera.position.y, 0.0, minf(1.0, delta * 8.0))
