extends Node

var simplex = load("res://simplex/Simplex.gd")

func generate_height_with_simplex(size):
	var t = OS.get_ticks_msec()
	var world = {}
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
	print("World map generated in "+str(OS.get_ticks_msec() - t)+" ms")
	return [world, highest]

func generate_heightmap(size):
	var t = OS.get_ticks_msec()
	var map = Array2D.new(size, size)
	var highest = 0
	for x in range(size):
		for z in range(size):
			var xforsim = x * 0.05+40
			var yforsim = z * 0.05+2000
			var h = 1 + (((simplex.simplex2(xforsim,yforsim)+1)*0.5) * 16)
			if h > highest:
				highest = h
			map.set(x, z, h)
	print("Heightmap generated in "+str(OS.get_ticks_msec() - t)+" ms")
	return [map, highest]

func new_array2D(w, h):
	return Array2D.new(w, h)
	
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