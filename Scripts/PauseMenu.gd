
extends CanvasLayer

var paused = false

func _ready() -> void:
	# THE FIX: This tells Godot to never pause this specific node or its children
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Ensure the menu is hidden and the game is unpaused when the scene loads
	visible = false
	get_tree().paused = false

func toggle_pause_menu():
	paused = !paused 
	get_tree().paused = paused
	
	if paused:
		visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# Using event.is_action_pressed is slightly cleaner inside _input()
	if event.is_action_pressed("esc"):
		toggle_pause_menu()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_settings_button_pressed() -> void:
	pass # Replace with function body.

func _on_resume_button_pressed() -> void:
	toggle_pause_menu()


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://MainMenu/MainMenu.tscn")
