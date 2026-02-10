# Dans votre script de bouton
extends Button

func _ready():
	connect("pressed", _on_pressed)

func _on_pressed():
	print("Rechargement de la scène...")
	
	# Obtenir le chemin de la scène actuelle
	var current_scene_path = get_tree().current_scene.scene_file_path
	
	if current_scene_path:
		# Recharger la scène
		get_tree().change_scene_to_file(current_scene_path)
	else:
		print("Erreur: Impossible de trouver le chemin de la scène actuelle")
