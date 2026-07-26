extends Node3D

var canregen = false
var regenwait = 2.0
var r_timer = 0
var start_r_timer = false
var action = PlayerStats.get_action()

var stamina = int(PlayerStats.get_battlestamina())

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if action == true:
		if canregen == false && stamina != 100 or stamina == 0:
			start_r_timer = true
			if start_r_timer == true:
				r_timer += delta
				if r_timer >= regenwait:
					canregen = true
					start_r_timer = false
					r_timer = 0
					
		if stamina == 100:
			canregen = false
			
		if canregen == true:
			PlayerStats.change_battlestamina(2)
			start_r_timer = false
			r_timer = 0
		
	pass
