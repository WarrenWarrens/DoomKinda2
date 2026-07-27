
extends Node3D

@onready var weapon_sprite = $CanvasLayer/Control/WeaponSprite
@onready var gun_rays = $GunRays.get_children()

var can_attack = PlayerStats.get_action()

const B_STAMINA_COST: float = 25.0
const REGEN_DELAY: float = 1.5

func _ready() -> void:
	weapon_sprite.play("Idle")
	
func check_hit():
	pass

func _process(delta: float) -> void:
	# --- Desperation Attack Math ---
	var available_b = PlayerStats.battlestamina
	var available_s = PlayerStats.stamina
	
	var deficit = max(0.0, B_STAMINA_COST - available_b)
	# We can attack if we have 0 deficit, OR enough regular stamina to cover 2x the missing amount
	var can_afford = (deficit == 0) or (available_s >= (deficit * 2.0))
	
	if Input.is_action_just_pressed("shoot") and can_attack and can_afford:
		weapon_sprite.play("Attack")
		check_hit()
		
		# Apply the stamina costs
		if deficit > 0:
			PlayerStats.change_battlestamina(-available_b) # Drain remaining b_stamina to 0
			PlayerStats.change_stamina(-(deficit * 2.0))   # Drain 2x the deficit from regular stamina
			PlayerStats.stamina_delay_timer = REGEN_DELAY  # Pause regular stamina regen
		else:
			PlayerStats.change_battlestamina(-B_STAMINA_COST)
			
		PlayerStats.b_stamina_delay_timer = REGEN_DELAY # Pause b_stamina regen
		
		can_attack = false
		PlayerStats.change_action(0)
		
		await(weapon_sprite.animation_finished)
		
		can_attack = true
		PlayerStats.change_action(1)
		weapon_sprite.play("Idle")
