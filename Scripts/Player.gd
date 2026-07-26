extends CharacterBody3D


const SPEED: float = 7.0
const SPRINT: float = 4
const MOUSE_SENS: float = 0.002
const GRAVITY: float = 9.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	
#func _input(event) -> void:
	#if event is InputEventMouseMotion:
		#rotation_degrees.y -= event.relative.x * MOUSE_SENS


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		if Input.is_action_just_pressed("sprint"):
			velocity.x = direction.x * (SPEED * SPRINT)
			velocity.z = direction.z * (SPEED * SPRINT)
		else:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
	else:
		if Input.is_action_just_pressed("sprint"):
			velocity.x = move_toward(velocity.x, 0, SPEED*SPRINT)
			velocity.z = move_toward(velocity.z, 0, SPEED*SPRINT)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
	move_and_slide()
	
	
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		$Head.rotate_x(-event.relative.y * MOUSE_SENS)
		$Head.rotation.x = clamp($Head.rotation.x,-1.2,1.2)
