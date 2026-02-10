# NavBar.gd
extends Control

signal menu_selected(item_name: String)

func _ready():
	# Connecter les boutons
	for child in get_children():
		if child is Button:
			child.connect("pressed", _on_button_pressed.bind(child.name))

func _on_button_pressed(button_name: String):
	menu_selected.emit(button_name)
	print("Menu sélectionné:", button_name)
