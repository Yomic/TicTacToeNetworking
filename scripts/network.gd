extends Node

signal server_created
signal join_success
signal join_fail
signal player_list_changed

var players = {}

# Everyone gets notified whenever a new client joins the server
func _on_player_connected(id):
	pass

# Everyone gets notified whenever someone disconnects from the server
func _on_player_disconnected(id):
	print("Player ", players[id].name, " ", players[id].net_id, " disconnected from server")
	# Update the player tables
	if (get_tree().is_network_server()):
		# Unregister the player from the server's list
		unregister_player(id)
		# Then all remaining peers
		rpc("unregister_player", id)

# Peer trying to connect to server is notified on success
func _on_connected_to_server():
	emit_signal("join_success")
	# Update the player_info dictionary with the obtained unique network ID
	Gamestate.player_info.net_id = get_tree().get_network_unique_id()
	# Request the server to register this new player across all connected players
	rpc_id(1, "register_player", Gamestate.player_info)
	# And register itself on the local list
	register_player(Gamestate.player_info)

# Peer trying to connect to server is notified on failure
func _on_connection_failed():
	emit_signal("join_fail")
	get_tree().set_network_peer(null)

# Peer is notified when disconnected from server
func _on_disconnected_from_server():
	print("Disconnected from server")
	# Clear the internal player list
	players.clear()
	# Reset the player info network ID
	Gamestate.player_info.net_id = 1
	
	if (!get_tree().is_network_server()):
		get_tree().change_scene("res://MenuScene.tscn")

func _ready():
	get_tree().connect("network_peer_connected", self, "_on_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_on_player_disconnected")
	get_tree().connect("connected_to_server", self, "_on_connected_to_server")
	get_tree().connect("connection_failed", self, "_on_connection_failed")
	get_tree().connect("server_disconnected", self, "_on_disconnected_from_server")

var server_info = {
	name = "Server",      # Holds the name of the server
	max_players = 2,      # Maximum allowed connections
	used_port = 4445         # Listening port
}

func create_server():
	# Initialize the networking system
	var net = NetworkedMultiplayerENet.new()
	
	# Try to create the server
	if (net.create_server(server_info.used_port, server_info.max_players) != OK):
		print("Failed to create server")
		return
	
	# Assign it into the tree
	get_tree().set_network_peer(net)
	# Tell the server has been created successfully
	emit_signal("server_created")
	# Register the server's player in the local player list
	register_player(Gamestate.player_info)

func join_server(ip, port):
	var net = NetworkedMultiplayerENet.new()
	
	if (net.create_client(ip, port) != OK):
		print("Failed to create client")
		emit_signal("join_fail")
		return
		
	get_tree().set_network_peer(net)

remote func register_player(pinfo):
	if (get_tree().is_network_server()):
		var totalPlayers = 0
		# If we are the server, distribute the player list info thoughout the connected players
		for id in players:
			totalPlayers += 1
			if totalPlayers > server_info.max_players:
				return
			# Send currently iterated player info to the new player
			rpc_id(pinfo.net_id, "register_player", players[id])
			# Send new player info to currently iterated player, skipping the server (which get get the info shortly)
			if (id != 1):
				rpc_id(id, "register_player", pinfo)
				
	# This will happen for both clients and servers
	print("Registering player ", pinfo.name, " (", pinfo.net_id, ") to internal player table")
	players[pinfo.net_id] = pinfo           # Create the player entry in the dictionary
	emit_signal("player_list_changed")      # And notify that the player list has been changed
	
remote func unregister_player(id):
	print("Removing player ", players[id].name, " from internal table")
	# Remove the player from the list
	players.erase(id)
	# Notify the list has been changed
	emit_signal("player_list_changed")
