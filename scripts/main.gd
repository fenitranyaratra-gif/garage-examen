extends Node2D

# ===============================
# FIREBASE CONFIG
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

@onready var voitures_container: Node2D = $VoituresContainer

# ===============================
# GODOT LIFECYCLE
# ===============================
func _ready() -> void:
	print("===================================")
	print(" CHARGEMENT DES VOITURES FIREBASE ")
	print("===================================")
	get_all_voitures(_on_voitures_recues)   # ← syntaxe propre Godot 4

# ===============================
# FIREBASE API
# ===============================
func get_all_voitures(callback: Callable) -> void:
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
	if response_code != 200:
		print("❌ HTTP ERROR :", response_code)
		callback.call([] as Array[Dictionary])
		return
	
	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		print("❌ JSON invalide :", json.get_error_message())
		callback.call([] as Array[Dictionary])
		return
	
	var data: Dictionary = json.data if json.data is Dictionary else {}
	var documents: Array = data.get("documents", []) as Array
	
	var voitures: Array[Dictionary] = []
	for doc in documents:
		if not doc is Dictionary:
			continue
		
		var fields: Dictionary = doc.get("fields", {}) as Dictionary
		
		# Extraction correcte de l'ID du document
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
	print("Voitures reçues :", voitures.size())
	
	# Nettoyage des anciennes instances
	for child in voitures_container.get_children():
		child.queue_free()
	
	var x: float = 0.0
	var spacing: float = 180.0
	
	for v in voitures:
		var scene: PackedScene = _scene_for_modele(v.get("modele", ""))
		if scene == null:
			print("Aucune scène trouvée pour modèle :", v.get("modele", "<inconnu>"))
			continue
		
		var car: Node2D = scene.instantiate()
		voitures_container.add_child(car)
		car.position = Vector2(x, 0)
		x += spacing
		
		if car.has_method("setup"):
			car.setup(v)
		else:
			print("Attention : instance sans méthode setup() → ", car.name)
	
	print("✅ Voitures affichées :", voitures_container.get_child_count())

# ===============================
# CHOIX DU MODÈLE
# ===============================
func _scene_for_modele(modele: String) -> PackedScene:
	var m := modele.to_lower()
	if m.contains("civic") and civic_scene:
		return civic_scene
	if m.contains("suv") and suv_scene:
		return suv_scene
	if m.contains("hatchback") and suv_scene:
		return hatchback_scene
	if m.contains("minivan") and suv_scene:
		return minivan_scene
	return default_scene

# ===============================
# HTTP FIRESTORE
# ===============================
func _get_firestore_collection(
	collection_name: String,
	callback: Callable
) -> void:
	var url := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/%s" % [
		PROJECT_ID,
		collection_name
	]
	
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	
	var err := http.request(url)
	if err != OK:
		print("❌ HTTPRequest error :", err)
		callback.call([], 500, PackedStringArray(), PackedByteArray())
	
	# Note : on ne queue_free PAS ici, car la requête est asynchrone
	# Il sera libéré dans le callback
