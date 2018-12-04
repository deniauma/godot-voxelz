extends MeshInstance

var SIZE = 16

var texture = load("res://assets/spritesheet_tiles.png")
var shader = load("res://shaders/greedy_mesh.shader")
var surface = SurfaceTool.new()
var greedy_mat = ShaderMaterial.new()
var static_body = StaticBody.new()
var col_shape = CollisionShape.new()
var shape = ConcavePolygonShape.new()
var voxel_dirt_and_grass #type = 1
var voxel_dirt #type = 2
var world
var highest
var thread = Thread.new()
var generated = false

func create(h_map, h_highest):
	print("Map size: "+str(h_map.size()))
	world = h_map
	highest = h_highest
	greedy_mat.shader = shader
	greedy_mat.set_shader_param("texture_albedo", texture)
	"""chunk.add_child(static_body)
	static_body.add_child(col_shape)
	col_shape.set_shape(shape)"""

	if thread.is_active():
		# Already working
		return
	
	#thread.start(self, "greedy_mesher", SIZE)
	greedy_mesher(SIZE)
	#var vol_test = Quad3D.new(Vector3(0,0,0), 2,1,1)
	#thread.start(self, "test_volume", vol_test)
	
	
func on_mesh_generated():
	var t = OS.get_ticks_msec()
	print("on_mesh_generated start")
	set_mesh(surface.commit())
	print("Checkpoint 4: "+str(OS.get_ticks_msec() - t)+" ms /")
	
	print("Chunk generated in "+str(OS.get_ticks_msec() - t)+" ms")
	t = OS.get_ticks_msec()
	#shape.set_faces(chunk.mesh.get_faces())
	create_trimesh_collision()
	print("Chunk collider generated in "+str(OS.get_ticks_msec() - t)+" ms")
	
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
	#call_deferred("on_mesh_generated")
	on_mesh_generated()
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