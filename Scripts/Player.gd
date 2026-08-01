
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
const PRONE_SPEED: float = 1.5

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

const SLIDE_FRICTION: float = 12.0
const SLOPE_BOOST: float = 24.0
var is_sliding: bool = false


# --- Node References & Crouch Data ---
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ceiling_check: RayCast3D = $CeilingCheck
@onready var interact_ray = $Head/Camera3D/InteractionRay
@onready var interact_prompt: Label = $HUD/CanvasLayer/InteractPrompt
@onready var axe = $Head/Axe
@onready var pistol = $Head/Pistol
@onready var weapons = [axe, pistol]
@onready var ammo_counter = $HUD/MarginContainer/Stats/Ammo/AmmoValue

var current_weapon_index: int = 0

var original_capsule_height: float
var original_shape_y: float
var original_head_y: float
var cursor_locked = true

#Hanging Variables
var is_hanging: bool = false
var ledge_axis: Vector3 = Vector3.ZERO
const HANG_SPEED: float = 3.0
const HANG_DRAIN_RATE: float = 10.0

var pull_up_progress: float = 0.0
var pull_up_counted: bool = false
const PULL_UP_COST: float = 20.0
const PULL_UP_SPEED: float = 1.5
var ledge_can_climb: bool = false

#Ladder
var is_on_ladder: bool = false
var ladder_normal: Vector3 = Vector3.ZERO
const LADDER_SPEED: float = 4.0
const LADDER_DRAIN_RATE: float = 4.0
const TRAVERSE_COST: float = 15.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Save our standing dimensions so we can lerp back to them
	original_capsule_height = collision_shape.shape.height
	original_shape_y = collision_shape.position.y
	original_head_y = head.position.y
	
	equip_weapon(current_weapon_index)
	
	camera.current = true
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
	if is_hanging:
		var wants_pull_up = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		
		if wants_pull_up and PlayerStats.stamina > 0:
			if pull_up_progress < 1.0:
				pull_up_progress += delta * PULL_UP_SPEED
				PlayerStats.change_stamina(-PULL_UP_COST * delta * PULL_UP_SPEED)
			else:
				PlayerStats.change_stamina(-HANG_DRAIN_RATE * delta)
				
				if ledge_can_climb and Input.is_action_just_pressed("up"):
					vault_over_obstacle()
					return
		else:
			pull_up_progress -= delta * PULL_UP_SPEED
			PlayerStats.change_stamina(-HANG_DRAIN_RATE * delta)
			
		PlayerStats.stamina_delay_timer = STAMINA_DELAY
		
		pull_up_progress = clamp(pull_up_progress, 0.0, 1.0)
		
		if pull_up_progress == 1.0 and not pull_up_counted:
			PlayerStats.add_pull_up()
			pull_up_counted = true
		elif pull_up_progress < 0.1:
			pull_up_counted = false
		
		var target_hang_head_y = original_head_y + (pull_up_progress * (original_capsule_height * 0.35))
		head.position.y = target_hang_head_y
		
		if PlayerStats.stamina <= 0 or Input.is_action_just_pressed("crouch"):
			stop_hanging()
			pull_up_progress = 0.0
			return
		
		var input_dir := Input.get_vector("left", "right", "up", "down")
		var move_dir = transform.basis.x * input_dir.x
		velocity = move_dir * HANG_SPEED
		move_and_slide()
		
		
		return
		
	# --- LADDER STATE OVERRIDE ---
	if is_on_ladder:
		# Check if we want to fast-slide down
		if Input.is_action_pressed("sprint"):
			# Move straight down at double speed with ZERO stamina drain
			velocity = Vector3.DOWN * (LADDER_SPEED * 2.0)
			move_and_slide()
			
			# Automatically let go if we hit the floor while sliding!
			if is_on_floor():
				stop_ladder()
			return
			
		PlayerStats.change_stamina(-LADDER_DRAIN_RATE * delta)
		PlayerStats.stamina_delay_timer = STAMINA_DELAY
		
		# Drop if out of stamina or pressing crouch
		if PlayerStats.stamina <= 0 or Input.is_action_just_pressed("crouch"):
			stop_ladder()
			return
			
		var input_dir := Input.get_vector("left", "right", "up", "down")
		
		# Move Left/Right locally, and Up/Down globally
		# (Input 'up' returns -y, so multiplying by -1 makes W go UP)
		var move_dir = (transform.basis.x * input_dir.x) + (Vector3.UP * -input_dir.y)
		
		velocity = move_dir * LADDER_SPEED
		move_and_slide()
		
		# --- Auto-Vault Check (Code-based RayCast) ---
		if velocity.y > 0: # Only check if we are moving UP
			var space_state = get_world_3d().direct_space_state
			# Shoot an invisible laser from our chest, straight forward into the ladder
			var query = PhysicsRayQueryParameters3D.create(global_position, global_position - ladder_normal * 0.8)
			var result = space_state.intersect_ray(query)
			
			# If the laser hits nothing, our chest has cleared the top of the ladder!
			if result.is_empty():
				vault_over_obstacle()
				
		return # Skip normal gravity and walking
	# --- END LADDER OVERRIDE ---
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var is_moving = direction.length() > 0
	
	# 1. Determine if we are actively holding sprint (Can't sprint if crouched or prone)
	var is_sprinting = false
	if Input.is_action_pressed("sprint") and is_moving and not PlayerStats.get_stealth() and not PlayerStats.get_prone() and PlayerStats.stamina > 0:
		is_sprinting = true

	# --- 2. Crouch, Prone & Slide Trigger Logic ---
	if Input.is_action_just_pressed("prone"):
		if PlayerStats.get_prone():
			# Trying to stand up from prone
			if not ceiling_check.is_colliding():
				PlayerStats.change_prone()
		else:
			# Going into prone (Belly flop!)
			PlayerStats.change_prone()
			is_sliding = false 

	if Input.is_action_just_pressed("crouch"):
		if PlayerStats.get_stealth():
			# Trying to stand up
			if not ceiling_check.is_colliding():
				PlayerStats.change_stealth()
				is_sliding = false 
		elif PlayerStats.get_prone():
			# Trying to rise from Prone to Crouch
			if not ceiling_check.is_colliding():
				PlayerStats.change_stealth()
		else:
			# Trying to crouch from standing
			PlayerStats.change_stealth()
			if is_sprinting and is_on_floor():
				is_sliding = true

	var is_crouching = PlayerStats.get_stealth()
	var is_prone = PlayerStats.get_prone()

	# --- Capsule Height Lerping ---
	var standing_height = original_capsule_height
	var crouch_height = original_capsule_height * (7.0 / 12.0)
	var prone_height = original_capsule_height * (3.0 / 12.0)
	var target_height = standing_height
	var y_offset = 0.0
	
	

	if is_prone:
		target_height = prone_height
		y_offset = (standing_height - prone_height) / 2.0
	elif is_crouching:
		target_height = crouch_height
		y_offset = (standing_height - crouch_height) / 2.0

	var target_shape_y = original_shape_y - y_offset
	var target_head_y = original_head_y - y_offset
	
	collision_shape.shape.height = lerp(collision_shape.shape.height, target_height, delta * 10.0)
	collision_shape.position.y = lerp(collision_shape.position.y, target_shape_y, delta * 10.0)
	head.position.y = lerp(head.position.y, target_head_y, delta * 10.0)
	

	# --- 3. Dodge Logic ---
	if is_dodging:
		dodge_timer -= delta
		if dodge_timer <= 0:
			is_dodging = false

	var valid_dodge_dir = input_dir.x != 0 or input_dir.y > 0 
	# Can't dodge while crouching OR prone
	if Input.is_action_just_pressed("dodge") and not is_dodging and not is_crouching and not is_prone and valid_dodge_dir and PlayerStats.stamina >= DODGE_COST:
		is_dodging = true
		dodge_timer = DODGE_DURATION
		dodge_direction = direction 
		PlayerStats.change_stamina(-DODGE_COST)
		PlayerStats.stamina_delay_timer = STAMINA_DELAY 

	# --- 4. Sprint & Stamina Drain ---
	if not is_dodging and not is_sliding:
		if is_sprinting:
			PlayerStats.change_stamina(-drain_rate * delta)
			PlayerStats.stamina_delay_timer = STAMINA_DELAY 

	# --- 5. Dynamic FOV ---
	var target_fov = SPRINT_FOV if (is_sprinting or is_sliding) else BASE_FOV
	camera.fov = lerp(camera.fov, target_fov, delta * FOV_TRANS_SPEED)

	# --- 6. Apply Movement Speed ---
	if is_dodging:
		velocity.x = dodge_direction.x * DODGE_SPEED
		velocity.z = dodge_direction.z * DODGE_SPEED
		
	elif is_sliding:
		var floor_normal = get_floor_normal()
		var downhill = Vector3.DOWN.slide(floor_normal).normalized()
		var slope_vector = Vector2(downhill.x, downhill.z)
		
		if slope_vector.length() > 0.1: 
			velocity.x += downhill.x * SLOPE_BOOST * delta
			velocity.z += downhill.z * SLOPE_BOOST * delta
		else: 
			velocity.x = move_toward(velocity.x, 0, SLIDE_FRICTION * delta)
			velocity.z = move_toward(velocity.z, 0, SLIDE_FRICTION * delta)
			
		if direction:
			velocity.x += direction.x * 3.0 * delta
			velocity.z += direction.z * 3.0 * delta
			
		var current_horiz_speed = Vector2(velocity.x, velocity.z).length()
		if current_horiz_speed <= CROUCH_SPEED:
			is_sliding = false
			
	else:
		# Determine speed based on our current state hierarchy
		var current_speed = WALK_SPEED
		if is_sprinting: current_speed = SPRINT_SPEED
		elif is_prone: current_speed = PRONE_SPEED
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


