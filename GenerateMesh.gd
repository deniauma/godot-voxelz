extends Spatial

onready var meshInstance = $mesh

var angle = 0
var texture = load("res://assets/spritesheet_tiles.png")
var surface = SurfaceTool.new()
var mat = SpatialMaterial.new()
var voxel_dirt_and_grass #type = 1
var voxel_dirt #type = 2
var world = {}

func _ready():
	mat.albedo_texture = texture
	#mat.set_flag(SpatialMaterial.FLAG_UNSHADED, true)
	create_cube_with_grass_and_dirt()
	"""world[Vector3(0,0,0)] = meshInstance
	for i in range(-5,5):
		for k in range(-5,5):
			addVoxel(Vector3(i,0,k), 1)
	for i in range(-2,2):
			addVoxel(Vector3(i,1,0), 1)"""
	#generateWorld()
	generate_heightmap()
	create_chunk()
	return

func generate_heightmap():
	randomize()
	var gen_map = gen_diamond_square_heightmap(3, 0, 10)
	var nb_voxels = 0
	for x in range(gen_map.width):
		for z in range(gen_map.width):
			var k = int(gen_map.at(x,z))
			if k <= 0:
				k = 1
			for y in range(k):
				world[Vector3(x,y,z)] = 1


func generateWorld():
	#randomize()
	var gen_map = gen_diamond_square_heightmap(2, 0, 5)
	print("Map size: " + str(gen_map.size))
	#print(gen_map.to_str())
	var nb_voxels = 0
	for x in range(gen_map.width):
		for z in range(gen_map.width):
			var k = int(gen_map.at(x,z))
			if k <= 0:
				k = 1
			for y in range(k):
				addVoxel(Vector3(x,y,z), 1)
				nb_voxels += 1
				#print(str(Vector3(x,y,z)))
	print("Nb voxels: " + str(nb_voxels))

func create_chunk():
	print("Culled voxels = "+str(cull_voxels()))
	surface.clear()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(mat)
	for pos in world.keys():
		if world[pos] > 0:
			cube_at(pos, 2)
	var chunk = MeshInstance.new()
	chunk.mesh = surface.commit()
	add_child(chunk)
	return chunk

func cull_voxels():
	var nb_culled = 0
	for pos in world.keys():
		if find_adjacent_cubes(pos):
			world[pos] = -world[pos]
			nb_culled += 1
	return nb_culled
		
func find_adjacent_cubes(pos):
	var dirs = [Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1), Vector3(-1,0,0),Vector3(0,-1,0),Vector3(0,0,-1)]
	var culled = true
	for normal in dirs:
		var adjacent_cube = pos + normal
		if not world.has(adjacent_cube):
			culled = false
	return culled

func addVoxel(pos, type):
	var voxel = MeshInstance.new()
	voxel.mesh = voxel_dirt_and_grass
	voxel.translation = pos
	world[pos] = voxel
	add_child(voxel)

func create_cube_with_grass_and_dirt():
	surface.clear()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(mat)
	cube_at(Vector3(0, 0, 0), 2)
	voxel_dirt_and_grass = surface.commit()

func cube_at(pos, type):
	var dirs = [Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1)]
	
	for i in range(3):
		for k in range(2):
			var n = dirs[i]*-(k*2 -1)
			face_at(pos,n,type)
				
func face_at(pos, normal, type):
	var s = 0.5
	pos += normal*s
	
	var verts =[Vector3(  0,  s, -s  ),
				Vector3(  0, -s, -s  ),
				Vector3(  0,  s,  s  ),
				Vector3(  0, -s,  s  )]
	
	if normal.x + normal.y + normal.z < 0:
		verts = [verts[0],verts[2],verts[1],verts[3]]

	var normalList = [normal.x,normal.z,normal.y]
	for i in normalList:
		if abs(i) > 0:
			break
		else:
			var index = 0
			for v in verts:
				var tempV = v
				v.x = tempV.y
				v.y = tempV.z
				v.z = tempV.x
				verts[index] = v
				index += 1

	var uv_size = 0.0625
	var u_size = 0.127
	var v_size = 0.0635
	var uvInfo = calcUV(type,normal)
	var uv_offset = uvInfo[1]#Vector2(0,0)
	var order_v  = [ 2   , 0   , 1   ,1    , 3   , 2   ]
	var order_uv = uvInfo[0]#[[1,0],[1,1],[0,1],[0,1],[0,0],[1,0]]
	surface.set_material(mat)
	for v in range(6):
		var uv_vec = Vector2(order_uv[v][0],order_uv[v][1])
		uv_vec.x *= u_size
		uv_vec.y *= v_size
		#uv_offset.x *= u_size
		#uv_offset.y *= v_size
		surface.add_uv(Vector2(uv_offset.x * u_size, uv_offset.y * v_size) + uv_vec) #surface.add_uv((uv_offset * uv_size) + (uv_size * Vector2(order_uv[v][0],order_uv[v][1])))
		surface.add_normal(normal)
		surface.add_vertex(verts[order_v[v]] + pos)
		
