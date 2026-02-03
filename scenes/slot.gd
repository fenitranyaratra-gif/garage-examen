extends Area2D

# On tente de récupérer le mur. Si ça échoue, mur_shape sera 'null'
@onready var mur_shape = get_node_or_null("MurPhysique/CollisionShape_Mur")

var occupant = null

func _process(_delta):
	# Sécurité : Si le mur n'est pas trouvé, on ne fait rien pour éviter le crash
	if mur_shape == null: 
		return 

	if occupant != null:
		# CAS A : RÉPARATION EN COURS -> MUR ACTIF (Bloque tout le monde)
		if occupant.get("est_reparee") == false:
			if mur_shape.disabled == true: # On ne change l'état que si nécessaire
				mur_shape.set_deferred("disabled", false)
				print("🔒 BUNKER : Personne ne rentre !")
		
		# CAS B : RÉPARATION FINIE -> MUR DÉSACTIVÉ (Le joueur peut passer)
		else:
			if mur_shape.disabled == false:
				mur_shape.set_deferred("disabled", true)
				print("🔓 FINI : Récupération autorisée pour le joueur.")
	else:
		# CAS C : VIDE -> MUR DÉSACTIVÉ (Pour laisser entrer une voiture)
		if mur_shape.disabled == false:
			mur_shape.set_deferred("disabled", true)

func _on_body_entered(body):
	# On ignore le joueur pour la détection du slot
	if body.name == "Joueur": return
	
	# Si c'est une voiture et que le slot est vide
	if body.has_method("gerer_progression") and occupant == null:
		occupant = body
		body.dans_zone_special = true
