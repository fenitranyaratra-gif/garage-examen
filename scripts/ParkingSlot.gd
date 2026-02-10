extends Area2D
class_name ParkingSlot

@export var slot_name: String = "Place A"

var occupant: Node2D = null

func _ready() -> void:
	# Sécurité groupe (même si tu l'ajoutes dans l'éditeur)
	add_to_group("parking_slot")
	print("OAYYYYYAAA : ", slot_name)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("Parking slot créé : ", slot_name)
	print("  - Groupe parking_slot : ", is_in_group("parking_slot"))
	print("  - Layer : ", collision_layer)


func is_occupied() -> bool:
	var occ = occupant != null and is_instance_valid(occupant)
	print("[" + slot_name + "] is_occupied → ", occ, " (occupant = ", occupant.name if occupant else "aucun", ")")
	return occ


func try_park(car: Node2D) -> bool:
	print("\n=== TRY_PARK sur " + slot_name + " ===")
	print("Voiture : ", car.name if car else "NULL")
	print("Déjà occupé ? ", is_occupied())
	
	if is_occupied():
		print("REFUS → déjà occupé")
		return false
	
	if not car or not is_instance_valid(car):
		print("REFUS → voiture invalide")
		return false
	
	occupant = car
	print("PARKING ACCEPTÉ ! occupant = ", car.name)
	
	car.global_position = global_position + Vector2(0, 20)  # petit décalage
	car.velocity = Vector2.ZERO
	
	if "is_controlled" in car:
		car.is_controlled = false
	
	var coll = car.get_node_or_null("CollisionShape2D")
	if coll:
		coll.disabled = true
	
	return true


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("voitures"):
		print("Voiture PHYSIQUE entrée dans " + slot_name + " : " + body.name)


func _on_body_exited(body: Node2D) -> void:
	if body == occupant:
		print("Voiture PHYSIQUE sortie de " + slot_name)
		occupant = null
