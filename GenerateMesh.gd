extends Spatial

var angle = 0
var simplex = load("res://simplex/Simplex.gd")
var texture = load("res://assets/spritesheet_tiles.png")
var shader = load("res://shaders/greedy_mesh.shader")
var surface = SurfaceTool.new()
var mat = SpatialMaterial.new()
var greedy_mat = ShaderMaterial.new()
var chunk = MeshInstance.new()
var static_body = StaticBody.new()
var col_shape = CollisionShape.new()
var shape = ConcavePolygonShape.new()
var voxel_dirt_and_grass #type = 1
var voxel_dirt #type = 2
var world = {}
var highest
var thread = Thread.new()
var generated = false

func _ready():
	mat.albedo_texture = texture
	greedy_mat.shader = shader
	greedy_mat.set_shader_param("texture_albedo", texture)
	#mat.albedo_color = Color(255,0,0)
	#mat.set_flag(SpatialMaterial.FLAG_UNSHADED, true)
	"""add_child(chunk)
	chunk.add_child(static_body)
	static_body.add_child(col_shape)
	col_shape.set_shape(shape)"""

	var t = OS.get_ticks_msec()
	#generate_heightmap(5)
	highest = generate_height_with_simplex(32)
	#create_chunk()
	print(str(OS.get_ticks_msec() - t)+" ms")
	print("Before thread")
	if thread.is_active():
		# Already working
		return
	#thread.start(self, "create_chunk")
	
	thread.start(self, "greedy_mesher", 32)
	print("After thread")
	#create_chunk(16)
	#greedy_mesher(32)
	#var vol_test = Quad3D.new(Vector3(0,0,0), 2,1,1)
	#thread.start(self, "test_volume", vol_test)
	

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
	var highest = 0
	for x in range(size):
		for z in range(size):
			var xforsim = x * 0.05+40
			var yforsim = z * 0.05+2000
			var h = 1 + (((simplex.simplex2(xforsim,yforsim)+1)*0.5) * 16)
			if h > highest:
				highest = h
			for y in range(h):
				world[Vector3(x,y,z)] = 1
	return highest

func create_chunk(size):
	print("Chunk build started!")
	var t = OS.get_ticks_msec()
	surface.clear()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	#surface.set_material(mat)
	surface.set_material(greedy_mat)
	for pos in world.keys():
		if world[pos] > 0:
			var faces_to_cull = find_adjacent_faces(pos)
			cube_at(pos, 2, faces_to_cull)
	surface.index()
	chunk.mesh = surface.commit()
	print("Chunk mesh generated in "+str(OS.get_ticks_msec() - t)+" ms")
	t = OS.get_ticks_msec()
	#chunk.create_trimesh_collision()
	#chunk.create_convex_collision()
	shape.set_faces(chunk.mesh.get_faces())
	print("Chunk collider generated in "+str(OS.get_ticks_msec() - t)+" ms")
	generated = true
	return chunk
	
func on_mesh_generated():
	var t = OS.get_ticks_msec()
	print("on_mesh_generated start")
	var new_chunk = MeshInstance.new()
	new_chunk.set_mesh(surface.commit())
	print("Checkpoint 4: "+str(OS.get_ticks_msec() - t)+" ms /")
	
	print("Chunk generated in "+str(OS.get_ticks_msec() - t)+" ms")
	t = OS.get_ticks_msec()
	#shape.set_faces(chunk.mesh.get_faces())
	new_chunk.create_trimesh_collision()
	print("Chunk collider generated in "+str(OS.get_ticks_msec() - t)+" ms")
	
	add_child(new_chunk)
	print("Chunk added to tree"+str(OS.get_ticks_msec() - t)+" ms")
	generated = true

