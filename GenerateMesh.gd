extends Spatial

var angle = 0
var simplex = load("res://simplex/Simplex.gd")
var texture = load("res://assets/spritesheet_tiles.png")
var surface = SurfaceTool.new()
var mat = SpatialMaterial.new()
var voxel_dirt_and_grass #type = 1
var voxel_dirt #type = 2
var world = {}
var chunk_world = {}
var thread = Thread.new()

func _ready():
	mat.albedo_texture = texture
	#mat.set_flag(SpatialMaterial.FLAG_UNSHADED, true)
	var t = OS.get_ticks_msec()
	#generate_heightmap(5)
	generate_height_with_simplex(256)
	#create_chunk()
	print(str(OS.get_ticks_msec() - t)+" ms")
	if thread.is_active():
		# Already working
		return
	thread.start(self, "create_chunk")

func generate_heightmap(max_height):
	#randomize()
	seed(4)
	var gen_map = gen_diamond_square_heightmap(6, 0, 10)
	var nb_voxels = 0
	for x in range(gen_map.width):
		for z in range(gen_map.width):
			var k = int(gen_map.at(x,z))
			if k <= 0:
				k = 1
			if k > 20:
				k = 20
			for y in range(k):
				world[Vector3(x,y,z)] = 1

func generate_height_with_simplex(size):
	for x in range(size):
		for z in range(size):
			var xforsim = x * 0.05+40
			var yforsim = z * 0.05+2000
			var h = 1 + (((simplex.simplex2(xforsim,yforsim)+1)*0.5) * 16)
			for y in range(h):
				world[Vector3(x,y,z)] = 1

func create_chunk(size):
	print("Chunk build started!")
	var t = OS.get_ticks_msec()
	var total_voxels = 0
	for pos in world:
		if world[pos] > 0:
			total_voxels += 1
	print("Total voxels before culling = "+str(total_voxels))
	#print("Culled voxels = "+str(cull_voxels()))
	surface.clear()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(mat)
	for pos in world.keys():
		if world[pos] > 0:
			var faces_to_cull = find_adjacent_faces(pos)
			cube_at(pos, 2, faces_to_cull)
	var chunk = MeshInstance.new()
	surface.index()
	chunk.mesh = surface.commit()
	print("Chunk mesh generated in "+str(OS.get_ticks_msec() - t)+" ms")
	t = OS.get_ticks_msec()
	chunk.create_trimesh_collision()
	#chunk.create_convex_collision()
	print("Chunk collider generated in "+str(OS.get_ticks_msec() - t)+" ms")
	add_child(chunk)
	return chunk
	

func cull_voxels():
	var nb_culled = 0
	for pos in world.keys():
		var culling_info = find_adjacent_cubes(pos)
		var to_cull = culling_info[0]
		var faces_to_cull = culling_info[1]
		if to_cull:
			world[pos] = -world[pos]
			nb_culled += 1
	return nb_culled
		
func find_adjacent_cubes(pos):
	var dirs = [Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1), Vector3(-1,0,0),Vector3(0,-1,0),Vector3(0,0,-1)]
	var adjacent_faces = []
	var culled = true
	for normal in dirs:
		var adjacent_cube = pos + normal
		if not world.has(adjacent_cube):
			culled = false
		else:
			adjacent_faces.append(normal)
	return [culled, adjacent_faces]
	
func find_adjacent_faces(pos):
	var dirs = [Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1), Vector3(-1,0,0),Vector3(0,-1,0),Vector3(0,0,-1)]
	var adjacent_faces = []
	for normal in dirs:
		var adjacent_cube = pos + normal
		if world.has(adjacent_cube):
			adjacent_faces.append(normal)
	return adjacent_faces

func cube_at(pos, type, faces_to_cull):
	var dirs = [Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1)]	
	for i in range(3):
		for k in range(2):
			var n = dirs[i]*-(k*2 -1)
			if not faces_to_cull.has(n):
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
				var h = sum / (m + rand_range(-half_step, half_step))
				heightmap.set(x, y, h)
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