extends CharacterBody2D

const SPEED = 500.0

@onready var animations = $AnimatedSprite2D
@onready var camera: Camera2D = get_node("/root/Main/Camera2D")

var is_active = true
var current_vehicle: Node2D = null
var target_to_follow = null
var nearby_vehicles: Array[Node2D] = []
var controlled_vehicle_root: Node2D = null
var can_interact: bool = true
var is_in_parked_car: bool = false  # Nouveau: pour savoir si on est dans une voiture garée

func _ready():
	print("🎮 Joueur prêt")
	if camera:
		camera.make_current()
		camera.enabled = true

func _physics_process(_delta: float) -> void:
	if not camera:
		return
	
	var target_pos := global_position
	if not is_active:
		if current_vehicle != null and is_instance_valid(current_vehicle):
			target_pos = current_vehicle.global_position
		else:
			exit_car()
			return
	
	camera.global_position = camera.global_position.lerp(target_pos, 15.0 * _delta)
	
	if not is_active:
		return
	
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * SPEED
	move_and_slide()
	update_animations(direction)

func _input(event):
	if event.is_action_pressed("ui_select") and can_interact:
		can_interact = false
		
		if is_active:
			if target_to_follow and current_vehicle and is_instance_valid(current_vehicle):
				enter_car()
			else:
				print("Aucune voiture à portée")
		else:
			# Mode voiture
			if is_in_parked_car:
				# Si on est dans une voiture garée, juste sortir
				print("🚗 Sortie de voiture garée")
				exit_car()
			else:
				# Si on est dans une voiture normale, essayer de garer
				if try_park():
					print("🎉 Voiture garée!")
				else:
					print("❌ Parking impossible - sortie")
					exit_car()
		
		await get_tree().create_timer(0.3).timeout
		can_interact = true

# ================= ENTRER DANS LA VOITURE =================
func enter_car():
	if not target_to_follow or not current_vehicle or not is_instance_valid(current_vehicle):
		print("❌ Impossible d'entrer: voiture invalide")
		return
	
	print("🚗 Entrée dans la voiture...")
	
	# Vérifier si c'est une voiture garée
	is_in_parked_car = false
	var all_slots = get_tree().get_nodes_in_group("parking_slots")
	for slot in all_slots:
		if slot is ParkingPlace and slot.is_parked:
			if slot.parked_car == current_vehicle:
				is_in_parked_car = true
				print("⚠️ Entrée dans une voiture GARÉE")
				break
	
	# Marquer la voiture comme contrôlée
	if current_vehicle.has_method("set_controlled"):
		current_vehicle.set_controlled(true)
	else:
		current_vehicle.is_controlled = true
	
	controlled_vehicle_root = target_to_follow
	
	is_active = false
	animations.visible = false
	$CollisionShape2D.disabled = true
	
	camera.top_level = true
	camera.global_position = current_vehicle.global_position
	
	print("✅ Entré dans:", current_vehicle.name)
	print("DEBUG: is_in_parked_car = ", is_in_parked_car)

# ================= SORTIR DE LA VOITURE =================
func exit_car():
	var vehicle = current_vehicle if current_vehicle else get_vehicle_body(controlled_vehicle_root)
	
	if not vehicle or not is_instance_valid(vehicle):
		force_player_return()
		return
	
	# Marquer la voiture comme non contrôlée
	if vehicle.has_method("set_controlled"):
		vehicle.set_controlled(false)
	else:
		vehicle.is_controlled = false
	
	# Place le joueur à côté de la voiture
	var forward = Vector2(0, -120).rotated(vehicle.global_rotation)
	global_position = vehicle.global_position + forward
	
	is_active = true
	animations.visible = true
	$CollisionShape2D.disabled = false
	
	camera.top_level = false
	camera.position = Vector2.ZERO
	
	print("✅ Sorti de:", vehicle.name)
	
	# Réinitialiser
	is_in_parked_car = false
	current_vehicle = null
	controlled_vehicle_root = null
	target_to_follow = null
	nearby_vehicles.clear()

