class_name Ink
extends RefCounted
## Collects a whole layer of small vector drawing (discs, lines, arcs and
## filled shapes) into one triangle array sampled from the shared disc
## texture, so an enemy's face costs a single draw call instead of one per
## line and polygon. The methods mirror CanvasItem's, so drawing code can
## take an Ink where it took a node.
##
## How the one texture serves every shape:
##  - discs map the whole texture onto a quad (its edge is the disc's edge);
##  - lines map a diameter across their width, so the texture's falloff
##    (and its mipmaps, as the quad gets thin) gives them soft edges;
##  - filled shapes sample the solid centre.

const SOLID := Vector2(0.5, 0.5)
const UV_A := Vector2(0.5, 0.0)   # one side of a stroke
const UV_B := Vector2(0.5, 1.0)   # the other

var pts := PackedVector2Array()
var uvs := PackedVector2Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()
var xf := Transform2D.IDENTITY
var _ident := true


func clear() -> void:
	pts.clear()
	uvs.clear()
	cols.clear()
	idx.clear()
	xf = Transform2D.IDENTITY
	_ident = true


## Submits everything collected to canvas item `ci` (one draw call).
func flush(ci: RID) -> void:
	if idx.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), Pal.circle_tex().get_rid())


func draw_set_transform_matrix(m: Transform2D) -> void:
	xf = m
	_ident = m == Transform2D.IDENTITY


func _vert(p: Vector2, uv: Vector2, c: Color) -> void:
	pts.append(p if _ident else xf * p)
	uvs.append(uv)
	cols.append(c)


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, col: Color) -> void:
	var i := pts.size()
	_vert(a, ua, col)
	_vert(b, ub, col)
	_vert(c, uc, col)
	_vert(d, ud, col)
	idx.append_array([i, i + 1, i + 2, i, i + 2, i + 3])


## A filled disc with a soft one-pixel edge (as Pal.disc).
func disc(c: Vector2, r: float, col: Color) -> void:
	if col.a <= 0.0 or r <= 0.0:
		return
	var e := r + 0.45
	_quad(c + Vector2(-e, -e), c + Vector2(e, -e), c + Vector2(e, e), c + Vector2(-e, e),
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), col)


func draw_circle(c: Vector2, r: float, col: Color, filled := true, width := -1.0, _aa := false) -> void:
	if filled:
		disc(c, r, col)
	else:
		draw_arc(c, r, 0.0, TAU, maxi(24, int(r * 1.2)), col, width, true)


func draw_rect(rect: Rect2, col: Color, filled := true, width := -1.0) -> void:
	if filled:
		_quad(rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y),
			SOLID, SOLID, SOLID, SOLID, col)
	else:
		var p := rect.position
		var e := rect.end
		draw_polyline(PackedVector2Array([p, Vector2(e.x, p.y), e, Vector2(p.x, e.y), p]), col, width)


func draw_line(a: Vector2, b: Vector2, col: Color, width := -1.0, _aa := false) -> void:
	draw_polyline(PackedVector2Array([a, b]), col, width)


## A stroke of `width` px along `line`: one strip with mitred joins (no
## overlaps where segments meet, so translucent strokes stay even).
func draw_polyline(line: PackedVector2Array, col: Color, width := -1.0, _aa := false) -> void:
	if col.a <= 0.0:
		return
	_stroke(line, PackedColorArray(), col, width)


## As draw_polyline, with a colour per point.
func draw_polyline_colors(line: PackedVector2Array, colors: PackedColorArray, width := -1.0, _aa := false) -> void:
	_stroke(line, colors, Color.WHITE, width)


func _stroke(line: PackedVector2Array, colors: PackedColorArray, col: Color, width: float) -> void:
	var n := line.size()
	if n < 2:
		return
	var per := colors.size() == n
	# Half the stroke plus half a pixel of falloff; the thinnest strokes a
	# touch more, as the coarse mip they sample is softer.
	var w := maxf(width, 1.0)
	var hw := w * 0.5 + (0.5 if w >= 2.5 else 0.8)
	var base := pts.size()
	pts.resize(base + n * 2)
	uvs.resize(base + n * 2)
	cols.resize(base + n * 2)
	# Each point is pushed out along the mitre of the segments meeting there
	# (one normal per segment, carried over to the next point).
	var prev := (line[1] - line[0]).normalized().orthogonal()
	for i in n:
		var off := prev * hw
		if i > 0 and i < n - 1:
			var cur := (line[i + 1] - line[i]).normalized().orthogonal()
			var m := prev + cur
			var ml := m.length_squared()
			if ml > 1e-6:
				m /= sqrt(ml)
				off = m * (hw * clampf(1.0 / maxf(m.dot(cur), 0.3), 1.0, 2.0))
			else:
				off = cur * hw
			prev = cur
		var p := line[i]
		var k := base + i * 2
		if _ident:
			pts[k] = p - off
			pts[k + 1] = p + off
		else:
			pts[k] = xf * (p - off)
			pts[k + 1] = xf * (p + off)
		uvs[k] = UV_A
		uvs[k + 1] = UV_B
		var c := colors[i] if per else col
		cols[k] = c
		cols[k + 1] = c
	var ib := idx.size()
	idx.resize(ib + (n - 1) * 6)
	for i in n - 1:
		var a := base + i * 2
		var q := ib + i * 6
		idx[q] = a
		idx[q + 1] = a + 1
		idx[q + 2] = a + 3
		idx[q + 3] = a
		idx[q + 4] = a + 3
		idx[q + 5] = a + 2


func draw_arc(c: Vector2, r: float, a0: float, a1: float, segs: int, col: Color, width := -1.0, _aa := false) -> void:
	if col.a <= 0.0:
		return
	var line := PackedVector2Array()
	# About one segment per 6 px of arc is smooth at these sizes.
	segs = clampi(segs, 2, maxi(6, int(r * absf(a1 - a0) / 6.0)))
	for i in segs + 1:
		line.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / segs)) * r)
	draw_polyline(line, col, width)


func draw_colored_polygon(poly: PackedVector2Array, col: Color) -> void:
	if poly.size() < 3 or col.a <= 0.0:
		return
	var tri := Geometry2D.triangulate_polygon(poly)
	if tri.is_empty():
		return
	var base := pts.size()
	for p in poly:
		_vert(p, SOLID, col)
	for k in tri:
		idx.append(base + k)
