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

# What makes this fast: a shape is not built vertex by vertex in script.
# Its points are a small table (a ring of unit directions, a quad) placed
# by one transform in one engine call, and the parts that do not depend on
# where it is drawn (texture coordinates, the triangle list for a given
# start index) are kept and reused. A face's small dots and arcs, which
# were four fifths of its drawing time, cost a fifth of what they did.
const QUAD_UV: PackedVector2Array = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
const LINE_UV: PackedVector2Array = [UV_A, UV_B, UV_A, UV_B]
const CACHE_MAX := 4096
static var _ring := PackedVector2Array()   # twelve unit directions (the small disc's rim)
static var _solid_uv := {}                 # n -> n x SOLID
static var _strip_uv := {}                 # n -> n x UV_A, then n x UV_B
static var _fan_idx := {}                  # first vertex -> a small disc's triangles
static var _strip_idx := {}                # (first vertex, n) -> a strip's triangles
static var _arc_dirs := {}                 # (from, to, n) -> unit directions along an arc
var _dot_col := Color(0, 0, 0, 0)          # the colour the two arrays below were made for
var _dot_in := PackedColorArray()          # centre and inner rim: the colour
var _dot_out := PackedColorArray()         # outer rim: the colour, clear


func clear() -> void:
	pts.clear()
	uvs.clear()
	cols.clear()
	idx.clear()
	xf = Transform2D.IDENTITY
	_ident = true


## Empties the buffers but keeps the current transform (for drawing code
## that flushes between runs of shapes, see Hud.TopBar).
func reset_buffers() -> void:
	pts.clear()
	uvs.clear()
	cols.clear()
	idx.clear()


## Submits everything collected to canvas item `ci` (one draw call).
func flush(ci: RID) -> void:
	if idx.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), Pal.circle_tex().get_rid())


func draw_set_transform_matrix(m: Transform2D) -> void:
	xf = m
	_ident = m == Transform2D.IDENTITY


## Four corners (in order round the shape) as two triangles.
func _quad(q: PackedVector2Array, uv: PackedVector2Array, col: Color) -> void:
	var i := pts.size()
	pts.append_array(q if _ident else xf * q)
	uvs.append_array(uv)
	cols.append_array(PackedColorArray([col, col, col, col]))
	idx.append_array(PackedInt32Array([i, i + 1, i + 2, i, i + 2, i + 3]))


static func _solid(n: int) -> PackedVector2Array:
	if not _solid_uv.has(n):
		var a := PackedVector2Array()
		a.resize(n)
		a.fill(SOLID)
		_solid_uv[n] = a
	return _solid_uv[n]


## A filled disc with a soft one-pixel edge (as Pal.disc).
func disc(c: Vector2, r: float, col: Color) -> void:
	if col.a <= 0.0 or r <= 0.0:
		return
	var px := r * (1.0 if _ident else xf.get_scale().x)
	if px < 6.0:
		_small_disc(c, r, col, px)
		return
	var e := r + 0.45
	_quad(PackedVector2Array([c + Vector2(-e, -e), c + Vector2(e, -e), c + Vector2(e, e), c + Vector2(-e, e)]), QUAD_UV, col)


