
extends CharacterBody3D

#Crouch height 3 blocks
#Player height 2m or 5 blocks

#player height 1.9m or 4 blocks  (8 blocks at 3m)
#crouch height 3 blocks at 3m

# --- Movement Variables ---
const WALK_SPEED: float = 7.0
const SPRINT_SPEED: float = 14.0
const CROUCH_SPEED: float = 3.5
const MOUSE_SENS: float = 0.002

# --- Dodge Variables ---
const DODGE_SPEED: float = 25.0
const DODGE_DURATION: float = 0.2 
const DODGE_COST: float = 20.0
var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO

# --- Stamina & FOV ---
var drain_rate: float = 20.0
const STAMINA_DELAY: float = 1.5 
const BASE_FOV: float = 75.0
const SPRINT_FOV: float = 90.0
const FOV_TRANS_SPEED: float = 8.0

# --- Node References & Crouch Data ---
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var original_capsule_height: float
var original_shape_y: float
var original_head_y: float

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Save our standing dimensions so we can lerp back to them
	original_capsule_height = collision_shape.shape.height
	original_shape_y = collision_shape.position.y
	original_head_y = head.position.y
	
	# --- Slope & Stair Snapping Settings ---
	# Keeps the player from flying off ramps when going up/down
	floor_constant_speed = true 
	# Prevents sliding down slopes when you let go of the keys
	floor_stop_on_slope = true
	# The max angle the player can walk up (45 degrees is standard)
	floor_max_angle = deg_to_rad(45.0)
	# Casts a ray downwards to "snap" the player to the floor, preventing bounces on the way down
	floor_snap_length = 0.5

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var is_moving = direction.length() > 0
	var is_sprinting = false

	# --- 1. Crouch Toggle Logic ---
	if Input.is_action_just_pressed("crouch"):
		PlayerStats.change_stealth()
		
	var is_crouching = PlayerStats.get_stealth()

	# Lerp Capsule Height and Position (keeps feet on the floor)
	var target_height = original_capsule_height * 0.4 if is_crouching else original_capsule_height
	var target_shape_y = (original_shape_y - (original_capsule_height * 0.25)) if is_crouching else original_shape_y
	var target_head_y = (original_head_y - (original_capsule_height * 0.25)) if is_crouching else original_head_y
	
	collision_shape.shape.height = lerp(collision_shape.shape.height, target_height, delta * 10.0)
	collision_shape.position.y = lerp(collision_shape.position.y, target_shape_y, delta * 10.0)
	head.position.y = lerp(head.position.y, target_head_y, delta * 10.0)

	# --- 2. Dodge Timer Management ---
	if is_dodging:
		dodge_timer -= delta
		if dodge_timer <= 0:
			is_dodging = false

	# --- 3. Dodge Trigger Logic ---
	var valid_dodge_dir = input_dir.x != 0 or input_dir.y > 0 
	
	# Can't dodge while crouching
	if Input.is_action_just_pressed("dodge") and not is_dodging and not is_crouching and valid_dodge_dir and PlayerStats.stamina >= DODGE_COST:
		is_dodging = true
		dodge_timer = DODGE_DURATION
		dodge_direction = direction 
		
		PlayerStats.change_stamina(-DODGE_COST)
		PlayerStats.stamina_delay_timer = STAMINA_DELAY 

	# --- 4. Sprint & Stamina Drain ---
	if not is_dodging:
		# Can't sprint while crouching
		if Input.is_action_pressed("sprint") and is_moving and not is_crouching and PlayerStats.stamina > 0:
			is_sprinting = true
			PlayerStats.change_stamina(-drain_rate * delta)
			PlayerStats.stamina_delay_timer = STAMINA_DELAY 

	# --- 5. Dynamic FOV ---
	var target_fov = SPRINT_FOV if is_sprinting else BASE_FOV
	camera.fov = lerp(camera.fov, target_fov, delta * FOV_TRANS_SPEED)

	# --- 6. Apply Speed ---
	if is_dodging:
		velocity.x = dodge_direction.x * DODGE_SPEED
		velocity.z = dodge_direction.z * DODGE_SPEED
	else:
		# Determine speed based on current state
		var current_speed = WALK_SPEED
		if is_sprinting: current_speed = SPRINT_SPEED
		elif is_crouching: current_speed = CROUCH_SPEED
		
		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotate_x(-event.relative.y * MOUSE_SENS)
		head.rotation.x = clamp(head.rotation.x, -1.2, 1.2)
