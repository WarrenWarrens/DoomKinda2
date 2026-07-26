extends Node3D

@onready var weapon_sprite = $CanvasLayer/Control/WeaponSprite
@onready var gun_rays =$GunRays.get_children()

var can_attack = PlayerStats.get_action()
var damage = 8
var regentime = 2
var rtimer = 0

func _ready() -> void:
	weapon_sprite.play("Idle")
	pass # Replace with function body.
	
func check_hit():
	pass
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("shoot") and can_attack and PlayerStats.battlestamina >= 10:
		weapon_sprite.play("Attack")
		check_hit()
		rtimer = 0
		PlayerStats.change_battlestamina(-10)
		can_attack = false
		PlayerStats.change_action(0)
		
		await(weapon_sprite.animation_finished)
		can_attack = true
		PlayerStats.change_action(1)
		weapon_sprite.play("Idle")
		
	if can_attack == true && rtimer < 50:
		rtimer += delta
	elif can_attack == true:
		PlayerStats.change_battlestamina(5)
	pass
