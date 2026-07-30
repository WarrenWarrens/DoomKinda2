
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
	
#func _physics_process(delta: float) -> void:
	#if not is_on_floor():
		#velocity += get_gravity() * delta
#
	#var input_dir := Input.get_vector("left", "right", "up", "down")
	#var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	#var is_moving = direction.length() > 0
	#
	## 1. Determine if we are actively holding sprint
	#var is_sprinting = false
	#if Input.is_action_pressed("sprint") and is_moving and not PlayerStats.get_stealth() and PlayerStats.stamina > 0:
		#is_sprinting = true
#
	## --- 2. Crouch & Slide Trigger Logic ---
	#if Input.is_action_just_pressed("crouch"):
		#if PlayerStats.get_stealth():
			## Trying to stand up
			#if not ceiling_check.is_colliding():
				#PlayerStats.change_stealth()
				#is_sliding = false # Cancel slide if we stand up
		#else:
			## Trying to crouch
			#PlayerStats.change_stealth()
			## Trigger slide ONLY if we were sprinting when we crouched!
			#if is_sprinting and is_on_floor():
				#is_sliding = true
#
	#var is_crouching = PlayerStats.get_stealth()
#
	## Lerp Capsule Height (keep your existing lerp code here)
	#var target_height = original_capsule_height * 0.4 if is_crouching else original_capsule_height
	#var target_shape_y = (original_shape_y - (original_capsule_height * 0.25)) if is_crouching else original_shape_y
	#var target_head_y = (original_head_y - (original_capsule_height * 0.25)) if is_crouching else original_head_y
	#
	#collision_shape.shape.height = lerp(collision_shape.shape.height, target_height, delta * 10.0)
	#collision_shape.position.y = lerp(collision_shape.position.y, target_shape_y, delta * 10.0)
	#head.position.y = lerp(head.position.y, target_head_y, delta * 10.0)
#
	## --- 3. Dodge Logic (Keep your existing code) ---
	#if is_dodging:
		#dodge_timer -= delta
		#if dodge_timer <= 0:
			#is_dodging = false
#
	#var valid_dodge_dir = input_dir.x != 0 or input_dir.y > 0 
	#if Input.is_action_just_pressed("dodge") and not is_dodging and not is_crouching and valid_dodge_dir and PlayerStats.stamina >= DODGE_COST:
		#is_dodging = true
		#dodge_timer = DODGE_DURATION
		#dodge_direction = direction 
		#PlayerStats.change_stamina(-DODGE_COST)
		#PlayerStats.stamina_delay_timer = STAMINA_DELAY 
#
	## --- 4. Sprint & Stamina Drain ---
	## We naturally stop draining stamina while sliding because is_sprinting becomes false when crouched!
	#if not is_dodging and not is_sliding:
		#if is_sprinting:
			#PlayerStats.change_stamina(-drain_rate * delta)
			#PlayerStats.stamina_delay_timer = STAMINA_DELAY 
#
	## --- 5. Dynamic FOV ---
	## Target sprint FOV if sprinting OR sliding
	#var target_fov = SPRINT_FOV if (is_sprinting or is_sliding) else BASE_FOV
	#camera.fov = lerp(camera.fov, target_fov, delta * FOV_TRANS_SPEED)
#
	## --- 6. Apply Movement Speed ---
	#if is_dodging:
		#velocity.x = dodge_direction.x * DODGE_SPEED
		#velocity.z = dodge_direction.z * DODGE_SPEED
		#
	#elif is_sliding:
		#var floor_normal = get_floor_normal()
		## This math extracts exactly how sloped the ground is
		#var downhill = Vector3.DOWN.slide(floor_normal).normalized()
		#var slope_vector = Vector2(downhill.x, downhill.z)
		#
		#if slope_vector.length() > 0.1: 
			## We are on a slope! Add momentum downhill
			#velocity.x += downhill.x * SLOPE_BOOST * delta
			#velocity.z += downhill.z * SLOPE_BOOST * delta
		#else: 
			## Flat ground! Apply friction to slow down over time
			#velocity.x = move_toward(velocity.x, 0, SLIDE_FRICTION * delta)
			#velocity.z = move_toward(velocity.z, 0, SLIDE_FRICTION * delta)
			#
		## Allow slight steering left/right while sliding (optional but feels amazing)
		#if direction:
			#velocity.x += direction.x * 3.0 * delta
			#velocity.z += direction.z * 3.0 * delta
			#
		## End the slide automatically if we slow down to crouch speed
		#var current_horiz_speed = Vector2(velocity.x, velocity.z).length()
		#if current_horiz_speed <= CROUCH_SPEED:
			#is_sliding = false
			#
	#else:
		## Normal walking/sprinting/crouching logic
		#var current_speed = WALK_SPEED
		#if is_sprinting: current_speed = SPRINT_SPEED
		#elif is_crouching: current_speed = CROUCH_SPEED
		#
		#if direction:
			#velocity.x = direction.x * current_speed
			#velocity.z = direction.z * current_speed
		#else:
			#velocity.x = move_toward(velocity.x, 0, current_speed)
			#velocity.z = move_toward(velocity.z, 0, current_speed)
#
	#move_and_slide()
	

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotate_x(-event.relative.y * MOUSE_SENS)
		head.rotation.x = clamp(head.rotation.x, -1.2, 1.2)


func _process(_delta: float) -> void:
	interact_prompt.visible = false
	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		if target != null and target.has_method("interact"):
			interact_prompt.text = "[E] " + target.prompt_message
			interact_prompt.visible = true
			if Input.is_action_just_pressed("interact"):
				target.interact()
	if Input.is_action_just_pressed("switch_weapon"):
		current_weapon_index = (current_weapon_index +1) % weapons.size()
		equip_weapon(current_weapon_index)
		
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
			

			