func greedy_mesher(size):
	print("Greedy mesh start!")
	var t = OS.get_ticks_msec()
	surface.clear()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(greedy_mat)
	var polys = []
	for y in range(highest+1):
		#compute the plane mask along the Y axis
		var mask = Array2D.new(size,size)
		for x in range(size):
			for z in range(size):
				var pos = Vector3(x,y,z)
				if world.has(pos):
					mask.set(x,z,world[pos])
				else:
					mask.set(x,z,0)
		#search quads in the mask
		var volume
		for x in range(size):
			var start = false
			for z in range(size):
				if mask.at(x,z) == 1:
					if not start:
						start = true
						volume = Quad3D.new(Vector3(x,y,z),1,1,1)
					else:
						volume.depth += 1
					#if z < (size-1):
					#	if mask.at(x,z+1) != 1
					if z == (size - 1):
						var x_max = find_x_max(volume, mask)
						volume.width += x_max - volume.pos.x
						polys.append(volume)
				else:
					if start:
						start = false
						var x_max = find_x_max(volume, mask)
						volume.width += x_max - volume.pos.x
						polys.append(volume)
	print("Checkpoint: "+str(OS.get_ticks_msec() - t)+" ms")
	print(str(polys.size()))
	for vol in polys:
		create_volume_vertex(vol)
	print("Checkpoint 2: "+str(OS.get_ticks_msec() - t)+" ms")
	surface.index()
	print("Checkpoint 3: "+str(OS.get_ticks_msec() - t)+" ms")
	call_deferred("on_mesh_generated")
	"""var new_chunk = MeshInstance.new()
	new_chunk.set_mesh(surface.commit())
	print("Checkpoint 4: "+str(OS.get_ticks_msec() - t)+" ms /")
	
	print("Chunk generated in "+str(OS.get_ticks_msec() - t)+" ms")
	t = OS.get_ticks_msec()
	#shape.set_faces(chunk.mesh.get_faces())
	new_chunk.create_trimesh_collision()
	print("Chunk collider generated in "+str(OS.get_ticks_msec() - t)+" ms")
	
	#call_deferred("add_child", new_chunk)
	return new_chunk"""
	

func find_x_max(volume, mask):
	for x in range(volume.pos.x+1, mask.width):
		for z in range(volume.pos.z, volume.pos.z + volume.depth):
			if mask.at(x,z) == 1:
				mask.set(x,z,0)
			else:
				return x
	return mask.width-1

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

func test_volume(vol):
	print("Greedy mesh start!")
	var t = OS.get_ticks_msec()
	print(vol.to_str())
	surface.clear()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(mat)
	create_volume_vertex(vol)
	surface.index()
	chunk.mesh = surface.commit()
	print("Checkpoint: "+str(OS.get_ticks_msec() - t)+" ms")
	#shape.set_faces(chunk.mesh.get_faces())
			
