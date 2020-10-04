extends Node2D

func _ready():
	Network.connect("server_created", self, "_on_ready_to_play")
	Network.connect("join_success", self, "_on_ready_to_play")
	Network.connect("join_fail", self, "_on_join_fail")

func _process(delta):
	pass

func _on_ready_to_play():
	get_tree().change_scene("res://GameScene.tscn")

func _on_join_fail():
	print("Failed to join server")

func _on_btnHost_pressed():
	# Set the local player info
	set_player_info()
	
	# Gather values from the GUI and fill the network.server_info dictionary
	#if (!$CanvasLayer/PanelHost/txtServerName.text.empty()):
	#Network.server_info.name = $CanvasLayer/PanelHost/txtServerName.text
	Network.server_info.max_players = int(2)
	Network.server_info.used_port = int($CanvasLayer/PanelHost/txtPort.text)
	
	# And create the server, using the function previously added into the code
	Network.create_server()

func _on_btnJoin_pressed():
	# Set the local player info
	set_player_info()
	
	var port = int($CanvasLayer/PanelJoin/txtPort2.text)
	var ip = $CanvasLayer/PanelJoin/txtIpAddress.text
	Network.join_server(ip, port)
	
func set_player_info():
	if (!$CanvasLayer/PanelPlayer/txtPlayerName.text.empty()):
		Gamestate.player_info.name = $CanvasLayer/PanelPlayer/txtPlayerName.text
	else:
		Gamestate.player_info.name = "NO NAME"
