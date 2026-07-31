extends StaticBody3D

@export var prompt_message: String = "Hang from Ledge"
@export var is_x_axis_ledge: bool = false
@export var can_climb: bool = true

func get_ledge_axis() -> Vector3:
	if is_x_axis_ledge:
		return Vector3(1,0,0)
	else:
		return Vector3(0,0,1)
		
func get_can_climb() -> bool:
	return can_climb
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
