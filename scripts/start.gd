extends CanvasLayer

func _ready():
	# Optionnel : masquer la souris si tu veux un style arcade, 
	# mais garde-la pour un menu !
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Connecté au signal pressed() de ButtonStart
func _on_button_start_pressed():
	# Remplace "GameScene.tscn" par le nom de ta scène de jeu
	prints("LOLL P")
	get_tree().change_scene_to_file("res://scenes/main_scene.tscn")

# Connecté au signal pressed() de ButtonExit
func _on_button_exit_pressed():
	# Ferme le jeu
	get_tree().quit()
