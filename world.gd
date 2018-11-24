extends Spatial

onready var chunk = $Chunk
onready var player = $Player

func _ready():
	if chunk.world.has(player.transform.origin):
		print("yes!")
	
func _physics_process(delta):
	var pos = player.transform.origin
	pos = Vector3(int(pos.x), int(pos.y)-1.5, int(pos.z))
	#print(str(pos))
	if chunk.generated:
		$playerPosDebug.translation = pos
		