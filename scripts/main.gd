extends Node2D

# ===============================
# CONFIGURATION FIREBASE
# ===============================
const PROJECT_ID := "garrageapp-05"

# ===============================
# SCÈNES VOITURES
# ===============================
@export var civic_scene: PackedScene
@export var suv_scene: PackedScene
@export var hatchback_scene: PackedScene
@export var minivan_scene: PackedScene
@export var default_scene: PackedScene

# ===============================
# SCÈNES DE CHARGEMENT
# ===============================
@export var loading_scene: PackedScene
@export var loading_failure_scene: PackedScene

var loading_instance: Node = null
var failure_instance: Node = null  # Instance séparée pour les erreurs
var minimum_loading_time: float = 2.0
var loading_start_time: float = 0.0

@onready var voitures_container: HBoxContainer = $VoituresContainer

# ===============================
# CYCLE DE VIE GODOT
# ===============================
func _ready() -> void:
	print("===================================")
	print(" CHARGEMENT DES VOITURES FIREBASE ")
	print("===================================")
	
	loading_start_time = Time.get_ticks_msec() / 1000.0
	
	# Attendre un frame pour s'assurer que tout est prêt
	await get_tree().process_frame
	
	_show_loading()
	get_all_voitures(_on_voitures_recues)

# ===============================
# FONCTIONS DE CHARGEMENT
# ===============================
func _show_loading() -> void:
	# D'abord nettoyer toute erreur existante
	_hide_failure()
	
	if loading_instance != null:
		return
		
	if loading_scene == null:
		print("⚠️ Aucune scène de loading assignée !")
		return
		
	loading_instance = loading_scene.instantiate()
	
	# Ajouter au CanvasLayer
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(loading_instance)
	get_tree().root.add_child(canvas)
	loading_instance = canvas
	
	print("✅ Loading affiché")

func _hide_loading() -> void:
	if loading_instance == null:
		print("⚠️ Loading instance déjà null")
		return
	
	# Calculer le temps d'attente seulement pour le loading normal
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed_time = current_time - loading_start_time
	var time_to_wait = max(0, minimum_loading_time - elapsed_time)
	
	print("Temps écoulé : ", elapsed_time, " secondes")
	print("Attente supplémentaire : ", time_to_wait, " secondes")
	
	if time_to_wait > 0:
		await get_tree().create_timer(time_to_wait).timeout
	
	loading_instance.queue_free()
	loading_instance = null
	print("✅ Loading caché")

func _show_loading_failure(error_message: String, error_code: int = 0) -> void:
	print("🔄 Affichage loading failure...")
	
	# D'abord cacher le loading normal
	_hide_loading()
	
	# Nettoyer toute erreur précédente
	_hide_failure()
	
	# Vérifier si la scène de failure existe
	if loading_failure_scene == null:
		print("⚠️ Aucune scène de loading failure assignée !")
		# Afficher un message d'erreur simple
		var error_label = Label.new()
		error_label.text = "ERREUR %d\n%s" % [error_code, error_message]
		error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(error_label)
		return
	
	# Instancier la scène de failure
	failure_instance = loading_failure_scene.instantiate()
	
	# Si la scène a une méthode pour configurer le message d'erreur
	if failure_instance.has_method("set_error_message"):
		failure_instance.set_error_message(error_message, error_code)
	
	# Ajouter au CanvasLayer
	var canvas = CanvasLayer.new()
	canvas.layer = 101  # Couche supérieure au loading
	canvas.add_child(failure_instance)
	get_tree().root.add_child(canvas)
	failure_instance = canvas
	
	print("✅ Loading failure affiché: ", error_message, " (Code: ", error_code, ")")

func _hide_failure() -> void:
	if failure_instance == null:
		return
	
	failure_instance.queue_free()
	failure_instance = null
	print("✅ Failure caché")

# ===============================
# API FIREBASE
# ===============================
func get_all_voitures(callback: Callable) -> void:
	print("🌐 Tentative de connexion à Firebase...")
	_get_firestore_collection(
		"voitures",
		_on_voitures_loaded.bind(callback)
	)

func _on_voitures_loaded(
	_result,
	response_code: int,
	_headers,
	body: PackedByteArray,
	callback: Callable
) -> void:
	print("📡 Réponse HTTP reçue: Code ", response_code)
	
	if response_code != 200:
		print("❌ HTTP ERROR :", response_code)
		
		# Déterminer le message d'erreur selon le code
		var error_msg := ""
		match response_code:
			0:
				error_msg = "Pas de connexion Internet\nVérifiez votre réseau"
			400:
				error_msg = "Requête invalide vers Firebase"
			401:
				error_msg = "Non autorisé - Vérifiez votre configuration"
			403:
				error_msg = "Accès interdit"
			404:
				error_msg = "Collection 'voitures' non trouvée"
			500:
				error_msg = "Erreur serveur Firebase"
			503:
				error_msg = "Service Firebase indisponible"
			_:
				error_msg = "Erreur de connexion (Code: %d)" % response_code
		
		# Afficher la scène de loading failure
		_show_loading_failure(error_msg, response_code)
		callback.call([] as Array[Dictionary])
		return

	print("✅ Connexion réussie, traitement des données...")
	
	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		print("❌ JSON invalide :", json.get_error_message())
		_show_loading_failure("Format de données invalide", 422)
		callback.call([] as Array[Dictionary])
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}
	var documents: Array = data.get("documents", []) as Array
	var voitures: Array[Dictionary] = []

	for doc in documents:
		if not doc is Dictionary:
			continue

		var fields: Dictionary = doc.get("fields", {}) as Dictionary
		var doc_name: String = str(doc.get("name", ""))
		var voiture_id: String = ""

		if doc_name != "":
			var parts = doc_name.split("/")
			if parts.size() > 0:
				voiture_id = parts[-1].strip_edges()

		if voiture_id == "":
			print("⚠️ Document sans ID valide :", doc_name)
			continue

		voitures.append({
			"id": voiture_id,
			"modele": str(fields.get("modele", {}).get("stringValue", "")).strip_edges(),
			"marque": str(fields.get("marque", {}).get("stringValue", "")).strip_edges(),
			"matricule": str(fields.get("matricule", {}).get("stringValue", "")).strip_edges(),
		})

	print("Voitures extraites : ", voitures.size())
	for v in voitures:
		print(" → ", v["matricule"], " | ID = ", v["id"])

	callback.call(voitures as Array[Dictionary])

