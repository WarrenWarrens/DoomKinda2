extends StaticBody3D

@export var prompt_message: String = "Climb"

func get_is_ladder() -> bool:
	return true
	
#func _ready() -> void:
	#self.visible = false # Turns the mesh invisible, but keeps the collision box!



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
