extends CharacterBody3D

# --- Movement Variables ---
const WALK_SPEED: float = 7.0
const SPRINT_SPEED: float = 14.0
const CROUCH_SPEED: float = 3.5
const MOUSE_SENS: float = 0.002
const PRONE_SPEED: float = 1.5
const JUMP_VELOCITY: float = 6.0
var is_in_air: bool = false
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
# --- Camera Dynamics ---
# Strafe Tilt
const TILT_AMOUNT: float = 0.03
const TILT_SPEED: float = 6.0

# Head Bobbing
const BOB_FREQ: float = 2.4
const BOB_AMP: float = 0.06
var t_bob: float = 0.0

# FOV Punch
var fov_punch: float = 0.0

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
@onready var ammo_label = $HUD/MarginContainer/Stats/Ammo2/AmmoLabel
@onready var speed_label = $HUD/SpeedLabel
@onready var state_label = $HUD/StateLabel

@onready var right_dom_hand = PlayerStats.get_dom_hand()


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
var ledge_normal: Vector3 = Vector3.ZERO

var pull_up_released: bool = true
var pull_up_progress: float = 0.0
var pull_up_counted: bool = false
const PULL_UP_COST: float = 20.0
const PULL_UP_SPEED: float = 1.5

var push_up_released: bool = true
var push_up_progress: float = 0.0
var push_up_counted: bool = false
const PUSH_UP_COST: float = 20.0
const PUSH_UP_SPEED: float = 1.5

var sit_up_released: bool = true
var sit_up_progress: float = 0.0
var sit_up_counted: bool = false
const SIT_UP_COST: float = 20.0
const SIT_UP_SPEED: float = 1.5



var ledge_can_climb: bool = false

#Ladder
var is_on_ladder: bool = false
var ladder_normal: Vector3 = Vector3.ZERO
const LADDER_SPEED: float = 4.0
const LADDER_DRAIN_RATE: float = 4.0
const TRAVERSE_COST: float = 15.0
var current_climb_target: Node3D = null

var holding_left_hand: bool = true
var holding_right_hand: bool = true
const ONE_HAND_DRAIN_MULT: float = 1.75 # Drains 75% faster when using one hand!

var is_wall_running: bool = false
var wall_normal: Vector3 = Vector3.ZERO
const WALL_RUN_SPEED: float = 12.0
const WALL_JUMP_PUSH: float = 8.0


