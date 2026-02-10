extends Area2D

class_name ParkingPlaceB

@export var place_name: String = "Place B"
var is_parked: bool = false
var parked_car: Node2D = null
var car_original_position: Vector2 = Vector2.ZERO  # Nouveau: position originale
var car_original_rotation: float = 0.0  # Nouveau: rotation originale

func _ready():
	if not is_in_group("parking_slots"):
		add_to_group("parking_slots")
	print("✅ ParkingPlace '", place_name, "' créé")
	
	var timer = Timer.new()
	timer.wait_time = 0.3
	timer.timeout.connect(_check_car_state)
	add_child(timer)
	timer.start()

func try_park(car: Node2D) -> bool:
	print("🅿️ Parking sur ", place_name, " - Voiture: ", car.name)
	
	# SAUVEGARDER la position et rotation originales
	car_original_position = car.global_position
	car_original_rotation = car.global_rotation
	
	# Place la voiture au bon endroit
	car.global_position = global_position
	car.global_rotation = 0
	
	# Arrête la voiture
	if car.has_method("get_velocity"):
		car.velocity = Vector2.ZERO
	elif "velocity" in car:
		car.velocity = Vector2.ZERO
	
	is_parked = true
	parked_car = car
	
	activate_barrier()
	print("✅ Parking accepté")
	return true

func release_car():
	# LIBÈRE la voiture sans la repositionner
	if is_parked and parked_car and is_instance_valid(parked_car):
		print("🚗 Libération de la voiture du parking ", place_name)
		
		# La voiture garde sa position actuelle
		# Ne pas la repositionner !
		
		is_parked = false
		parked_car = null
		
		deactivate_barrier()
		return true
	return false

func free_parking():
	is_parked = false
	parked_car = null
	deactivate_barrier()
	print("🔓 Parking libéré")

func _check_car_state():
	if is_parked and parked_car and is_instance_valid(parked_car):
		var is_controlled = false
		
		if parked_car.get("is_controlled") != null:
			is_controlled = parked_car.is_controlled
		
		if is_controlled:
			# Si la voiture est contrôlée, la libérer du parking
			release_car()
			deactivate_barrier()
		else:
			# Si la voiture n'est pas contrôlée, activer barrière
			activate_barrier()

func activate_barrier():
	var barrier = get_node_or_null("Barrier")
	if barrier:
		if barrier is CollisionShape2D:
			barrier.disabled = false
		elif barrier is StaticBody2D or barrier is Area2D:
			var collision = barrier.get_node("CollisionShape2D")
			if collision:
				collision.disabled = false

func deactivate_barrier():
	var barrier = get_node_or_null("Barrier")
	if barrier:
		if barrier is CollisionShape2D:
			barrier.disabled = true
		elif barrier is StaticBody2D or barrier is Area2D:
			var collision = barrier.get_node("CollisionShape2D")
			if collision:
				collision.disabled = true