## A tiny disc sampled from the texture would come from a coarse mip and
## look square; it is built instead as a fan with a one-pixel feather ring
## that fades out, which is round and soft at any size. Its vertices are
## the centre, an inner rim of twelve and an outer rim of twelve: each rim
## is the unit ring placed by one transform.
func _small_disc(c: Vector2, r: float, col: Color, px: float) -> void:
	const SEG := 12
	if _ring.is_empty():
		for i in SEG:
			_ring.append(Vector2.from_angle(TAU * i / SEG))
	var feather := r / maxf(px, 0.5)   # one pixel, in local units
	var inner := maxf(r - feather * 0.5, r * 0.3)
	var outer := r + feather * 0.5
	var t_in := Transform2D(Vector2(inner, 0.0), Vector2(0.0, inner), c)
	var t_out := Transform2D(Vector2(outer, 0.0), Vector2(0.0, outer), c)
	if not _ident:
		t_in = xf * t_in
		t_out = xf * t_out
	var base := pts.size()
	pts.append(t_in.origin)
	pts.append_array(t_in * _ring)
	pts.append_array(t_out * _ring)
	uvs.append_array(_solid(SEG * 2 + 1))
	if col != _dot_col or _dot_in.is_empty():
		_dot_col = col
		_dot_in.resize(SEG + 1)
		_dot_in.fill(col)
		_dot_out.resize(SEG)
		_dot_out.fill(Color(col, 0.0))
	cols.append_array(_dot_in)
	cols.append_array(_dot_out)
	if not _fan_idx.has(base):
		if _fan_idx.size() >= CACHE_MAX:
			_fan_idx.clear()
		var tri := PackedInt32Array()
		tri.resize(SEG * 9)
		for i in SEG:
			var a := base + 1 + i
			var b := base + 1 + (i + 1) % SEG
			var q := i * 9
			tri[q] = base
			tri[q + 1] = a
			tri[q + 2] = b
			tri[q + 3] = a
			tri[q + 4] = a + SEG
			tri[q + 5] = b + SEG
			tri[q + 6] = a
			tri[q + 7] = b + SEG
			tri[q + 8] = b
		_fan_idx[base] = tri
	idx.append_array(_fan_idx[base])


func draw_circle(c: Vector2, r: float, col: Color, filled := true, width := -1.0, _aa := false) -> void:
	if filled:
		disc(c, r, col)
	else:
		draw_arc(c, r, 0.0, TAU, maxi(24, int(r * 1.2)), col, width, true)


func draw_rect(rect: Rect2, col: Color, filled := true, width := -1.0) -> void:
	if filled:
		_quad(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), _solid(4), col)
	else:
		var p := rect.position
		var e := rect.end
		draw_polyline(PackedVector2Array([p, Vector2(e.x, p.y), e, Vector2(p.x, e.y), p]), col, width)


## Half a stroke's width as drawn: half the stroke plus half a pixel of
## falloff; the thinnest strokes a touch more, as the coarse mip they
## sample is softer.
static func _half(width: float) -> float:
	var w := maxf(width, 1.0)
	return w * 0.5 + (0.5 if w >= 2.5 else 0.8)


func draw_line(a: Vector2, b: Vector2, col: Color, width := -1.0, _aa := false) -> void:
	if col.a <= 0.0:
		return
	var off := (b - a).normalized().orthogonal() * _half(width)
	var q := PackedVector2Array([a - off, a + off, b - off, b + off])
	var i := pts.size()
	pts.append_array(q if _ident else xf * q)
	uvs.append_array(LINE_UV)
	cols.append_array(PackedColorArray([col, col, col, col]))
	idx.append_array(PackedInt32Array([i, i + 1, i + 3, i, i + 3, i + 2]))


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
	var hw := _half(width)
	# The two edges of the strip, each as one run of points (the first
	# edge, then the second), so texture coordinates and triangles are the
	# ready-made ones of a strip of n points (see draw_arc).
	var ea := PackedVector2Array()
	var eb := PackedVector2Array()
	ea.resize(n)
	eb.resize(n)
	# Each point is pushed out along the mitre of the segments meeting there
	# (one normal per segment, carried over to the next point).
	var prev := (line[1] - line[0]).normalized().orthogonal()
	var last := n - 1
	for i in n:
		var off := prev * hw
		if i > 0 and i < last:
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
		ea[i] = p - off
		eb[i] = p + off
	var base := pts.size()
	if _ident:
		pts.append_array(ea)
		pts.append_array(eb)
	else:
		pts.append_array(xf * ea)
		pts.append_array(xf * eb)
	uvs.append_array(_strip_uvs(n))
	if colors.size() == n:
		cols.append_array(colors)
		cols.append_array(colors)
	else:
		var cc := PackedColorArray()
		cc.resize(n * 2)
		cc.fill(col)
		cols.append_array(cc)
	idx.append_array(_strip_tris(base, n))