func _process(_delta: float) -> void:
	# 1. Default state: hide the prompt
	interact_prompt.visible = false
	
	# 2. Raycast Interaction Logic
	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		
		if target != null:
			# --- Ledge Logic ---
			if target.has_method("get_ledge_axis"):
				var is_traversing = is_hanging or is_on_ladder
				
				# Change the UI prompt if we are already hanging/climbing
				interact_prompt.text = "[E] Leap to Ledge" if is_traversing else "[E] " + target.prompt_message
				interact_prompt.visible = true
				
				if Input.is_action_just_pressed("interact"):
					var hit_point = interact_ray.get_collision_point()
					var hit_normal = interact_ray.get_collision_normal()
					
					if is_traversing:
						# Only allow the leap if we have enough stamina
						if PlayerStats.stamina >= TRAVERSE_COST:
							PlayerStats.change_stamina(-TRAVERSE_COST)
							PlayerStats.stamina_delay_timer = STAMINA_DELAY
							# Clean up old states before jumping
							is_hanging = false 
							is_on_ladder = false
							start_hanging(target.get_ledge_axis(), hit_point, hit_normal, target.get_can_climb())
					else:
						start_hanging(target.get_ledge_axis(), hit_point, hit_normal, target.get_can_climb())
						
			# --- Ladder Logic ---
			elif target.has_method("get_is_ladder"):
				var is_traversing = is_hanging or is_on_ladder
				
				interact_prompt.text = "[E] Leap to Ladder" if is_traversing else "[E] " + target.prompt_message
				interact_prompt.visible = true
				
				if Input.is_action_just_pressed("interact"):
					var hit_point = interact_ray.get_collision_point()
					var hit_normal = interact_ray.get_collision_normal()
					
					if is_traversing:
						if PlayerStats.stamina >= TRAVERSE_COST:
							PlayerStats.change_stamina(-TRAVERSE_COST)
							PlayerStats.stamina_delay_timer = STAMINA_DELAY
							is_hanging = false
							is_on_ladder = false
							start_ladder(hit_normal, hit_point)
					else:
						start_ladder(hit_normal, hit_point)

			# --- Door / Object Logic ---
			elif target.has_method("interact") and not is_hanging and not is_on_ladder:
				interact_prompt.text = "[E] " + target.prompt_message
				interact_prompt.visible = true
				if Input.is_action_just_pressed("interact"):
					target.interact()
					
	# 3. Weapon Switching Logic
	# Added "and not is_on_ladder" so weapons stay locked while climbing!
	if Input.is_action_just_pressed("switch_weapon") and not is_hanging and not is_on_ladder:
		current_weapon_index = (current_weapon_index + 1) % weapons.size()
		equip_weapon(current_weapon_index)	

