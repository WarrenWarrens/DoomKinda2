extends CanvasLayer


@onready var armour = $MarginContainer/Stats/Values/ArmourValue
@onready var health = $MarginContainer/Stats/Values/HealthValue
@onready var ammo = $MarginContainer/Stats/Ammo/AmmoValue
@onready var stamina = $MarginContainer/Stats/Ammo/StaminaValue
@onready var battlestamina = $MarginContainer/Stats/Ammo/BattleStaminaValue

func _process(delta):
	armour.text = PlayerStats.get_armour()
	health.text = PlayerStats.get_health()
	stamina.text = PlayerStats.get_stamina()
	battlestamina.text = PlayerStats.get_battlestamina()
	ammo.text = PlayerInventory.get_pistol_ammo()
	
