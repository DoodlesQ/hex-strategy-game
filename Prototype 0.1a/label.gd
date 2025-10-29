extends Label


func _on_beat_manager_faction_changed(faction: String) -> void:
	text = faction


func _on_beat_manager_beat_changed(beat: int) -> void:
	text = str(beat + 1)