func start_hanging(axis: Vector3, hit_point: Vector3, hit_normal: Vector3, can_climb_flag: bool) -> void:
	is_hanging = true
	ledge_axis = axis
	ledge_can_climb = can_climb_flag
	
	PlayerStats.change_action(0)
	
	if PlayerStats.get_stealth(): PlayerStats.change_stealth()
	if PlayerStats.get_prone(): PlayerStats.change_prone()
	is_sliding = false
	is_dodging = false
	
	global_position = hit_point + (hit_normal * 0.5) - Vector3(0, original_capsule_height * 0.35, 0)

	var look_target = global_position - hit_normal
	look_target.y = global_position.y
	look_at(look_target, Vector3.UP)
	head.rotation.x = 0
	
func stop_hanging() -> void:
	is_hanging = false
	PlayerStats.change_action(1)


func equip_weapon(index: int) -> void:
	for i in range(weapons.size()):
		if i == index:
			weapons[i].visible = true
			weapons[i].set_process(true)
			weapons[i].set_physics_process(true)
			
			if weapons[i].has_node("CanvasLayer"):
				weapons[i].get_node("CanvasLayer").visible = true
			
			if weapons[i].get("is_gun") == true:
				ammo_counter.visible = true
			else:
				ammo_counter.visible = false
		else:
			weapons[i].visible = false
			weapons[i].set_process(false)
			weapons[i].set_physics_process(false)
			
			if weapons[i].has_node("CanvasLayer"):
				weapons[i].get_node("CanvasLayer").visible = false
			

			
func vault_over_obstacle() -> void:
	var forward_dir = -transform.basis.z 
   
	global_position += Vector3(0, original_capsule_height * 0.9, 0) + (forward_dir * 1.2)
	
	stop_hanging()
	stop_ladder()
	
	pull_up_progress = 0.0
	head.position.y = original_head_y

func start_ladder(hit_normal: Vector3, hit_point: Vector3) -> void:
	
	is_on_ladder = true
	ladder_normal = hit_normal
	PlayerStats.change_action(0) 
	
	if PlayerStats.get_stealth(): PlayerStats.change_stealth()
	if PlayerStats.get_prone(): PlayerStats.change_prone()
	is_sliding = false
	is_dodging = false

	# Teleport to the ladder so mid-air leaps connect perfectly!
	# (Using a slightly different offset than ledges so the player centers on the rungs)
	global_position = hit_point + (hit_normal * 0.6) - Vector3(0, original_capsule_height * 0.25, 0)

	var look_target = global_position - ladder_normal
	look_target.y = global_position.y
	look_at(look_target, Vector3.UP)
	head.rotation.x = 0
	


func stop_ladder() -> void:
	is_on_ladder = false
	PlayerStats.change_action(1)
