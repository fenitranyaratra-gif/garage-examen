extends Node

const PROJECT_ID := "garrageapp-05"

func _ready():
	print("=== Test récupération des voitures en panne ===")
	get_voitures_en_panne(Callable(self, "_on_voitures_en_panne"))

# -------------------------------
# Fonction publique à appeler
# -------------------------------
func get_voitures_en_panne(callback: Callable) -> void:
	_get_firestore_collection("pannes", Callable(self, "_on_pannes_loaded").bind(callback))

# -------------------------------
# CALLBACK : PANNES
# -------------------------------
func _on_pannes_loaded(result, response_code, headers, body, callback):
	if response_code != 200:
		print("Erreur HTTP Pannes : ", response_code)
		callback.call([])
		return

	# Parsing JSON compatible Godot 4.5
	var parse_result = JSON.parse_string(body.get_string_from_utf8())
	if parse_result == null:
		print("Erreur JSON : réponse null")
		callback.call([])
		return
	
	var json = parse_result

	var pannes = []
	for doc in json.get("documents", []):
		var fields = doc["fields"]
		pannes.append({
			"idPanne": doc["name"].get_slice("/", -1),
			"idVoiture": fields.get("idVoiture", {}).get("stringValue", "")
		})

	# Récupérer les détails ensuite
	_get_firestore_collection("panneDetails", Callable(self, "_on_details_loaded").bind(callback, pannes))

# -------------------------------
# CALLBACK : PANNES DETAILS
# -------------------------------
func _on_details_loaded(result, response_code, headers, body, callback, pannes):
	if response_code != 200:
		print("Erreur HTTP PanneDetails : ", response_code)
		callback.call([])
		return

	var parse_result2 = JSON.parse_string(body.get_string_from_utf8())
	if parse_result2 == null:
		print("Erreur JSON : réponse null")
		callback.call([])
		return
	
	var json2 = parse_result2

	var details = []
	for doc in json2.get("documents", []):
		var fields = doc["fields"]
		details.append({
			"idPanneDetails": doc["name"].get_slice("/", -1),
			"idPanne": fields.get("idPanne", {}).get("stringValue", ""),
			"idPanneType": fields.get("idPanneType", {}).get("stringValue", "")
		})

	# Associer détails à chaque voiture
	var voitures_en_panne = []
	for panne in pannes:
		var panne_details = []
		for d in details:
			if d["idPanne"] == panne["idPanne"]:
				panne_details.append(d)
		voitures_en_panne.append({
			"idVoiture": panne["idVoiture"],
			"details": panne_details
		})

	# Appel du callback final
	callback.call(voitures_en_panne)

# -------------------------------
# Callback final : affichage console
# -------------------------------
func _on_voitures_en_panne(voitures):
	print("=== Voitures en panne avec détails ===")
	if voitures.size() == 0:
		print("Aucune panne trouvée ou erreur.")
		return

	for v in voitures:
		print("Voiture ID : ", v["idVoiture"])
		if v["details"].size() == 0:
			print("  Aucun détail pour cette panne.")
		else:
			for d in v["details"]:
				print("  PanneDetail ID : ", d["idPanneDetails"], " | Type : ", d["idPanneType"])

# -------------------------------
# Fonction générique pour Firestore
# -------------------------------
func _get_firestore_collection(collection_name: String, callback: Callable) -> void:
	var url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/%s" % [PROJECT_ID, collection_name]
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	var err = http.request(url)
	if err != OK:
		print("Erreur HTTP : ", err)
		callback.call([])
