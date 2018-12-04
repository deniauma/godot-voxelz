extends Spatial

var MAP_SIZE = 256
var CHUNK_SIZE = 16

var chunk_class = load("res://scripts/chunk.gd")
onready var player = $Player
var map
var highest
var chunk_lib

func _ready():
	var r = Utils.generate_heightmap(MAP_SIZE)
	map = r[0]
	highest = r[1]
	chunk_lib = Utils.new_array2D(MAP_SIZE / CHUNK_SIZE, MAP_SIZE / CHUNK_SIZE)
	for x in range(2):
		for y in range(2):
			chunk_lib.set(x, y, create_chunk(Vector2(x,y)))
	
	
func create_chunk(pos):
	var chunk_map = {}
	var max_h = 1
	for x in range(pos.x * CHUNK_SIZE, pos.x * CHUNK_SIZE + CHUNK_SIZE):
		for z in range(pos.y * CHUNK_SIZE, pos.y * CHUNK_SIZE + CHUNK_SIZE):
			for y in range(map.at(x, z)):
				if y > max_h:
					max_h = y
				chunk_map[Vector3(x,y,z)] = 1
	var chunk = chunk_class.new()
	chunk.translate(Vector3(pos.x * CHUNK_SIZE, 0, pos.y * CHUNK_SIZE))
	add_child(chunk)
	chunk.create(chunk_map, max_h)
	print("Chunk final pos: "+str(chunk.translation))
	#player.transform.origin.y = 200
	return chunk

	
func _physics_process(delta):
	var pos = player.transform.origin
	pos = Vector3(int(pos.x), int(pos.y)-1.5, int(pos.z))
			