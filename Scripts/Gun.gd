extends Node3D

@onready var gun_sprite = $CanvasLayer/Control/WeaponSprite
@onready var gun_rays =$GunRays.get_children()
@onready var flash = preload("res://Scenes/muzzle_flash.tscn")

var can_shoot = true
var damage = 8

func _ready() -> void:
	gun_sprite.play("Idle")
	pass # Replace with function body.
	
func check_hit():
	for ray in gun_rays:
		if ray.is_colliding():
			if ray.is_colliding().is_in_group("Enemy"):
				ray.get_collider().take_damage(damage)
	pass
	
func make_flash():
	var f = flash.instantiate()
	add_child(f)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("shoot") and can_shoot and PlayerInventory.ammo_pistol > 0:
		gun_sprite.play("Attack")
		make_flash()
		check_hit()
		PlayerInventory.change_pistol_ammo(-1)
		can_shoot = false
		
		await(gun_sprite.animation_finished)
		can_shoot = true
		gun_sprite.play("Idle")
		
	pass