func _ready() -> void:
	get_window().grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Save our standing dimensions so we can lerp back to them
	original_capsule_height = collision_shape.shape.height
	original_shape_y = collision_shape.position.y
	original_head_y = head.position.y
	interact_ray.add_exception(self)
	
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
	var input_dir := Input.get_vector("left", "right", "up", "down")
	if is_hanging:
		update_hand_states(ledge_normal)
		
		var current_hang_drain = HANG_DRAIN_RATE
		if not holding_left_hand or not holding_right_hand:
			if right_dom_hand:
				if not holding_left_hand:
					current_hang_drain *= ONE_HAND_DRAIN_MULT
				else:
					current_hang_drain *= (ONE_HAND_DRAIN_MULT * 1.5)
			elif not right_dom_hand:
				if not holding_right_hand:
					current_hang_drain *= ONE_HAND_DRAIN_MULT
				else:
					current_hang_drain *= (ONE_HAND_DRAIN_MULT * 1.5)
				

		
		var wants_pull_up = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	
		if not wants_pull_up:
			pull_up_released = true
			
		if wants_pull_up and pull_up_released and PlayerStats.stamina > 0 and holding_left_hand and holding_right_hand:
			if pull_up_progress < 1.0:
				pull_up_progress += delta * PULL_UP_SPEED
				PlayerStats.change_stamina(-PULL_UP_COST * delta * PULL_UP_SPEED)
			else:
				PlayerStats.change_stamina(-current_hang_drain * delta)
				
				if ledge_can_climb and Input.is_action_just_pressed("up"):
					vault_over_obstacle()
					return
		else:
			pull_up_progress -= delta * PULL_UP_SPEED
			PlayerStats.change_stamina(-current_hang_drain * delta)
			
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
			head.position.y = original_head_y
			return
			
		# Lock all horizontal movement while doing a pull-up
		if pull_up_progress > 0.0:
			velocity = Vector3.ZERO
		else:
			if Input.is_action_just_pressed("jump"):
				velocity = (ledge_normal * 8.0) + (Vector3.UP * JUMP_VELOCITY)
				stop_hanging()
				pull_up_progress = 0.0
				head.position.y = original_head_y
				return
			
			#var input_dir := Input.get_vector("left", "right", "up", "down")
			if not holding_left_hand or not holding_right_hand:
				input_dir.x = 0.0 
			
			var alignment = sign(transform.basis.x.dot(ledge_axis))
			if alignment == 0:
				alignment = 1.0
				
			var move_dir = ledge_axis * (input_dir.x * alignment)
			
			# --- Bulletproof Edge Block Check ---
			if move_dir.length() > 0:
				# FIX: Shoot from slightly lower down (0.25) so it doesn't skim the top lip
				var chest_position = global_position + Vector3(0, original_capsule_height * 0.33, 0)
				var future_chest_pos = chest_position + (move_dir * 0.80)
				
				var space_state = get_world_3d().direct_space_state
				
				# FIX: Extended ray length to 1.0 to easily cover the new gap
				var query = PhysicsRayQueryParameters3D.create(future_chest_pos, future_chest_pos - ledge_normal * 1.0)
				# FIX: Tell the ray to completely ignore the player's collision box
				query.exclude = [self.get_rid()]
				
				var result = space_state.intersect_ray(query)
				
				if result.is_empty():
					move_dir = Vector3.ZERO
				#if result.is_empty() or not result.collider.is_in_group("ledge"):
					#move_dir = Vector3.ZERO
				#if result.is_empty() or not result.collider.has_method("get_ledge_axis"):
					#move_dir = Vector3.ZERO
					
				# If the ray misses the wall entirely, block the movement input!
				#if result.is_empty() or result.collider != current_climb_target:
					#move_dir = Vector3.ZERO
					
			velocity = move_dir * HANG_SPEED
			
		move_and_slide()
		update_hud_stats() # <--- Add this right here!
		return
	# --- LADDER STATE OVERRIDE ---
	if is_on_ladder:
		# Check if we want to fast-slide down
		update_hand_states(ladder_normal)
		var current_ladder_drain = LADDER_DRAIN_RATE
		
		if not holding_left_hand or not holding_right_hand:
			current_ladder_drain *= ONE_HAND_DRAIN_MULT
		
		if Input.is_action_pressed("sprint"):
			# Move straight down at double speed with ZERO stamina drain
			velocity = Vector3.DOWN * (LADDER_SPEED * 2.0)
			move_and_slide()
			
			# Automatically let go if we hit the floor while sliding!
			if is_on_floor():
				stop_ladder()
				
			return

				
		if Input.is_action_just_pressed("jump"):
			velocity = (ladder_normal * 8.0) + (Vector3.UP * JUMP_VELOCITY)
			stop_ladder()
			return
		
		
		PlayerStats.change_stamina(-current_ladder_drain * delta)
		PlayerStats.stamina_delay_timer = STAMINA_DELAY
		

		
		# Drop if out of stamina or pressing crouch
		if PlayerStats.stamina <= 0 or Input.is_action_just_pressed("crouch"):
			stop_ladder()
			return
			
		#var input_dir := Input.get_vector("left", "right", "up", "down")
		
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
	
	is_wall_running = false
	if not is_on_floor():
		if is_on_wall() and Input.is_action_just_pressed("up") and not is_hanging and not is_on_ladder:
			var normal = get_wall_normal()
			if abs(normal.y) < 0.1:
				is_wall_running = true
				wall_normal = normal
				
				velocity.y = move_toward(velocity.y, -1.5, 15.0 * delta)
				var wall_forward = Vector3.UP.cross(wall_normal).normalized()
				if (-transform.basis.z).dot(wall_forward) < 0:
					wall_forward = -wall_forward
				velocity.x = (wall_forward.x * WALL_RUN_SPEED) - (wall_normal.x * 2.0)
				velocity.z = (wall_forward.z * WALL_RUN_SPEED) - (wall_normal.z * 2.0)
				
		if not is_wall_running:
			velocity += get_gravity() * delta

	#var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	#var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var is_moving = direction.length() > 0
	
	# 1. Determine if we are actively holding sprint (Can't sprint if crouched or prone)
	var is_sprinting = false
	if Input.is_action_pressed("sprint") and is_moving and not PlayerStats.get_stealth() and not PlayerStats.get_prone() and PlayerStats.stamina > 0 and is_on_floor():
		is_sprinting = true

	if is_on_floor():
		if Input.is_action_just_pressed("prone"):
			if PlayerStats.get_prone():
				if not ceiling_check.is_colliding():
					PlayerStats.change_prone()
			else:
				PlayerStats.change_prone()
				is_sliding = false
		if Input.is_action_just_pressed("crouch"):
			if PlayerStats.get_stealth():
				if not ceiling_check.is_colliding():
					PlayerStats.change_stealth()
					is_sliding = false
			elif PlayerStats.get_prone():
				if not ceiling_check.is_colliding():
					PlayerStats.change_stealth()
			else:
				PlayerStats.change_stealth()
				if is_sprinting and is_on_floor():
					is_sliding = true
	## --- 2. Crouch, Prone & Slide Trigger Logic ---
	#if Input.is_action_just_pressed("prone"):
		#if PlayerStats.get_prone():
			## Trying to stand up from prone
			#if not ceiling_check.is_colliding():
				#PlayerStats.change_prone()
		#else:
			## Going into prone (Belly flop!)
			#PlayerStats.change_prone()
			#is_sliding = false 
