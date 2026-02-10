# SuperSimpleFinishZone.gd
extends Area2D

func _ready():
	# On connecte les signaux
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("SuperSimpleFinishZone prêt!")

func _on_body_entered(body: Node2D):
	print("Quelque chose est entré: ", body.name)
	
	# On va chercher TOUTES les voitures dans le jeu
	var all_cars = get_tree().get_nodes_in_group("voiture_principale")
	
	for car in all_cars:
		print("  - On force l'affichage du bouton pour: ", car.name)
		# On force le bouton à s'afficher
		if car.has_method("montrer_bouton_finir"):
			car.montrer_bouton_finir()
		elif car.has_method("show_finish_button"):
			car.show_finish_button()

func _on_body_exited(body: Node2D):
	print("Quelque chose est sorti: ", body.name)
	
	# On va chercher TOUTES les voitures dans le jeu
	var all_cars = get_tree().get_nodes_in_group("voiture_principale")
	
	for car in all_cars:
		print("  - On cache le bouton pour: ", car.name)
		# On force le bouton à se cacher
		if car.has_method("cacher_bouton_finir"):
			car.cacher_bouton_finir()
		elif car.has_method("hide_finish_button"):
			car.hide_finish_button()