# ================= PARKING =================
func try_park() -> bool:
	print("\n🚗 Tentative de parking...")
	
	if not current_vehicle:
		print("❌ Pas de voiture à garer")
		return false
	
	# Cherche un slot de parking proche
	var all_slots = get_tree().get_nodes_in_group("parking_slots")
	var closest_slot = null
	var closest_distance = 9999
	
	for slot in all_slots:
		if not slot is ParkingPlace:
			continue
		
		# Ignorer les slots déjà occupés
		if slot.is_parked:
			continue
		
		var distance = global_position.distance_to(slot.global_position)
		if distance < closest_distance and distance < 600:
			closest_distance = distance
			closest_slot = slot
	
	if closest_slot:
		print("✅ Slot trouvé à", closest_distance, "pixels")
		
		# Tente de garer la voiture
		if closest_slot.try_park(current_vehicle):
			print("🎉 Parking réussi!")
			
			# Mettre is_controlled à false
			if current_vehicle.has_method("set_controlled"):
				current_vehicle.set_controlled(false)
			else:
				current_vehicle.is_controlled = false
			
			# Retour au mode joueur
			exit_car_after_parking()
			return true
		else:
			print("❌ Le slot a refusé le parking")
			return false
	else:
		print("❌ Pas de slot de parking assez proche (ou tous occupés)")
		return false
func exit_car_after_parking():
	var vehicle = current_vehicle if current_vehicle else get_vehicle_body(controlled_vehicle_root)
	
	if vehicle and is_instance_valid(vehicle):
		# DEBUG: Afficher la position de la voiture
		print("DEBUG: Position voiture = ", vehicle.global_position)
		print("DEBUG: Rotation voiture = ", vehicle.global_rotation)
		
		# Calculer la position de sortie
		var forward = Vector2(0, -120).rotated(vehicle.global_rotation)
		var exit_position = vehicle.global_position + forward
		
		print("DEBUG: Position de sortie calculée = ", exit_position)
		
		# Téléporter le joueur
		global_position = exit_position
		
		is_active = true
		animations.visible = true
		$CollisionShape2D.disabled = false
		
		camera.top_level = false
		camera.position = Vector2.ZERO
		
		print("✅ Voiture garée et sortie - Position finale: ", global_position)
	else:
		print("❌ Véhicule invalide lors de la sortie du parking")
		global_position = Vector2(100, 100)  # Position de secours
	
	current_vehicle = null
	controlled_vehicle_root = null
	target_to_follow = null
	nearby_vehicles.clear()
# ================= FONCTIONS UTILITAIRES =================
func get_vehicle_body(vehicle_root: Node2D) -> Node2D:
	if not vehicle_root or not is_instance_valid(vehicle_root):
		return null
	
	if vehicle_root is CharacterBody2D:
		return vehicle_root
	
	var car_body = vehicle_root.get_node_or_null("CharacterBody2D")
	if not car_body:
		car_body = vehicle_root.get_node_or_null("Body")
	
	return car_body

func force_player_return():
	is_active = true
	animations.visible = true
	$CollisionShape2D.disabled = false
	camera.top_level = false
	camera.position = Vector2.ZERO
	current_vehicle = null
	controlled_vehicle_root = null
	target_to_follow = null
	nearby_vehicles.clear()
	print("🔄 Retour au mode joueur")

# ================= DÉTECTION DES VOITURES =================
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("voitures") and not nearby_vehicles.has(body):
		nearby_vehicles.append(body)
		update_target_vehicle()
		print("🚗 Voiture détectée:", body.name)

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if nearby_vehicles.has(body):
		nearby_vehicles.erase(body)
		update_target_vehicle()
		print("🚗 Voiture hors de portée:", body.name)

func update_target_vehicle() -> void:
	if nearby_vehicles.is_empty():
		target_to_follow = null
		if is_active:
			current_vehicle = null
		return
	
	var closest = null
	var min_dist = INF
	for v in nearby_vehicles:
		if not is_instance_valid(v):
			continue
			
		var dist = global_position.distance_to(v.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = v
	
	target_to_follow = closest
	
	var car_body: Node2D = get_vehicle_body(target_to_follow)
	
	if is_active:
		current_vehicle = car_body if car_body else target_to_follow

# ================= ANIMATIONS =================
func update_animations(direction: Vector2):
	if direction == Vector2.ZERO:
		animations.play("idle")
	else:
		if abs(direction.x) > abs(direction.y):
			animations.play("side_left")
			animations.flip_h = (direction.x < 0)
		else:
			animations.flip_h = false
			if direction.y > 0:
				animations.play("front_idle")
			else:
				animations.play("back_idle")
