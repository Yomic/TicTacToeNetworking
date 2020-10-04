extends Node2D

const SPRITE_X = preload("res://sprites/X.png")
const SPRITE_O = preload("res://sprites/O.png")

var UPDATE_TIME = 1

var deltaUpdateFromServer = 0
var pickedFirstTurn = false
sync var playerTurn = 0
sync var playerWhoMoved = 0
sync var playerMove = 0 # Player moves are 1, 2, 3
						#                  4, 5, 6
						#                  7, 8, 9
sync var winner = -1
var totalTies = 0
var occupiedSpaces = []
var waitingForBothPlayersToResetGame = false

func resetForNewGame():
	for p in Network.players:
		Network.players[p].moves = []
		Network.players[p].newGamePressed = false
	deltaUpdateFromServer = 0
	pickedFirstTurn = false
	# This must be reset earlier so the vars can sync during this method
	# peer might lag and set to 0 after having a proper outcome otherwise
	#playerTurn = 0
	playerWhoMoved = 0
	playerMove = 0
	winner = -1
	occupiedSpaces = []
	waitingForBothPlayersToResetGame = false
	
func resetWins():
	for p in Network.players:
		Network.players[p].wins = 0
	totalTies = 0

func _ready():
	Network.connect("player_list_changed", self, "_on_player_list_changed")
	
	$HUD/PanelPlayer1/rtlLocalPlayer.text = Gamestate.player_info.name
	$HUD/PanelPlayer2/rtlRemotePlayer.text = "NOT CONNECTED"
	$HUD/PanelStatus/rtlStatus.text = "WAITING FOR OPPONENT TO JOIN..."
	#$HUD/PanelIpOfHost/rtlIPAddress.text = 
	#print(IP.get_local_addresses())
	
	if (!get_tree().is_network_server()):
		$HUD/X_ServerPlayerIcon.position.x = 480
		$HUD/O_PeerPlayerIcon.position.x = 110

func _process(delta):
	
	if !waitingForBothPlayersToResetGame:
		deltaUpdateFromServer += delta
		if deltaUpdateFromServer >= UPDATE_TIME:
			deltaUpdateFromServer -= UPDATE_TIME
			updateStatusText()
			
		if playerMove != 0:
			#playerMove reset to default in function
			rpc("updateGameBoard", playerWhoMoved, playerMove)
	else:
		
		var confirmedPlayers = 0
		for p in Network.players:
			if Network.players[p].newGamePressed:
				confirmedPlayers += 1
			if confirmedPlayers == 2:
				waitingForBothPlayersToResetGame = false
		
		if !waitingForBothPlayersToResetGame:
			print("Start new game!")
			resetForNewGame()
			gotoNewGame()
	
func gotoNewGame():
	setup_newgame()
	resetGameBoard()
	
func resetGameBoard():
	for i in range(9):
		if $HUD/GameMovePositions.get_child(i).visible:
			$HUD/GameMovePositions.get_child(i).hide()

func _on_player_list_changed():
	
	# Reset all variables so new game is fresh at start and when players disconnect
	resetForNewGame()
	resetWins()
	updateStatusText()
	updateWinsText()
	resetGameBoard()
	if $HUD/btnNewGame.visible:
		$HUD/btnNewGame.hide()
	playerTurn = 0
	
	# First delete text from remote player
	$HUD/PanelPlayer2/rtlRemotePlayer.text = ""
	# Now iterate through the player list creating a new entry into the boxList
	var connectedPlayers = 0
	for p in Network.players:
		connectedPlayers += 1
		if (p != Gamestate.player_info.net_id):
			$HUD/PanelPlayer2/rtlRemotePlayer.text = Network.players[p].name
	
	if connectedPlayers > 1:
		setup_newgame()
	# If the host leaves, disconnect and throw out the peer
	if (connectedPlayers == 1 && !get_tree().is_network_server()):
		get_tree().change_scene("res://MenuScene.tscn")
		
func setup_newgame():
	# Determine who goes first
	if (get_tree().is_network_server()):
		getFirstTurn()
	
	# Update Status Text
	updateStatusText()
	
