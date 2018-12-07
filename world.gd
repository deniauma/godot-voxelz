extends Spatial

var MAP_SIZE = 256
var CHUNK_SIZE = 16

var chunk_class = load("res://scripts/chunk.gd")
onready var player = $Player
var map
var highest
var chunk_lib
var thread = Thread.new()
var curr_chuck
var prev_chunk
var nb_chunks = 0
var chunks_queue = []

func _ready():
	var r = Utils.generate_heightmap(MAP_SIZE)
	map = r[0]
	highest = r[1]
	chunk_lib = Utils.new_array2D(MAP_SIZE / CHUNK_SIZE, MAP_SIZE / CHUNK_SIZE)
	for x in range(5):
		for y in range(5):
			chunk_lib.set(x, y, create_chunk(Vector2(x,y)))
	player.transform.origin = Vector3(2*CHUNK_SIZE, 20, 2*CHUNK_SIZE)
	
func create_chunk(pos):
	var t = OS.get_ticks_msec()
	var chunk_map = {}
	var max_h = 1
	for x in range(pos.x * CHUNK_SIZE, pos.x * CHUNK_SIZE + CHUNK_SIZE):
		for z in range(pos.y * CHUNK_SIZE, pos.y * CHUNK_SIZE + CHUNK_SIZE):
			for y in range(map.at(x, z)):
				if y > max_h:
					max_h = y
				chunk_map[Vector3(x - pos.x * CHUNK_SIZE, y, z - pos.y * CHUNK_SIZE)] = 1
	var chunk = chunk_class.new()
	chunk.translate(Vector3(pos.x * CHUNK_SIZE, 0, pos.y * CHUNK_SIZE))
	add_child(chunk)
	chunk.create(chunk_map, max_h)
	#player.transform.origin.y = 200
	print("Chunk added in "+str(OS.get_ticks_msec() - t)+" ms")
	nb_chunks += 1
	return chunk

func find_current_chunk(pos):
	var x_pos = int(pos.x / CHUNK_SIZE)
	var z_pos = int(pos.z / CHUNK_SIZE)
	curr_chuck = Vector2(x_pos, z_pos)
	if prev_chunk == null:
		prev_chunk = curr_chuck
	get_tree().call_group("hud", "update_current_chunk_coords", curr_chuck)
	if curr_chuck != prev_chunk:
		load_chunks()
	prev_chunk = curr_chuck
		
func load_chunks():
	var diff = curr_chuck - prev_chunk
	var x_dir
	var y_dir
	if(diff.x != 0):
		x_dir = curr_chuck.x + (diff.x / abs(diff.x)) * 2
		#create_chunk(Vector2(x_dir, curr_chuck.y))
	if(diff.y != 0):
		y_dir = curr_chuck.y + (diff.y / abs(diff.y)) * 2
		#create_chunk(Vector2(curr_chuck.x, y_dir))
	
	for i in range(-1,2,1):
		if(diff.x != 0):
			#create_chunk(Vector2(x_dir, curr_chuck.y + i))
			chunks_queue.append(Vector2(x_dir, curr_chuck.y + i))
		if(diff.y != 0):
			#create_chunk(Vector2(curr_chuck.x, y_dir + i))
			chunks_queue.append(Vector2(curr_chuck.x, y_dir + i))
	
func _physics_process(delta):
	var pos = player.transform.origin
	get_tree().call_group("hud", "update_player_pos", pos)
	get_tree().call_group("hud", "update_nb_chunks", nb_chunks, chunks_queue.size())
	find_current_chunk(pos)
			
func _process(delta):
	print(str(thread.is_active()))
	if(chunks_queue.size() > 0 and not thread.is_active()):
		thread.start(self, "create_chunk", chunks_queue.pop_front())