func create_volume_vertex(volume):
	var verts = []
	var dirs = [Vector3(1,0,0),Vector3(0,1,0),Vector3(0,0,1), Vector3(-1,0,0),Vector3(0,-1,0),Vector3(0,0,-1)]
	var x1 = volume.pos.x
	var x2 = x1 + volume.width
	var y1 = volume.pos.y
	var y2 = y1 + volume.height
	var z1 = volume.pos.z
	var z2 = z1 + volume.depth
	var uv_scale
	for n in dirs:
		if n.z == -1:
			verts = [Vector3(x1, y1, z1),
					Vector3(x2, y1, z1),
					Vector3(x2, y2, z1),
					Vector3(x2, y2, z1),
					Vector3(x1, y2, z1),
					Vector3(x1, y1, z1)]
			uv_scale = Vector2(volume.width, volume.height)
					
		elif n.z == 1:
			#[[1,0],[1,1],[0,1],[0,1],[0,0],[1,0]] #works for (0,0,1)
			#[[0,0],[0,1],[1,1],[1,1],[1,0],[0,0]] #test
			verts = [Vector3(x1, y1, z2),
					Vector3(x1, y2, z2),
					Vector3(x2, y2, z2),
					Vector3(x2, y2, z2),
					Vector3(x2, y1, z2),
					Vector3(x1, y1, z2)]
			uv_scale = Vector2(volume.width, volume.height)
					
		elif n.x == -1:
			verts = [Vector3(x1, y1, z1),
					Vector3(x1, y2, z1),
					Vector3(x1, y2, z2),
					Vector3(x1, y2, z2),
					Vector3(x1, y1, z2),
					Vector3(x1, y1, z1)]
			uv_scale = Vector2(volume.depth, volume.height)
					
		elif n.x == 1:
			verts = [Vector3(x2, y1, z1),
					Vector3(x2, y1, z2),
					Vector3(x2, y2, z2),
					Vector3(x2, y2, z2),
					Vector3(x2, y2, z1),
					Vector3(x2, y1, z1)]
			uv_scale = Vector2(volume.depth, volume.height)
					
		elif n.y == -1:
			verts = [Vector3(x1, y1, z1),
					Vector3(x2, y1, z1),
					Vector3(x2, y1, z2),
					Vector3(x2, y1, z2),
					Vector3(x1, y1, z2),
					Vector3(x1, y1, z1)]
			uv_scale = Vector2(volume.width, volume.depth)
					
		elif n.y == 1:
			verts = [Vector3(x1, y2, z1),
					Vector3(x2, y2, z1),
					Vector3(x2, y2, z2),
					Vector3(x2, y2, z2),
					Vector3(x1, y2, z2),
					Vector3(x1, y2, z1)]
			uv_scale = Vector2(volume.width, volume.depth)
					
		var uvInfo = calcUV(2, n)
		var uv_offset = uvInfo[1]
		var order_uv = uvInfo[0]
		for v in range(6):
			var uv_vec = Vector2(order_uv[v][0] * uv_scale[0], order_uv[v][1] * uv_scale[1])
			surface.add_uv(uv_vec)
			surface.add_uv2(uv_offset)
			surface.add_normal(n)
			surface.add_vertex(verts[v])

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
	#surface.set_material(mat)
	for v in range(6):
		var uv_vec = Vector2(order_uv[v][0],order_uv[v][1])
		#uv_vec.x *= u_size
		#uv_vec.y *= v_size
		#uv_offset.x *= u_size
		#uv_offset.y *= v_size
		#surface.add_uv(Vector2(uv_offset.x * u_size, uv_offset.y * v_size) + uv_vec) #surface.add_uv((uv_offset * uv_size) + (uv_size * Vector2(order_uv[v][0],order_uv[v][1])))
		surface.add_uv(uv_vec)
		surface.add_uv2(uv_offset)
		surface.add_normal(normal)
		surface.add_vertex(verts[order_v[v]] + pos)
		
func calcUV(type,normal):
	var uv_orderList = [[1,0],[1,1],[0,1],[0,1],[0,0],[1,0]] #works for (0,0,1)
	
	var uvoffset = Vector2(2,0)
	if type == 1 and normal == Vector3(0,1,0):
		uvoffset = Vector2(0,0)
	if type == 2:
		if normal == Vector3(1,0,0):
			uv_orderList = [[1,1],[0,1],[0,0],[0,0],[1,0],[1,1]] #[[0,0],[1,0],[1,1],[1,1],[0,1],[0,0]] #works for (1,0,0)
			uvoffset = Vector2(5,0)
		elif normal == Vector3(-1,0,0):
			uv_orderList = [[0,1],[0,0],[1,0],[1,0],[1,1],[0,1]] #works for (-1,0,0)
			uvoffset = Vector2(5,0)
		elif normal == Vector3(0,1,0):
			uv_orderList = [[0,0],[1,0],[1,1],[1,1],[0,1],[0,0]] #[[0,1],[0,0],[1,0],[1,0],[1,1],[0,1]]
			uvoffset = Vector2(4,6)
		elif normal == Vector3(0,-1,0):
			
			uvoffset = Vector2(5,1)
		elif normal == Vector3(0,0,1):
			uv_orderList = [[0,1],[0,0],[1,0],[1,0],[1,1],[0,1]] #[[0,0],[0,1],[1,1],[1,1],[1,0],[0,0]] 
			uvoffset = Vector2(5,0)
		elif normal == Vector3(0,0,-1):
			uv_orderList = [[1,1],[0,1],[0,0],[0,0],[1,0],[1,1]]
			#uv_orderList = [[0,0],[1,0],[1,1],[1,1],[0,1],[0,0]]
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
	
class Quad3D:
	var pos
	var width
	var height
	var depth
	
	func _init(p, w, h, d):
		pos = p
		width = w
		height = h
		depth = d
		
	func to_str():
		return "Pos: "+str(pos)+", w: "+str(width)+", h: "+str(height)+", d: "+str(depth)
	
	
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