func updateStatusText():
	
	if playerTurn == 0:
		$HUD/PanelStatus/rtlStatus.text = "WAITING FOR OPPONENT TO JOIN..."
	else:
		$HUD/PanelStatus/rtlStatus.text = getTurnPlayerName() + "'s turn."
		
	if winner != -1 && winner != -2:
		$HUD/PanelStatus/rtlStatus.text = Network.players[winner].name + " wins!"
		updateWinsText()
	elif winner == -2:
		$HUD/PanelStatus/rtlStatus.text = "TIED GAME!  CAT WINS!"
		updateWinsText()
		
func updateWinsText():
	var totalPlayers = 0
	for p in Network.players:
		totalPlayers += 1
		# if p is the local net_id
		if (p == Gamestate.player_info.net_id):
			$HUD/PanelPlayer1Wins/rtlLocalPlayerWins.text = str(Network.players[p].wins)
		else:
			$HUD/PanelPlayer2Wins/rtlRemotePlayerWins.text = str(Network.players[p].wins)
			
	if totalPlayers == 1:
		$HUD/PanelPlayer2Wins/rtlRemotePlayerWins.text = str(0)
		
	$HUD/PanelCatWins/rtlTotalTies.text = str(totalTies)
		
remotesync func updateGameBoard(who, move):
	if who == 1:
		if !$HUD/GameMovePositions.get_child(move - 1).visible:
			print("Player who moved was: " + str(who))
			$HUD/GameMovePositions.get_child(move - 1).texture = SPRITE_X
			$HUD/GameMovePositions.get_child(move - 1).show()
	else:
		if !$HUD/GameMovePositions.get_child(move - 1).visible:
			print("Player who moved was: " + str(who))
			$HUD/GameMovePositions.get_child(move - 1).texture = SPRITE_O
			$HUD/GameMovePositions.get_child(move - 1).show()
			
	# I'd like these to be able to change locally only, but I don't think I can do this
	playerMove = 0
	playerWhoMoved = 0
	
func getTurnPlayerName():
	for p in Network.players:
		if playerTurn == 1:
			# If this is the server && p is the local net_id
			if (get_tree().is_network_server() && p == Gamestate.player_info.net_id):
				return Network.players[p].name
			elif (!get_tree().is_network_server() && p != Gamestate.player_info.net_id):
				return Network.players[p].name
		elif playerTurn == 2:
			# If this is the peer && p is the local net_id
			if (!get_tree().is_network_server() && p == Gamestate.player_info.net_id):
				return Network.players[p].name
			elif (get_tree().is_network_server() && p != Gamestate.player_info.net_id):
				return Network.players[p].name
		else:
			return "PT=" + str(playerTurn) # Game hasn't started yet
	return "ERROR"
	
master func getFirstTurn():
	# 0 = not started, 1 = server, 2 = peer
	if !pickedFirstTurn:
		randomize()
		playerTurn = randi() % 2 + 1
		
		pickedFirstTurn = true
	
		var playerName = getTurnPlayerName()

		print("Player " + playerName + " goes first!")
	
		rset("playerTurn", playerTurn)
		
func nextTurn():
	if playerTurn == 1:
		rset("playerTurn", 2)
	elif playerTurn == 2:
		rset("playerTurn", 1)

remotesync func checkWinner(player_id):

	if Network.players[player_id].moves.has(1):
		if Network.players[player_id].moves.has(2):
			if Network.players[player_id].moves.has(3):
				winner = player_id
		if Network.players[player_id].moves.has(5):
			if Network.players[player_id].moves.has(9):
				winner = player_id
		if Network.players[player_id].moves.has(4):
			if Network.players[player_id].moves.has(7):
				winner = player_id
				
	if Network.players[player_id].moves.has(4):
		if Network.players[player_id].moves.has(5):
			if Network.players[player_id].moves.has(6):
				winner = player_id
	if Network.players[player_id].moves.has(7):
		if Network.players[player_id].moves.has(8):
			if Network.players[player_id].moves.has(9):
				winner = player_id
				
	if Network.players[player_id].moves.has(2):
		if Network.players[player_id].moves.has(5):
			if Network.players[player_id].moves.has(8):
				winner = player_id
	if Network.players[player_id].moves.has(3):
		if Network.players[player_id].moves.has(6):
			if Network.players[player_id].moves.has(9):
				winner = player_id
	if Network.players[player_id].moves.has(7):
		if Network.players[player_id].moves.has(5):
			if Network.players[player_id].moves.has(3):
				winner = player_id
				
	#If there is no winner yet, go to next turn
	if winner == -1:
		nextTurn()
				
	#If there is a tie, end game
	if winner == -1 && occupiedSpaces.size() == 9:
		winner = -2 # Tie condition:  Cat wins
		$HUD/btnNewGame.show()
		playerTurn = 0
		totalTies += 1
	#If there is a winner, end game
	if winner != -1 && winner != -2:
		Network.players[player_id].wins += 1
		$HUD/btnNewGame.show()
		playerTurn = 0

