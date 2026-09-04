extends Node

# Autoloaded singleton. Holds the state every scene needs to agree on.

var game_on := false      ## true once the player has picked a ship and started
var game_over := false    ## true when the player has run out of health
var score := 0
var high_score := 0
var chosen_ship := 1      ## 1 = ACE, 2 = TANK, 3 = ZAP
var mute := false


func reset_values() -> void:
	# Called when the main scene loads / restarts.
	# Note: high_score and mute deliberately survive a restart.
	game_on = false
	game_over = false
	score = 0
	chosen_ship = 1


func add_score(amount: int) -> void:
	score += amount
	if score > high_score:
		high_score = score


func set_mute(value: bool) -> void:
	mute = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), mute)
