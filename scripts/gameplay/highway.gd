class_name HighwayVisual
extends Control

const LANE_COUNT: int = 5
const HIT_LINE_RATIO: float = 0.85
const LEFT_COMPRESSION: float = 0.50 # As cordas se juntam mais na esquerda (perspectiva 3D)

const NOTE_COLORS: Array[Color] = [
	Color(0.2, 0.75, 0.65), # Teal
	Color(0.35, 0.6, 0.85), # Blue
	Color(0.85, 0.75, 0.3), # Gold
	Color(0.85, 0.45, 0.5), # Rose
	Color(0.6, 0.4, 0.75)   # Lavender
]

var receptor_glow: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var hit_glow: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var lane_glow: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var lane_held: Array[bool] = [false, false, false, false, false]

func _process(delta: float) -> void:
	var needs_redraw: bool = false
	for i in range(LANE_COUNT):
		if lane_held[i]:
			receptor_glow[i] = 1.0
			lane_glow[i] = 1.0
			needs_redraw = true
		else:
			if receptor_glow[i] > 0.0:
				receptor_glow[i] = maxf(receptor_glow[i] - delta * 6.0, 0.0)
				needs_redraw = true
			if lane_glow[i] > 0.0:
				lane_glow[i] = maxf(lane_glow[i] - delta * 4.0, 0.0)
				needs_redraw = true
				
		if hit_glow[i] > 0.0:
			hit_glow[i] = maxf(hit_glow[i] - delta * 3.5, 0.0)
			needs_redraw = true
			
	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var hit_x: float = w * HIT_LINE_RATIO
	var spawn_x: float = 0.0

	# 1. Corpo do Instrumento Clássico (Madeira escura / fundo brilhante)
	var bg_color: Color = Color(0.04, 0.04, 0.06, 0.85)
	draw_polygon(
		PackedVector2Array([
			Vector2(0, h * 0.15), Vector2(w, 0),
			Vector2(w, h), Vector2(0, h * 0.85),
		]),
		PackedColorArray([bg_color, bg_color, bg_color, bg_color])
	)

	# 2. O Cavalete (A "Ponte" onde os hits ocorrem à direita)
	var bridge_w: float = 24.0
	draw_rect(Rect2(hit_x - bridge_w/2, h * 0.05, bridge_w, h * 0.9), Color(0.12, 0.08, 0.05)) # Madeira Base
	draw_rect(Rect2(hit_x - bridge_w/4, h * 0.05, bridge_w/3, h * 0.9), Color(0.3, 0.2, 0.12)) # Reflexo metálico da ponte

	# 3. As Cordas (Strings de Aço / Prata)
	for i in range(LANE_COUNT):
		var left_y: float = get_lane_top_center(i)
		var right_y: float = get_lane_bottom_center(i)

		# Sombra projetada da corda para dar profundidade real
		draw_line(Vector2(spawn_x, left_y + 4), Vector2(w, right_y + 4), Color(0, 0, 0, 0.7), 4.0, true)

		# Base Metálica da corda
		draw_line(Vector2(spawn_x, left_y), Vector2(w, right_y), Color(0.65, 0.65, 0.7), 3.0, true)
		
		# Destaque de luz (Specular / Brilho do aço)
		draw_line(Vector2(spawn_x, left_y - 0.5), Vector2(w, right_y - 0.5), Color(1.0, 1.0, 1.0, 0.8), 1.0, true)

		# Brilho de Vibração da Corda quando tocada
		var lg: float = lane_glow[i]
		if lg > 0.0:
			var g_col: Color = NOTE_COLORS[i]
			g_col.a = lg * 0.5
			draw_line(Vector2(spawn_x, left_y), Vector2(w, right_y), g_col, 8.0, true)
			
			# Pequena onda seno para simular a vibração da corda batendo
			var wave = sin(Time.get_ticks_msec() * 0.05) * (3.0 * lg)
			draw_line(Vector2(spawn_x, left_y + wave), Vector2(w, right_y + wave), g_col, 2.0, true)

	# 4. Receptores (Almofadas de Hit na Ponte)
	var receptor_r = (h * 0.75 / float(LANE_COUNT)) * 0.35
	for i in range(LANE_COUNT):
		var cy: float = get_lane_bottom_center(i)
		var cx: float = hit_x
		var col: Color = NOTE_COLORS[i]
		var rg: float = receptor_glow[i]
		var hg: float = hit_glow[i]

		# Desenha os anéis virados de lado (achatar no X para dar perspectiva isométrica)
		draw_set_transform(Vector2(cx, cy), 0, Vector2(0.4, 1.1))
		
		# Base inativa de metal
		draw_arc(Vector2.ZERO, receptor_r, 0, TAU, 32, Color(0.7, 0.75, 0.85, 0.5), 3.0, true)

		# Glow ao pressionar
		if rg > 0.0:
			var press_c: Color = col
			press_c.a = rg * 0.8
			draw_arc(Vector2.ZERO, receptor_r, 0, TAU, 32, press_c, 5.0, true)
			press_c.a = rg * 0.25
			draw_circle(Vector2.ZERO, receptor_r, press_c)
		
		# Ripple (impacto na corda)
		if hg > 0.0:
			var ripple_c: Color = col
			ripple_c.a = hg * 0.9
			draw_arc(Vector2.ZERO, receptor_r + (hg * 45.0), 0, TAU, 32, ripple_c, 4.0, true)
		
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func set_lane_held(lane: int, is_held: bool) -> void:
	if lane >= 0 and lane < LANE_COUNT:
		lane_held[lane] = is_held
		if is_held:
			receptor_glow[lane] = 1.0
			lane_glow[lane] = 1.0
		queue_redraw()

func press_receptor(lane: int) -> void:
	if lane >= 0 and lane < LANE_COUNT:
		receptor_glow[lane] = 1.0
		lane_glow[lane] = 1.0
		queue_redraw()

func hit_receptor(lane: int) -> void:
	if lane >= 0 and lane < LANE_COUNT:
		hit_glow[lane] = 1.0
		queue_redraw()

func get_hit_y() -> float:
	return size.x * HIT_LINE_RATIO

func get_lane_top_center(lane: int) -> float:
	# Retorna o Y na ESQUERDA (comprimido pela perspectiva)
	var h: float = size.y
	var center_y: float = h * 0.5
	var total_spacing: float = h * LEFT_COMPRESSION
	var start_y: float = center_y - (total_spacing * 0.5)
	return start_y + (total_spacing / float(LANE_COUNT)) * (float(lane) + 0.5)

func get_lane_bottom_center(lane: int) -> float:
	# Retorna o Y na DIREITA (espaçamento normal no Hit)
	var h: float = size.y
	var center_y: float = h * 0.5
	var total_spacing: float = h * 0.80
	var start_y: float = center_y - (total_spacing * 0.5)
	return start_y + (total_spacing / float(LANE_COUNT)) * (float(lane) + 0.5)