#
	#if Input.is_action_just_pressed("crouch"):
		#if PlayerStats.get_stealth():
			## Trying to stand up
			#if not ceiling_check.is_colliding():
				#PlayerStats.change_stealth()
				#is_sliding = false 
		#elif PlayerStats.get_prone():
			## Trying to rise from Prone to Crouch
			#if not ceiling_check.is_colliding():
				#PlayerStats.change_stealth()
		#else:
			## Trying to crouch from standing
			#PlayerStats.change_stealth()
			#if is_sprinting and is_on_floor():
				#is_sliding = true

	var is_crouching = PlayerStats.get_stealth()
	var is_prone = PlayerStats.get_prone()
	
	var standing_height = original_capsule_height
	var crouch_height = (standing_height * 0.50) -0.2 # 50% height (5 blocks)
	var prone_height = (standing_height * 0.30) -0.2 # 30% height (3 blocks)

	var target_height = standing_height
	var shape_y_offset = 0.0
	var head_y_offset = 0.0
	
	if is_prone:
		target_height = prone_height
		shape_y_offset = (standing_height - prone_height) / 2.0
		head_y_offset = standing_height - prone_height # Camera moves the full distance!
	elif is_crouching:
		target_height = crouch_height
		shape_y_offset = (standing_height - crouch_height) / 2.0
		head_y_offset = standing_height - crouch_height # Camera moves the full distance!
		
	var target_shape_y = original_shape_y - shape_y_offset
	var target_head_y = original_head_y - head_y_offset
	
	collision_shape.shape.height = lerp(collision_shape.shape.height, target_height, delta * 15.0)
	collision_shape.position.y = lerp(collision_shape.position.y, target_shape_y, delta * 15.0)
	head.position.y = lerp(head.position.y, target_head_y, delta * 15.0)
	# --- Capsule Height Lerping ---

	# --- 3. Dodge Logic ---
	if is_dodging:
		dodge_timer -= delta
		if dodge_timer <= 0:
			is_dodging = false

	var valid_dodge_dir = input_dir.x != 0 or input_dir.y > 0 
	# Can't dodge while crouching OR prone
	if Input.is_action_just_pressed("dodge") and not is_dodging and not is_crouching and not is_prone and valid_dodge_dir and PlayerStats.stamina >= DODGE_COST and is_on_floor():
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
	var current_horiz_speed = Vector2(velocity.x, velocity.z).length()
	var target_fov = SPRINT_FOV if (is_sprinting or is_sliding) else BASE_FOV
	camera.fov = lerp(camera.fov, target_fov, delta * FOV_TRANS_SPEED)
	
	if Input.is_action_just_pressed("dodge") and valid_dodge_dir and PlayerStats.stamina >= DODGE_COST:
		fov_punch = 10.0 # Bumps the camera out instantly

	target_fov += fov_punch
	fov_punch = lerp(fov_punch, 0.0, delta * 5.0) # Quickly fade the punch away
	camera.fov = lerp(camera.fov, target_fov, delta * FOV_TRANS_SPEED)
	
	var target_tilt = 0.0
	
	if is_wall_running:
		var right_dot = transform.basis.x.dot(wall_normal)
		if right_dot > 0:
			target_tilt = 0.25
		else:
			target_tilt = -0.25
	elif not is_hanging and not is_on_ladder:
		target_tilt = input_dir.x * -TILT_AMOUNT
		
	if not is_hanging and not is_on_ladder:
		target_tilt = input_dir.x * -TILT_AMOUNT
	camera.rotation.z = lerp(camera.rotation.z, target_tilt, delta * TILT_SPEED)
	
	if is_on_floor() and current_horiz_speed > 1.0 and not is_sliding:
		t_bob += delta * current_horiz_speed
	else:
		# Smoothly return to center when stopping or in the air
		t_bob = 0.0
		
	var target_camera_pos = _calculate_headbob(t_bob)
	# Lerp the transform origin so it smoothly transitions in and out of the bob
	camera.transform.origin = camera.transform.origin.lerp(target_camera_pos, delta * 10.0)
		
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
			
		if current_horiz_speed <= CROUCH_SPEED:
			is_sliding = false
			
	else:
		# Determine speed based on our current state hierarchy
		var current_speed = WALK_SPEED
		if is_sprinting: current_speed = SPRINT_SPEED
		elif is_prone: current_speed = PRONE_SPEED
		elif is_crouching: current_speed = CROUCH_SPEED
		
		if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching and not is_prone and not is_dodging:
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
			elif is_wall_running:
				velocity = (wall_normal * WALL_JUMP_PUSH) + (Vector3.UP * JUMP_VELOCITY)
				is_wall_running = false
				
		if is_on_floor():
			if direction:
				velocity.x = direction.x * current_speed
				velocity.z = direction.z * current_speed
			else:
				velocity.x = move_toward(velocity.x, 0, current_speed)
				velocity.z = move_toward(velocity.z, 0, current_speed)
		elif not is_wall_running:
			if direction:
				velocity.x = lerp(velocity.x,direction.x * current_speed, delta * 3.0)
				velocity.z = lerp(velocity.z,direction.z * current_speed, delta * 3.0)


	move_and_slide()
	update_hud_stats()
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var yaw_change = -event.relative.x * MOUSE_SENS
		
		# --- Camera Restriction During Pull-up ---
		if is_hanging and pull_up_progress > 0.0:
			# Preview what our rotation would be if we allowed the mouse movement
			var future_basis = transform.basis.rotated(Vector3.UP, yaw_change)
			var future_forward = -future_basis.z
			
			# If the turn pushes us beyond the 60-degree threshold, block the turn!
			if future_forward.dot(ledge_normal) > -0.5:
				yaw_change = 0.0 
				
		# Apply the horizontal turn
		rotate_y(yaw_change)

		# Apply the vertical head look (pitch)
		head.rotate_x(-event.relative.y * MOUSE_SENS)
		head.rotation.x = clamp(head.rotation.x, -1.2, 1.2)
		
