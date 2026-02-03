extends Node2D  # Node2D pour jeu 2D

# ===============================
# CONFIG FIREBASE
# ===============================
const PROJECT_ID := "garrageapp-05"

# ===============================
# SCÈNES VOITURES
# ===============================
@export var civic_scene: PackedScene
@export var suv_scene: PackedScene
@export var default_scene: PackedScene = preload("res://scenes/CIVIC.tscn")

@onready var voitures_container := $VoituresContainer

# ===============================
# GODOT LIFECYCLE
# ===============================
func _ready():
	print("====================================")
	print(" DÉMARRAGE DU JEU - CHARGEMENT VOITURES ")
	print("====================================")

	get_all_voitures(Callable(self, "_on_voitures_reçues"))

# ===============================
# API PUBLIQUE
# ===============================
func get_all_voitures(callback: Callable) -> void:
	_get_firestore_collection(
		"voitures",
		Callable(self, "_on_voitures_loaded").bind(callback)
	)

# ===============================
# CALLBACK FIRESTORE : VOITURES
# ===============================
func _on_voitures_loaded(result, response_code, headers, body, callback):
	print("DEBUG → HTTP code :", response_code)

	if response_code != 200:
		print("❌ Erreur HTTP Voitures :", response_code)
		callback.call([])
		return

	var json_result = JSON.parse_string(body.get_string_from_utf8())
	if json_result == null:
		print("❌ Erreur JSON parsing : réponse null")
		callback.call([])
		return

	var json = json_result
	var voitures := []

	for doc in json.get("documents", []):
		var fields = doc.get("fields", {})

		voitures.append({
			"id": doc["name"].get_slice("/", -1),
			"idUtilisateur": fields.get("idUtilisateur", {}).get("stringValue", ""),
			"matricule": fields.get("matricule", {}).get("stringValue", ""),
			"marque": fields.get("marque", {}).get("stringValue", ""),
			"modele": fields.get("modele", {}).get("stringValue", ""),
			"annee": int(fields.get("annee", {}).get("integerValue", 0)),
			"dateAjout": fields.get("dateAjout", {}).get("timestampValue", "")
		})

	print("DEBUG → voitures parsées :", voitures)
	print("DEBUG → nombre de voitures :", voitures.size())

	callback.call(voitures)

# ===============================
# AFFICHAGE DANS LA SCÈNE
# ===============================
func _on_voitures_reçues(voitures):
	print("=== AFFICHAGE DES VOITURES ===")
	print("DEBUG → voitures reçues :", voitures)
	print("DEBUG → nombre :", voitures.size())

	# Nettoyage ancien affichage
	for child in voitures_container.get_children():
		child.queue_free()

	if voitures.is_empty():
		print("⚠️ Aucune voiture trouvée.")
		return

	var spacing := 150
	var x := 0

	for v in voitures:
		var scene := _get_scene_for_modele(v.get("modele", ""))

		if scene == null:
			print("⚠️ Scène introuvable pour le modèle :", v.get("modele", ""))
			continue

		var voiture = scene.instantiate()
		voitures_container.add_child(voiture)

		voiture.position = Vector2(x, 0)
		x += spacing

		if voiture.has_method("setup"):
			voiture.setup(v)

	print("✅ Total voitures affichées :", voitures_container.get_child_count())

# ===============================
# CHOIX DU MODÈLE VISUEL
# ===============================
func _get_scene_for_modele(modele: String) -> PackedScene:
	if modele == null:
		modele = ""

	var m := modele.to_lower()

	if m.contains("civic") and civic_scene:
		return civic_scene
	if m.contains("suv") and suv_scene:
		return suv_scene
	if default_scene:
		return default_scene

	push_error("❌ Aucune scène voiture assignée !")
	return null

# ===============================
# FIRESTORE HTTP GÉNÉRIQUE
# ===============================
func _get_firestore_collection(collection_name: String, callback: Callable) -> void:
	var url := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/%s" % [
		PROJECT_ID,
		collection_name
	]

	print("DEBUG → URL Firestore :", url)

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)

	var err = http.request(url)
	if err != OK:
		print("❌ Erreur HTTPRequest :", err)
		callback.call([], 500, {}, "")