func calcUV(type,normal):
	var uv_orderList = [[1,0],[1,1],[0,1],[0,1],[0,0],[1,0]] #works for (0,0,1)
	
	var uvoffset = Vector2(2,0)
	if type == 1 and normal == Vector3(0,1,0):
		uvoffset = Vector2(0,0)
	if type == 2:
		if normal == Vector3(1,0,0):
			uv_orderList = [[0,0],[1,0],[1,1],[1,1],[0,1],[0,0]] #works for (1,0,0)
			uvoffset = Vector2(5,0)
		elif normal == Vector3(-1,0,0):
			uv_orderList = [[0,1],[0,0],[1,0],[1,0],[1,1],[0,1]] #works for (-1,0,0)
			uvoffset = Vector2(5,0)
		elif normal == Vector3(0,1,0):
			
			uvoffset = Vector2(4,6)
		elif normal == Vector3(0,-1,0):
			
			uvoffset = Vector2(5,1)
		elif normal == Vector3(0,0,1):
			
			uvoffset = Vector2(5,0)
		elif normal == Vector3(0,0,-1):
			uv_orderList = [[1,1],[0,1],[0,0],[0,0],[1,0],[1,1]]
			uvoffset = Vector2(5,0)
	return [uv_orderList,uvoffset]

func _process(delta):
	$HUD/monitor/fpsLine/fps.set_text(str(Engine.get_frames_per_second()))
	$HUD/monitor/cpuMemStaticLine/cpuMemStatic.set_text(str(int(Performance.get_monitor(Performance.MEMORY_STATIC)/1000000)))
	$HUD/monitor/cpuMemDynLine/cpuMemDyn.set_text(str(int(Performance.get_monitor(Performance.MEMORY_DYNAMIC)/1000000)))
	$HUD/monitor/GPUmemLine/GPUmem.set_text(str(int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1000000)))
	
	if Input.is_action_just_pressed("ui_right"):
		print("Right")
	"""angle += delta * 30
	meshInstance.rotation_degrees = Vector3(angle, 0, 0)"""
	
func gen_diamond_square_heightmap(n, min_height, max_height):
	var side_size = pow(2, n) + 1
	var heightmap = Array2D.new(side_size, side_size)
	var iterations = n
	
	#randomize()
	#init the 4 corners
	heightmap.set(0, 0, rand_range(min_height, max_height))
	heightmap.set(side_size-1, 0, rand_range(min_height, max_height))
	heightmap.set(0, side_size-1, rand_range(min_height, max_height))
	heightmap.set(side_size-1, side_size-1, rand_range(min_height, max_height))
	
	for i in range(iterations):
		#diamond phase
		var step_size = (side_size-1) / pow(2,i) 
		var half_step = step_size/2
		for x in range(half_step, side_size, step_size):
			for y in range(half_step, side_size, step_size):
				var average = (heightmap.at(x - half_step, y - half_step) + heightmap.at(x - half_step, y + half_step) + heightmap.at(x + half_step, y + half_step) + heightmap.at(x + half_step, y - half_step))/4
				heightmap.set(x, y, average + rand_range(min_height, max_height))
		
		#square phase
		var decal = 0
		for x in range(0, side_size, half_step):
			if decal ==0:
				decal = half_step
			else:
				decal = 0
			
			for y in range(decal, side_size, half_step):
				var sum = 0
				var m = 0
				if x >= half_step:
					sum += heightmap.at(x - half_step, y)
					m += 1
				if (x + half_step) < side_size:
					sum += heightmap.at(x + half_step, y)
					m += 1
				if y >= half_step:
					sum += heightmap.at(x, y - half_step)
					m += 1
				if (y + half_step) < side_size:
					sum += heightmap.at(x, y + half_step)
					m += 1
				heightmap.set(x, y, sum / (m + rand_range(-half_step, half_step)))
	return heightmap
	
	
class Array2D:
	
	var width
	var height
	var size
	var tab = []
	
	func _init(w, h):
		width = w
		height = h
		size = width * height
		for i in range(size):
    		tab.append(0)
		
	func at(x, y):
		return tab[x * height + y]
		
	func set(x, y, val):
		tab[x * height + y] = val
		
	func to_str():
		return str(tab)