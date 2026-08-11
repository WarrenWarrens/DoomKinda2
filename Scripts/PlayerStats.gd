extends Node
#Player variables

#/////////////////////////////////////////////////////////////

var health = 100
var max_health = 200

var armour = 25
var max_armour = 100

var stamina = 1000.0
var max_stamina = 1000.0
var stamina_regen = 150.0
var stamina_delay_timer: float = 0.0
var current_stamina_regen: float = 0.0



var battlestamina = 100
var max_battlestamina = 100
var battlestamina_regen = 15
var b_stamina_delay_timer: float = 0.0
var current_b_stamina_regen: float = 0.0


var action = true
var right_hand_dom: bool = true


#var canregen = false
#var regenwait = 2.0
#var r_timer = 0
#var start_r_timer = false

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
var is_prone = false


#/////////////////////////////////////////////////////////////


func reset():
	health = 100
	max_health = 200
	armour = 0
	max_armour = 100
	stamina = 100
	max_stamina = 100
	stamina_regen = 15
	
	battlestamina = 100
	max_battlestamina = 100
	battlestamina_regen = 15
	
	is_stealth = false
	#canregen = true

	
#/////////////////////////////////////////////////////////////


func _ready():
	pass
	
#/////////////////////////////////////////////////////////////
	
#func take_damage(amount):
	#var tmp = amount
	#if amount > armour:
		#amount = amount - armour
		#armour = 0
	#else:
		#change_armour(-amount)
		#return
	####apply remaining damage to health
	#change_health(-amount)
		
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
	return str(int(stamina))
	
func get_battlestamina():
	return str(int(battlestamina))
	
func get_action():
	return action
	
#/////////////////////////////////////////////////////////////

#func change_stealth():
	#if is_stealth == false:
		#is_stealth = true
	#else:
		#is_stealth = false
		
func get_stealth():
	return is_stealth

func change_prone():
	is_prone = !is_prone
	if is_prone:
		is_stealth = false # Cancel crouch if we go prone

# Update your existing change_stealth function to match this:
func change_stealth():
	is_stealth = !is_stealth
	if is_stealth:
		is_prone = false # Cancel prone if we crouch

func get_prone():
	return is_prone
	
func get_dom_hand():
	return right_hand_dom

func _process(delta: float) -> void:
	# 1. Regular Stamina Regen
	if stamina_delay_timer > 0:
		stamina_delay_timer -= delta
		current_stamina_regen = 0.0 # Reset the gradual ramp-up
	elif stamina < max_stamina:
		# 1.5x multiplier if crouching/stealth
		var stealth_mult = 1.5 if is_stealth else 1.0 
		# Lerp creates a smooth acceleration curve
		current_stamina_regen = lerp(current_stamina_regen, stamina_regen * stealth_mult, delta * 2.0)
		change_stamina(current_stamina_regen * delta)

	# 2. Battle Stamina Regen
	if b_stamina_delay_timer > 0:
		b_stamina_delay_timer -= delta
		current_b_stamina_regen = 0.0
	elif battlestamina < max_battlestamina:
		var stealth_mult = 1.5 if is_stealth else 1.0
		current_b_stamina_regen = lerp(current_b_stamina_regen, battlestamina_regen * stealth_mult, delta * 2.0)
		change_battlestamina(current_b_stamina_regen * delta)
		
var total_pull_ups = 0

func add_pull_up():
	total_pull_ups += 1
	print("Pull ups completed: ", total_pull_ups)