#func _unhandled_input(event: InputEvent) -> void:
	#if event is InputEventMouseMotion:
		#rotate_y(-event.relative.x * MOUSE_SENS)
		#head.rotate_x(-event.relative.y * MOUSE_SENS)
		#head.rotation.x = clamp(head.rotation.x, -1.2, 1.2)

func _process(_delta: float) -> void:
	if is_hanging or is_on_ladder:
		
		interact_ray.target_position.z = -8.0 # Long reach for leaping
	else:
		interact_ray.target_position.z = -4.0 # Standard reach for ground interaction
	# 1. Default state: hide the prompt
	interact_prompt.visible = false
	
	# 2. Raycast Interaction Logic
	# 2. ShapeCast Interaction Logic
	
	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		
		if target != null:
			# Grab the normal and point immediately for filtering
			var hit_point = interact_ray.get_collision_point()
			var hit_normal = interact_ray.get_collision_normal()
			
			if is_hanging or is_on_ladder:
				if hit_point.distance_to(camera.global_position) < 2.0:
					return
			
				
			var is_vertical_face = abs(hit_normal.y) < 0.05
			
			# --- FACE FILTERING MATH ---
			# 1. Is the face completely vertical? (Rejects tops and bottoms)
			var player_forward = -camera.global_transform.basis.z
			var is_facing_surface = hit_normal.dot(player_forward) < 0.5
			# 2. Is the player generally looking AT the face? (Rejects side-glancing)
			
			# ---------------------------

			# --- Ledge Logic ---
			# Added our two new face filtering checks here!
			if target.has_method("get_ledge_axis") and is_vertical_face and is_facing_surface:
				var is_traversing = is_hanging or is_on_ladder
				
				interact_prompt.text = "[E] Leap to Ledge" if is_traversing else "[E] " + target.prompt_message
				interact_prompt.visible = true
				
				if Input.is_action_just_pressed("interact"):
					if is_traversing:
						if PlayerStats.stamina >= TRAVERSE_COST:
							PlayerStats.change_stamina(-TRAVERSE_COST)
							PlayerStats.stamina_delay_timer = STAMINA_DELAY
							is_hanging = false 
							is_on_ladder = false
							start_hanging(target, target.get_ledge_axis(), hit_point, hit_normal, target.get_can_climb())
					else:
						start_hanging(target, target.get_ledge_axis(), hit_point, hit_normal, target.get_can_climb())
						
			# --- Ladder Logic ---
			# Ladders also benefit from the face filtering checks!
			elif target.has_method("get_is_ladder") and is_vertical_face and is_facing_surface:
				var is_traversing = is_hanging or is_on_ladder
				
				interact_prompt.text = "[E] Leap to Ladder" if is_traversing else "[E] " + target.prompt_message
				interact_prompt.visible = true
				
				if Input.is_action_just_pressed("interact"):
					if is_traversing:
						if PlayerStats.stamina >= TRAVERSE_COST:
							PlayerStats.change_stamina(-TRAVERSE_COST)
							PlayerStats.stamina_delay_timer = STAMINA_DELAY
							is_hanging = false
							is_on_ladder = false
							start_ladder(target, hit_normal, hit_point)
					else:
						start_ladder(target, hit_normal, hit_point)

			# --- Door / Object Logic ---
			elif target.has_method("interact") and not is_hanging and not is_on_ladder:
				interact_prompt.text = "[E] " + target.prompt_message
				interact_prompt.visible = true
				if Input.is_action_just_pressed("interact"):
					target.interact()
					
	# 3. Weapon Switching Logic
	if Input.is_action_just_pressed("switch_weapon") and not is_hanging and not is_on_ladder:
		current_weapon_index = (current_weapon_index + 1) % weapons.size()
		equip_weapon(current_weapon_index)

