
extends Node3D

@onready var weapon_sprite = $CanvasLayer/Control/KickSprite
# Since kicking doesn't use gun rays, you can remove that variable if you don't need it

var can_attack = true

const B_STAMINA_COST: float = 25.0
const REGEN_DELAY: float = 1.5

func _ready() -> void:
	weapon_sprite.play("Idle")
	
func _exit_tree() -> void:
	PlayerStats.change_action(1)
	
func check_hit():
	pass

# THIS WAS MISSING: We need this so the game checks for the input every frame!
func _process(_delta: float) -> void:
	# Always read the global action state so the kick knows if we are busy
	can_attack = PlayerStats.get_action()
	
	# --- Desperation Attack Math ---
	var available_b = PlayerStats.battlestamina
	var available_s = PlayerStats.stamina
	
	var deficit = max(0.0, B_STAMINA_COST - available_b)
	var can_afford = (deficit == 0) or (available_s >= (deficit * 2.0))
	
	# We use "kick" instead of "shoot"
	if Input.is_action_just_pressed("kick") and can_attack and can_afford:
		weapon_sprite.play("Kick")
		check_hit()
		
		# Apply the stamina costs
		if deficit > 0:
			PlayerStats.change_battlestamina(-available_b) 
			PlayerStats.change_stamina(-(deficit * 2.0))   
			PlayerStats.stamina_delay_timer = REGEN_DELAY  
		else:
			PlayerStats.change_battlestamina(-B_STAMINA_COST)
			
		PlayerStats.b_stamina_delay_timer = REGEN_DELAY 
		
		# Lock global actions so we can't shoot our gun while kicking!
		PlayerStats.change_action(0) 
		
		await weapon_sprite.animation_finished
		
		# Unlock global actions
		PlayerStats.change_action(1)
		weapon_sprite.play("Idle")
