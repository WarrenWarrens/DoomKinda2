extends Node
#Player variables

#/////////////////////////////////////////////////////////////

var health = 100
var max_health = 200

var armour = 0
var max_armour = 100

var stamina = 100
var max_stamina = 100
var stamina_regen = 15

var battlestamina = 100
var max_battlestamina = 100
var battlestamina_regen = 15

var action = true


var canregen = false
var regenwait = 2.0
var r_timer = 0
var start_r_timer = false

#/////////////////////////////////////////////////////////////

var luck = 1
var inteligence = 1
var guts = 1
var agility = 1
var strength = 1
var endurance = 1

#/////////////////////////////////////////////////////////////

#standing, crouch, prone, stalk, fake, 
var is_stealth = false


#/////////////////////////////////////////////////////////////


func reset():
	var health = 100
	var max_health = 200
	var armour = 0
	var max_armour = 100
	var stamina = 100
	var max_stamina = 100
	var stamina_regen = 15
	
	var battlestamina = 100
	var max_battlestamina = 100
	var battlestamina_regen = 15
	
	var is_stealth = false
	var canregen = true

	
#/////////////////////////////////////////////////////////////


func _ready():
	pass
	
#/////////////////////////////////////////////////////////////
	
func take_damage(amount):
	var tmp = amount
	if amount > armour:
		amount = amount - armour
		armour = 0
	else:
		change_armour(-amount)
		return
	###apply remaining damage to health
	change_health(-amount)
		
#/////////////////////////////////////////////////////////////

func change_health(amount):
	health += amount
	health = clamp(health, 0, max_health)
	
func change_armour(amount):
	armour += amount
	armour = clamp(armour,0,max_armour)
	
func change_stamina(amount):
	stamina += amount
	stamina = clamp(stamina,0,max_stamina)
	
func change_battlestamina(amount):
	battlestamina += amount
	battlestamina = clamp(battlestamina,0,max_battlestamina)
	
func change_action(value):
	if value == 1:
		action = true
	elif value == 0:
		action = false
	
#/////////////////////////////////////////////////////////////

func get_health():
	return str(health)

func get_armour():
	return str(armour)
	
func get_stamina():
	return str(stamina)
	
func get_battlestamina():
	return str(battlestamina)
	
func get_action():
	return action
	
#/////////////////////////////////////////////////////////////

func change_stealth():
	if is_stealth == false:
		is_stealth = true
	else:
		is_stealth = false
		
func get_stealth():
	return is_stealth

#
#func staminausage():
	#canregen = false
	#regenstamina
#func _damage_player()
#
#--- can_passive_heal = false
#
#--- ## Damage code goes here
#
#--- regenHealthTimer.start()
#
#-
#
#-
#
#- func _on_passiveHealtimer_timeout():
#
#--- can_regen_health = true
#
#--- _regen_health()
#
#-
#
#-
#
#- func _regen_health():
#
#--- If player_health < regen_cap and can_regen_health == true:
#
#--- --- player_health += regen_increment
#
#--- --- yield(get_tree.create_timer(regen_rate, "timeout")
#
#--- ---_regen_health() 
