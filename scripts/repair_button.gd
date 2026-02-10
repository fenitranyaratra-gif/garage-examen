# Un script simple pour gérer la visibilité
extends Button

func _process(_delta):
	var show_button = false
	
	# Vérifier tous les parkings
	for slot in get_tree().get_nodes_in_group("parking_slots"):
		if slot and slot.is_parked:
			show_button = true
			break
	
	visible = show_button
	disabled = !show_button