func start_hanging(target: Node3D, axis: Vector3, hit_point: Vector3, hit_normal: Vector3, can_climb_flag: bool) -> void:
	is_hanging = true
	current_climb_target = target # Save the target!

	var auto_axis = Vector3.UP.cross(hit_normal)
	if auto_axis.length() < 0.01:
		ledge_axis = axis
	else:
		ledge_axis = auto_axis.normalized()

	ledge_can_climb = can_climb_flag
	ledge_normal = hit_normal 
	
	pull_up_progress = 0.0 
	velocity = Vector3.ZERO
	pull_up_released = false # <--- Add this! Forces them to let go first
	
	PlayerStats.change_action(0)
	
	if PlayerStats.get_stealth(): PlayerStats.change_stealth()
	if PlayerStats.get_prone(): PlayerStats.change_prone()
	is_sliding = false
	is_dodging = false
	
	# --- TOP LIP SNAPPING ---
	# Shoot a ray down from slightly inside the wall, starting high above the player
	var space_state = get_world_3d().direct_space_state
	var lip_check_start = hit_point - (hit_normal * 0.1)
	lip_check_start.y = hit_point.y + 1.2
	var query = PhysicsRayQueryParameters3D.create(lip_check_start, lip_check_start + (Vector3.DOWN * 2.0))
	query.exclude = [self.get_rid()]
	var result = space_state.intersect_ray(query)
	
	var final_hang_y = hit_point.y
	if not result.is_empty():
		final_hang_y = result.position.y # We found the exact top of the box!
	
	global_position = Vector3(hit_point.x, final_hang_y, hit_point.z) + (hit_normal * 0.6) - Vector3(0, original_capsule_height * 0.85, 0)

	var look_target = global_position - hit_normal
	look_target.y = global_position.y
	look_at(look_target, Vector3.UP)
	head.rotation.x = 0
	
	hide_current_weapon()
	
	
func stop_hanging() -> void:
	is_hanging = false
	holding_left_hand = true
	holding_right_hand = true
	current_climb_target = null 
	PlayerStats.change_action(1)
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
				ammo_label.visible = true
			else:
				ammo_counter.visible = false
				ammo_label.visible = false

		else:
			weapons[i].visible = false
			weapons[i].set_process(false)
			weapons[i].set_physics_process(false)
			
			if weapons[i].has_node("CanvasLayer"):
				weapons[i].get_node("CanvasLayer").visible = false
			

