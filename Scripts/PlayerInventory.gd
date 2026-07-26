extends Node

var guns_carried = []
var ammo_pistol = 50
var ammo_rocket = 0
var ammo_shells = 0
var ammo_plasma = 0
var ammo_max_pistol = 200
var ammo_max_rocket = 50
var ammo_max_shells = 100
var ammo_max_plasma = 200

var red_key = false
var blue_key = false
var yellow_key = false
var current_gun = "Pistol"


func reset():
	var guns_carried = []
	var ammo_pistol = 50
	var ammo_rocket = 0
	var ammo_shells = 0
	var ammo_plasma = 0
	var ammo_max_pistol = 200
	var ammo_max_rocket = 50
	var ammo_max_shells = 100
	var ammo_max_plasma = 200
	var red_key = false
	var blue_key = false
	var yellow_key = false
	var current_gun = "Pistol"

func change_pistol_ammo(amount):
	ammo_pistol+=amount
	ammo_pistol = clamp(ammo_pistol,0,ammo_max_pistol)
	
func change_shotgun_ammo(amount):
	ammo_shells+=amount
	ammo_shells = clamp(ammo_shells,0,ammo_max_shells)
	
func change_rocket_ammo(amount):
	ammo_rocket+=amount
	ammo_rocket = clamp(ammo_rocket,0,ammo_max_rocket)
	
func change_plasma_ammo(amount):
	ammo_plasma+=amount
	ammo_plasma = clamp(ammo_plasma,0,ammo_max_plasma)
	
func get_pistol_ammo():
	return str(ammo_pistol)

func get_shotgun_ammo():
	return str(ammo_shells)

func get_rocket_ammo():
	return str(ammo_rocket)
	
func get_plasma_ammo():
	return str(ammo_plasma)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