## Texture coordinates of a strip of n points: one edge, then the other.
static func _strip_uvs(n: int) -> PackedVector2Array:
	if not _strip_uv.has(n):
		var uv := PackedVector2Array()
		uv.resize(n * 2)
		uv.fill(UV_A)
		for i in n:
			uv[n + i] = UV_B
		_strip_uv[n] = uv
	return _strip_uv[n]


## Triangles of a strip of n points whose first edge starts at `base` and
## whose second edge follows it.
static func _strip_tris(base: int, n: int) -> PackedInt32Array:
	var ik := Vector2i(base, n)
	if not _strip_idx.has(ik):
		if _strip_idx.size() >= CACHE_MAX:
			_strip_idx.clear()
		var tri := PackedInt32Array()
		tri.resize((n - 1) * 6)
		for i in n - 1:
			var a := base + i
			var q := i * 6
			tri[q] = a
			tri[q + 1] = a + n
			tri[q + 2] = a + n + 1
			tri[q + 3] = a
			tri[q + 4] = a + n + 1
			tri[q + 5] = a + 1
		_strip_idx[ik] = tri
	return _strip_idx[ik]


## A stroke along an arc. Its two edges are the arc's unit directions
## (kept per angle range, so a ring that is drawn every frame works them
## out once) placed at the inner and the outer radius by one transform
## each, instead of a polyline with a mitre worked out at every point.
func draw_arc(c: Vector2, r: float, a0: float, a1: float, segs: int, col: Color, width := -1.0, _aa := false) -> void:
	if col.a <= 0.0:
		return
	# About one segment per 5 px of arc, and never fewer than a dozen for a
	# whole turn, keeps even small rings round.
	var sweep := absf(a1 - a0)
	segs = clampi(segs, 2, maxi(int(12.0 * sweep / TAU) + 2, int(r * sweep / 5.0)))
	var n := segs + 1
	var key := Vector3(a0, a1, n)
	if not _arc_dirs.has(key):
		if _arc_dirs.size() >= CACHE_MAX:
			_arc_dirs.clear()
		var d := PackedVector2Array()
		d.resize(n)
		for i in n:
			d[i] = Vector2.from_angle(lerpf(a0, a1, float(i) / segs))
		_arc_dirs[key] = d
	var dirs: PackedVector2Array = _arc_dirs[key]
	# The edges are pushed out along the mitre of the chords meeting at
	# each point: 1 / cos(half a step) further than half the width.
	var m := _half(width) * clampf(1.0 / maxf(cos(sweep / segs * 0.5), 0.3), 1.0, 2.0)
	var t_a := Transform2D(Vector2(r - m, 0.0), Vector2(0.0, r - m), c)
	var t_b := Transform2D(Vector2(r + m, 0.0), Vector2(0.0, r + m), c)
	if not _ident:
		t_a = xf * t_a
		t_b = xf * t_b
	var base := pts.size()
	pts.append_array(t_a * dirs)
	pts.append_array(t_b * dirs)
	uvs.append_array(_strip_uvs(n))
	var cc := PackedColorArray()
	cc.resize(n * 2)
	cc.fill(col)
	cols.append_array(cc)
	idx.append_array(_strip_tris(base, n))


func draw_colored_polygon(poly: PackedVector2Array, col: Color) -> void:
	var n := poly.size()
	if n < 3 or col.a <= 0.0:
		return
	var tri := Geometry2D.triangulate_polygon(poly)
	if tri.is_empty():
		return
	var base := pts.size()
	pts.append_array(poly if _ident else xf * poly)
	uvs.append_array(_solid(n))
	var cc := PackedColorArray()
	cc.resize(n)
	cc.fill(col)
	cols.append_array(cc)
	for k in tri:
		idx.append(base + k)
