extends Control

func _process(delta):
	$monitor/fpsLine/fps.set_text(str(Engine.get_frames_per_second()))
	$monitor/cpuMemStaticLine/cpuMemStatic.set_text(str(int(Performance.get_monitor(Performance.MEMORY_STATIC)/1000000)))
	$monitor/cpuMemDynLine/cpuMemDyn.set_text(str(int(Performance.get_monitor(Performance.MEMORY_DYNAMIC)/1000000)))
	$monitor/GPUmemLine/GPUmem.set_text(str(int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1000000)))