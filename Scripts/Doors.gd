extends StaticBody3D

@export var prompt_message: String = "Enter Door"
@export_file("*.tscn") var next_scene_path: String

func interact() -> void:
	if next_scene_path != "":
		get_tree().change_scene_to_file(next_scene_path)
	else:
		print("No scene path assigned to this door yet lmao")
		

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