# ===============================
# AFFICHAGE DES VOITURES
# ===============================
func _on_voitures_recues(voitures: Array[Dictionary]) -> void:
	print("📊 Voitures reçues :", voitures.size())
	
	# Si on a une erreur affichée, ne pas continuer
	if failure_instance != null:
		print("⚠️ Une erreur est affichée, annulation de l'affichage des voitures")
		return

	# Nettoyage des anciennes instances
	for child in voitures_container.get_children():
		child.queue_free()

	# Si aucune voiture n'a été trouvée
	if voitures.is_empty():
		print("ℹ️ Aucune voiture trouvée dans la base de données")
		# On cache le loading
		_hide_loading()
		
		# Afficher un message "Aucune voiture"
		var empty_label = Label.new()
		empty_label.text = "Aucune voiture disponible"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 24)
		voitures_container.add_child(empty_label)
		return

	# Afficher les voitures
	for v in voitures:
		var scene: PackedScene = _scene_for_modele(v.get("modele", ""))
		if scene == null:
			print("Aucune scène trouvée pour modèle :", v.get("modele", "<inconnu>"))
			continue

		# Crée un conteneur pour chaque voiture
		var car_container := VBoxContainer.new()
		car_container.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Instancie la scène de la voiture
		var car: Node2D = scene.instantiate()
		
		# Crée un Control pour contenir la Node2D
		var car_control := Control.new()
		car_control.custom_minimum_size = Vector2(200, 200)
		
		# Ajoute la voiture au Control
		car_control.add_child(car)
		car.position = car_control.size / 2
		
		# Crée un label pour les informations
		var label := Label.new()
		label.text = "%s\n%s\n%s" % [
			v.get("marque", "N/A"),
			v.get("modele", "N/A"),
			v.get("matricule", "N/A")
		]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Ajoute les éléments au conteneur
		car_container.add_child(car_control)
		car_container.add_child(label)
		
		# Applique des styles optionnels
		var stylebox := StyleBoxFlat.new()
		stylebox.bg_color = Color(0.1, 0.1, 0.1, 0.3)
		stylebox.border_width_bottom = 2
		stylebox.border_width_left = 2
		stylebox.border_width_right = 2
		stylebox.border_width_top = 2
		stylebox.border_color = Color(0.3, 0.3, 0.3, 0.5)
		stylebox.corner_radius_top_left = 8
		stylebox.corner_radius_top_right = 8
		stylebox.corner_radius_bottom_left = 8
		stylebox.corner_radius_bottom_right = 8
		
		car_container.add_theme_stylebox_override("panel", stylebox)
		
		# Ajoute au HBoxContainer principal
		voitures_container.add_child(car_container)
		
		# Configure la voiture si elle a une méthode setup
		if car.has_method("setup"):
			car.setup(v)
		else:
			print("Attention : instance sans méthode setup() → ", car.name)

	print("✅ Voitures affichées :", voitures_container.get_child_count())
	
	# Masquer le loading
	_hide_loading()

# ===============================
# CHOIX DU MODÈLE
# ===============================
func _scene_for_modele(modele: String) -> PackedScene:
	var m := modele.to_lower()
	if m.contains("civic") and civic_scene:
		return civic_scene
	if m.contains("suv") and suv_scene:
		return suv_scene
	if m.contains("hatchback") and hatchback_scene:
		return hatchback_scene
	if m.contains("minivan") and minivan_scene:
		return minivan_scene
	return default_scene

# ===============================
# HTTP FIRESTORE
# ===============================
func _get_firestore_collection(
	collection_name: String,
	callback: Callable
) -> void:
	var url := "https://garage-api-2-t50x.onrender.com/voitures" % [
		PROJECT_ID,
		collection_name
	]

	print("🔗 URL Firebase: ", url)
	
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	
	print("📤 Envoi de la requête HTTP...")
	var err := http.request(url)
	
	if err != OK:
		print("❌ HTTPRequest error :", err)
		# Appeler directement le callback avec une erreur
		callback.call([], 0, PackedStringArray(), PackedByteArray())

# ===============================
# GESTION DES BOUTONS D'ERREUR
# ===============================
func _on_retry_pressed() -> void:
	print("🔄 Tentative de reconnexion...")
	_hide_failure()
	loading_start_time = Time.get_ticks_msec() / 1000.0
	_show_loading()
	get_all_voitures(_on_voitures_recues)
