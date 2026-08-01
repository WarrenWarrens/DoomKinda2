extends StaticBody3D

@export var prompt_message: String = "Hang from Ledge"

# Notice there is no ": int" or ": String" here! 
# These are now Variants, so FuncGodot can safely inject whatever it wants.
@export var is_x_axis_ledge = 1
@export var can_climb = 1

func get_ledge_axis() -> Vector3:
	if str(is_x_axis_ledge) == "1" or str(is_x_axis_ledge) == "true":
		return Vector3(1, 0, 0)
	else:
		return Vector3(0, 0, 1)

func get_can_climb() -> bool:
	return str(can_climb) == "1" or str(can_climb) == "true"
