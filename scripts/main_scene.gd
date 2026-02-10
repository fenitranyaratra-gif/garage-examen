# LoadingScene.gd
extends Node2D

# ===============================
# CONFIGURATION
# ===============================
const PROJECT_ID := "garrageapp-05"

@export var main_scene: PackedScene  # LA SCÈNE PRINCIPALE À RETOURNER

# Variables pour les scènes de voitures (optionnel si MainScene les a déjà)
@export var civic_scene: PackedScene
@export var suv_scene: PackedScene
@export var hatchback_scene: PackedScene
@export var minivan_scene: PackedScene
@export var default_scene: PackedScene

@onready var animation_player = $AnimationPlayer

# ===============================
# GODOT LIFECYCLE
# ===============================
func _ready() -> void:
	print("🔄 Loading Scene démarrée")
	
	# Démarrer l'animation
	if animation_player:
		animation_player.play("loading")  # Votre animation
	
	# Démarrer le chargement Firebase
	start_firebase_loading()

# ===============================
# CHARGEMENT FIREBASE (TON CODE)
# ===============================
func start_firebase_loading():
	print("📡 Démarrage du chargement Firebase...")
	get_all_voitures(_on_voitures_recues)

func get_all_voitures(callback: Callable):
	var url := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/voitures" % PROJECT_ID
	
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_firebase_response.bind(callback))
	var err := http.request(url)
	if err != OK:
		print("❌ HTTPRequest error :", err)
		callback.call([] as Array[Dictionary])

func _on_firebase_response(result, response_code, headers, body, callback):
	if response_code != 200:
		print("❌ Erreur HTTP :", response_code)
		callback.call([] as Array[Dictionary])
		return
	
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		print("❌ JSON invalide")
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
		var voiture_id: String = doc_name.split("/")[-1].strip_edges() if "/" in doc_name else ""
		
		if voiture_id == "":
			continue
		
		voitures.append({
			"id": voiture_id,
			"modele": str(fields.get("modele", {}).get("stringValue", "")).strip_edges(),
			"marque": str(fields.get("marque", {}).get("stringValue", "")).strip_edges(),
			"matricule": str(fields.get("matricule", {}).get("stringValue", "")).strip_edges(),
		})
	
	print("✅ Données Firebase extraites :", voitures.size())
	callback.call(voitures)

func _on_voitures_recues(voitures: Array[Dictionary]):
	print("🎯 Chargement terminé, données :", voitures.size())
	
	# Arrêter l'animation
	if animation_player:
		animation_player.stop()
	
	# Retourner à la Main Scene avec les données
	return_to_main_with_data(voitures)

# ===============================
# RETOUR À LA MAIN SCENE
# ===============================
func return_to_main_with_data(voitures: Array[Dictionary]):
	print("🎬 Retour à Main Scene avec données...")
	
	if main_scene:
		# Instancier la Main Scene
		var main_instance = main_scene.instantiate()
		
		# Passer les données à Main Scene
		if main_instance.has_method("receive_voitures_data"):
			main_instance.receive_voitures_data(voitures)
		else:
			print("⚠️ Main Scene n'a pas receive_voitures_data()")
		
		# Changer de scène
		get_tree().change_scene_to_packed(main_scene)
	else:
		print("❌ Aucune Main Scene configurée")