func hide_current_weapon() -> void:
	var w = weapons[current_weapon_index]
	w.visible = false
	w.set_process(false)
	w.set_physics_process(false)
	
	if w.has_node("CanvasLayer"):
		w.get_node("CanvasLayer").visible = false
		
	ammo_counter.visible = false
	ammo_label.visible = false
	
			
func vault_over_obstacle() -> void:
	var forward_dir = -transform.basis.z 
   
	global_position += Vector3(0, original_capsule_height * 0.9, 0) + (forward_dir * 1.2)
	
	stop_hanging()
	stop_ladder()
	
	pull_up_progress = 0.0
	head.position.y = original_head_y

func start_ladder(target: Node3D, hit_normal: Vector3, hit_point: Vector3) -> void:
	
	is_on_ladder = true
	current_climb_target = target # Save the target!
	ladder_normal = hit_normal
	pull_up_progress = 0.0
	velocity = Vector3.ZERO
	PlayerStats.change_action(0) 
	
	if PlayerStats.get_stealth(): PlayerStats.change_stealth()
	if PlayerStats.get_prone(): PlayerStats.change_prone()
	is_sliding = false
	is_dodging = false

	# Teleport to the ladder so mid-air leaps connect perfectly!
	# (Using a slightly different offset than ledges so the player centers on the rungs)
	global_position = hit_point + (hit_normal * 0.6) - Vector3(0, original_capsule_height * 0.75, 0)

	var look_target = global_position - ladder_normal
	look_target.y = global_position.y
	look_at(look_target, Vector3.UP)
	head.rotation.x = 0
	hide_current_weapon() # <--- Add this at the end of the function!

	


func stop_ladder() -> void:
	is_on_ladder = false
	holding_left_hand = true
	holding_right_hand = true
	current_climb_target = null
	PlayerStats.change_action(1)
	equip_weapon(current_weapon_index)

func update_hud_stats() -> void:
	# 1. Calculate horizontal speed (ignoring gravity/falling speed)
	var current_speed = Vector2(velocity.x, velocity.z).length()
	
	# Format the string so it only shows 1 decimal place (e.g., "14.0")
	speed_label.text = "Speed: %.1f" % current_speed
	
	# 2. Determine the current state based on your hierarchy
	var current_state = "Standing"
	
	if is_hanging:
		current_state = "Hanging"
	elif is_on_ladder:
		current_state = "Climbing"
	elif is_sliding:
		current_state = "Sliding"
	elif is_dodging:
		current_state = "Dodging"
	elif PlayerStats.get_prone():
		current_state = "Prone"
	elif PlayerStats.get_stealth():
		current_state = "Crouched"
	elif Input.is_action_pressed("sprint") and current_speed > WALK_SPEED:
		# Only say sprinting if they are actually moving fast enough
		current_state = "Sprinting" 
	if is_hanging or is_on_ladder:
		if not holding_right_hand:
			current_state += " (Left Hand Only)"
		elif not holding_left_hand:
			current_state += " (Right Hand Only)"
		else:
			current_state += " (Both Hands)"
		
	state_label.text = "State: " + current_state
	
func update_hand_states(wall_normal: Vector3) -> void:
	var look_dot = (-transform.basis.z).dot(wall_normal)
	var right_dot = transform.basis.x.dot(wall_normal)
	
	# -1.0 means looking dead at the wall. 
	# > -0.5 means looking more than 60 degrees away (over a shoulder).
	if look_dot > -0.5:
		if right_dot > 0:
			# Looking right (over right shoulder) -> right hand lets go, left holds!
			holding_left_hand = true
			holding_right_hand = false
		else:
			# Looking left (over left shoulder) -> left hand lets go, right holds!
			holding_left_hand = false
			holding_right_hand = true
	else:
		# Looking generally forward -> both hands on the wall
		holding_left_hand = true
		holding_right_hand = true

func _calculate_headbob(time: float) -> Vector3:
	var bob_pos = Vector3.ZERO
	# Up and down movement
	bob_pos.y = sin(time * BOB_FREQ) * BOB_AMP
	# Left and right sway (half frequency for the figure-eight shape)
	bob_pos.x = cos(time * BOB_FREQ / 2.0) * BOB_AMP
	return bob_pos