remotesync func setMove(player_id, move):
	# Update move list on local machine
	Network.players[player_id].moves.append(move)
	occupiedSpaces.append(move)
	#Network.players.get(player_id).player_info.moves.append(move)
	checkWinner(player_id)

func setPlayerMove(move):
	if winner == -1 && !occupiedSpaces.has(move) && !waitingForBothPlayersToResetGame:
		var id = get_tree().get_network_unique_id()
		rpc("setMove", id, move)
		rset("playerMove", move)
		rset("playerWhoMoved", get_tree().get_network_unique_id())

func _on_btnNewGame_pressed():
	$HUD/PanelStatus/rtlStatus.text = "WAITING FOR OPPONENT..."
	waitingForBothPlayersToResetGame = true
	rpc("setNewGamePressed", Gamestate.player_info.net_id)
	$HUD/btnNewGame.hide()

remotesync func setNewGamePressed(id):
	print("Player: " + str(id) + " has pressed New Game!")
	Network.players[id].newGamePressed = true

func _on_Pos1_input_event(viewport, event, shape_idx):
	if (event is InputEventMouseButton && event.pressed):
		if (playerTurn == 1 && get_tree().is_network_server()) || (playerTurn == 2 && !get_tree().is_network_server()):
			setPlayerMove(1)

func _on_Pos2_input_event(viewport, event, shape_idx):
	if (event is InputEventMouseButton && event.pressed):
		if (playerTurn == 1 && get_tree().is_network_server()) || (playerTurn == 2 && !get_tree().is_network_server()):
			setPlayerMove(2)

func _on_Pos3_input_event(viewport, event, shape_idx):
	if (event is InputEventMouseButton && event.pressed):
		if (playerTurn == 1 && get_tree().is_network_server()) || (playerTurn == 2 && !get_tree().is_network_server()):
			setPlayerMove(3)

func _on_Pos4_input_event(viewport, event, shape_idx):
	if (event is InputEventMouseButton && event.pressed):
		if (playerTurn == 1 && get_tree().is_network_server()) || (playerTurn == 2 && !get_tree().is_network_server()):
			setPlayerMove(4)

func _on_Pos5_input_event(viewport, event, shape_idx):
	if (event is InputEventMouseButton && event.pressed):
		if (playerTurn == 1 && get_tree().is_network_server()) || (playerTurn == 2 && !get_tree().is_network_server()):
			setPlayerMove(5)

func _on_Pos6_input_event(viewport, event, shape_idx):
	if (event is InputEventMouseButton && event.pressed):
		if (playerTurn == 1 && get_tree().is_network_server()) || (playerTurn == 2 && !get_tree().is_network_server()):
			setPlayerMove(6)

func _on_Pos7_input_event(viewport, event, shape_idx):
	if (event is InputEventMouseButton && event.pressed):
		if (playerTurn == 1 && get_tree().is_network_server()) || (playerTurn == 2 && !get_tree().is_network_server()):
			setPlayerMove(7)

func _on_Pos8_input_event(viewport, event, shape_idx):
	if (event is InputEventMouseButton && event.pressed):
		if (playerTurn == 1 && get_tree().is_network_server()) || (playerTurn == 2 && !get_tree().is_network_server()):
			setPlayerMove(8)

func _on_Pos9_input_event(viewport, event, shape_idx):
	if (event is InputEventMouseButton && event.pressed):
		if (playerTurn == 1 && get_tree().is_network_server()) || (playerTurn == 2 && !get_tree().is_network_server()):
			setPlayerMove(9)
