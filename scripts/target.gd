class_name Target
extends "res://scripts/target_look.gd"
## Target, part 3 of 3: the face. Eye, lids, brows and mouth, and the small
## marks drawn over a body (badges, charms, arms, crowns, tears), all
## collected in one Ink and sent as a single draw call. See target_body.gd
## for the state and behaviour and target_look.gd for the body.

var _ink := Ink.new()              # the face's drawing, sent as one triangle array
var _face_tick := 0
var _face_phase := 0
var _eo := Vector2.ZERO            # the eye being drawn: its centre in body space
var _fc_col := Color.WHITE         # this face drawing's body colour (color() once a drawing)
static var _made := 0


func _ready() -> void:
	_face_phase = _made % 12
	_made += 1
	_pts.resize(N)
	_prev.resize(N)
	_jelly_reset()
	_setup_canvas()
	visible = false


## A small sign over the body as the stance changes: ! (wary), a flame
## (furious), a star (veteran).
func _draw_stance(f: Ink) -> void:
	if stance_flash <= 0.0 or phase != Phase.HANGING:
		return
	var a := minf(1.0, stance_flash * 2.0)
	var p := pos + Vector2(radius * 0.9, -radius * 0.95 - 8.0 * (1.0 - stance_flash))
	var col: Color = STANCE_TINT[stance].lightened(0.25)
	f.draw_circle(p, 8.0, Color(Pal.BG, 0.75 * a), true, -1.0, true)
	f.draw_arc(p, 8.0, 0.0, TAU, 20, Color(col, a), 1.2, true)
	match stance:
		Stance.WARY:
			f.draw_line(p + Vector2(0, -4.5), p + Vector2(0, 1.5), Color(col, a), 2.0, true)
			f.disc(p + Vector2(0, 4.2), 1.2, Color(col, a))
		Stance.FURIOUS:
			f.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5.5), p + Vector2(3.5, 1.5), p + Vector2(0, 5.0), p + Vector2(-3.5, 1.5)]), Color(col, a))
		Stance.VETERAN:
			var star := PackedVector2Array()
			for i in 10:
				var r := 5.0 if i % 2 == 0 else 2.2
				star.append(p + Vector2.from_angle(-PI * 0.5 + i * TAU / 10.0) * r)
			f.draw_colored_polygon(star, Color(col, a))


## The jelly arm, in world space: from the body's side to the hand, bent at
## the elbow and tapering, in the body's colour with a darker rim. Winding
## up it grows out, then draws back and trembles; the shove shoots it out
## to the neighbour's side; then it shrinks back in.
func _draw_arm(f: Ink) -> void:
	if arm == Arm.NONE or _gone:
		return
	var to := arm_to - pos
	var dist := to.length()
	if dist < 1.0:
		return
	var dir := to / dist
	var up := dir.orthogonal()
	if up.y > 0.0:
		up = -up
	var near := radius + 16.0
	# Reach for the neighbour's side, but never further than an arm's
	# length (a jelly arm stretches, it does not cross the room).
	var far := clampf(dist - (arm_victim.radius if arm_victim != null else 18.0) + 4.0, near, radius + ARM_REACH)
	# The hand's angle from the neighbour's direction toward straight up and
	# over (raised), and its distance from the centre.
	var th := 0.0
	var rr := near
	var shake := Vector2.ZERO
	match arm:
		Arm.WIND:
			var k := arm_t / ARM_WIND
			rr = lerpf(radius * 0.8, near, Motion.ease_value(Motion.Ease.ENTER, minf(1.0, k / 0.3)))
			th = 2.0 * Motion.ease_value(Motion.Ease.STANDARD, clampf((k - 0.3) / 0.5, 0.0, 1.0))
			shake = up.rotated(0.3) * sin(_clock * 55.0) * 1.8 * clampf((k - 0.7) / 0.3, 0.0, 1.0)
		Arm.SHOVE:
			var e := Motion.ease_value(Motion.Ease.EXIT, clampf(arm_t / 0.1, 0.0, 1.0))
			th = lerpf(2.0, 0.0, e)
			rr = lerpf(near, far, e)
		Arm.BACK:
			var e := Motion.ease_value(Motion.Ease.STANDARD, clampf(arm_t / 0.32, 0.0, 1.0))
			rr = lerpf(far, radius * 0.8, e)
	if rr <= radius * 0.82:
		return
	var hd := dir * cos(th) + up * sin(th)
	var hand := pos + hd * rr + shake
	var base := pos + hd * radius * 0.78
	var ext := clampf((rr - radius * 0.8) / maxf(1.0, far - radius * 0.8), 0.0, 1.0)
	var bend := hd.orthogonal()
	if bend.dot(up) < 0.0:
		bend = -bend
	var mid := base.lerp(hand, 0.5) + bend * (10.0 * (1.0 - 0.6 * ext))
	up = bend
	dir = hd
	var col := color()
	var rim := col.darkened(0.45)
	var pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		pts.append(base.lerp(mid, t).lerp(mid.lerp(hand, t), t))
	for pass_i in 3:
		for i in 8:
			var w := lerpf(12.0, 7.5, i / 7.0)
			var off := Vector2(2.0, 3.0) if pass_i == 0 else Vector2.ZERO
			var c: Color = [Color(0, 0, 0, 0.3), rim, col.lightened(0.08)][pass_i]
			var ww: float = [w, w + 3.0, w][pass_i]
			f.draw_line(pts[i] + off, pts[i + 1] + off, c, ww, true)
			f.draw_circle(pts[i + 1] + off, ww * 0.5, c, true, -1.0, true)
	# The mitten: a round palm and a thumb, lit on top.
	f.draw_circle(hand + Vector2(2, 3), 9.5, Color(0, 0, 0, 0.3), true, -1.0, true)
	f.draw_circle(hand, 9.5, rim, true, -1.0, true)
	f.draw_circle(hand, 8.0, col.lightened(0.08), true, -1.0, true)
	f.draw_circle(hand + up * 7.0 - dir * 2.0, 4.0, rim, true, -1.0, true)
	f.draw_circle(hand + up * 7.0 - dir * 2.0, 3.0, col.lightened(0.08), true, -1.0, true)
	f.draw_arc(hand, 6.0, up.angle() - 0.8, up.angle() + 0.4, 8, Color(1, 1, 1, 0.35), 1.6, true)
	if arm == Arm.SHOVE:
		# Speed lines behind the shove.
		for k in 3:
			var o := up * (k - 1) * 7.0
			f.draw_line(hand - dir * 18.0 + o, hand - dir * 34.0 + o, Color(Pal.INK, 0.35), 1.4, true)


## The bead: a thread from the body, a coloured bead with a tiny glyph.
func _draw_charm(f: Ink) -> void:
	if charm == Charm.NONE or phase != Phase.HANGING:
		return
	var a := 1.0 - 0.7 * hidden_amt
	var p := charm_pos()
	var top := pos + (p - pos).normalized() * (radius - 2.0)
	var col: Color = CHARM_COL[charm]
	f.draw_line(top, p, Color(Pal.STRING, 0.9 * a), 1.2, true)
	if charm_flash > 0.0:
		f.draw_circle(p, 7.0 + 8.0 * charm_flash, Color(col, 0.25 * charm_flash * a), true, -1.0, true)
	f.draw_circle(p + Vector2(1.2, 1.2), 7.0, Color(0, 0, 0, 0.35 * a), true, -1.0, true)
	f.draw_circle(p, 7.0, Color(col, a), true, -1.0, true)
	f.draw_circle(p + Vector2(-2.2, -2.2), 2.0, Color(1, 1, 1, 0.55 * a), true, -1.0, true)
	var g := Color(Pal.BG, 0.8 * a)
	match charm:
		Charm.BUBBLE:
			f.draw_arc(p, 3.6, 0.0, TAU, 14, g, 1.2, true)
		Charm.SPRING:
			f.draw_polyline(PackedVector2Array([p + Vector2(-3, 3), p + Vector2(-1, -1), p + Vector2(1, 3), p + Vector2(3, -1)]), g, 1.3, true)
		Charm.GHOST:
			f.draw_arc(p + Vector2(0, 0.5), 3.0, PI, TAU, 8, g, 1.3, true)
			f.draw_line(p + Vector2(-3, 0.5), p + Vector2(-3, 3.5), g, 1.3, true)
			f.draw_line(p + Vector2(3, 0.5), p + Vector2(3, 3.5), g, 1.3, true)
		Charm.BALLOON:
			f.draw_circle(p + Vector2(0, -1), 2.6, g, true, -1.0, true)
			f.draw_line(p + Vector2(0, 1.5), p + Vector2(0.8, 4.0), g, 1.0, true)
		Charm.VINE:
			f.draw_arc(p + Vector2(0, -1), 3.2, PI * 0.1, PI * 0.9, 8, g, 1.3, true)


func _process(delta: float) -> void:
	if phase == Phase.OFF or delay > 0.0:
		return
	intro_t = maxf(0.0, intro_t - delta)
	_body.modulate = Color.WHITE.lerp(DARK_TINT, dark) if dark > 0.0 else Color.WHITE
	_ring_t += delta
	squash_t += delta
	_clock += delta
	_update_eye(delta)
	_jit = _tremble()
	_xf = body_xform()
	_fxf = _xf * jelly_stretch()
	_body.transform = _xf
	_face.transform = _fxf
	_body.queue_redraw()
	# The face follows the body every frame through its transform. Its
	# drawing (blinks, glances, moods) is refreshed every frame while it is
	# in the thick of it (aimed at, showing a warning or a move, struck,
	# falling), so a tell is never late; the rest of the crowd at a rate the
	# phone can afford (FACE_EVERY), staggered from one enemy to the next.
	_face_tick += 1
	var busy := flash_t > 0.0 or startle_t > 0.0 or phase != Phase.HANGING or aimed or incoming \
		or squint or tele_t > 0.0 or not is_nan(_queued_x)
	if busy or (_face_tick + _face_phase) % FACE_EVERY[Device.tier] == 0:
		_face.queue_redraw()


func _setup_canvas() -> void:
	if _lit == null:
		_lit = ShaderMaterial.new()
		_lit.shader = preload("res://shaders/lit.gdshader")
		# A drawn contour round every creature (v8.6): on the softer walls the
		# shapes stand clear by their outline, not by glare.
		_lit.set_shader_parameter("outline", OUTLINE_PX)
		_lit.set_shader_parameter("outline_dark", OUTLINE_DARK)
	_body = Node2D.new()
	_body.material = _lit
	add_child(_body)
	_body.draw.connect(_draw_body)
	_face = Node2D.new()
	add_child(_face)
	_face.draw.connect(_draw_face)


# ---------------------------------------------------------------- face

## Face layer, in body space: the jelly's bubbles and the shells' rivets,
## then eye and mouth. World-space extras (the frayed string, the first-
## sighting ring, the boss's health) are drawn through the inverse.
## The face layer is collected in `_ink` and submitted as a single draw
## call (see Ink).
func _draw_face() -> void:
	_ink.clear()
	_face_ink()
	_ink.flush(_face.get_canvas_item())


func _face_ink() -> void:
	if phase == Phase.OFF or delay > 0.0:
		return
	var f := _ink
	var inv := _fxf.affine_inverse()
	f.draw_set_transform_matrix(inv)
	if fray_t > 0.0 and _attached and rope_alpha > 0.0:
		# Frayed: a few loose fibres at the nearest point, blinking faster
		# as the fray is about to mend.
		var q := _pts[1]
		for i in range(1, 4):
			if _pts[i].distance_to(_fray_at) < q.distance_to(_fray_at):
				q = _pts[i]
		var blink := 0.6 + 0.4 * sin(_clock * lerpf(6.0, 18.0, 1.0 - fray_t / 4.0))
		for k in 3:
			var a := -0.9 + k * 0.9
			f.draw_line(q, q + Vector2.from_angle(a) * 6.0, Color(Pal.INK, 0.7 * blink * rope_alpha), 1.2, true)
			f.draw_line(q, q + Vector2.from_angle(PI - a) * 6.0, Color(Pal.INK, 0.7 * blink * rope_alpha), 1.2, true)
	if _gone:
		f.draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	if intro_t > 0.0:
		# First sighting: a slow dashed ring marks the new enemy.
		var k := minf(1.0, intro_t / 0.5)
		for i in 12:
			var a0 := _clock * 0.8 + i * TAU / 12.0
			f.draw_arc(pos, radius + 16.0, a0, a0 + 0.3, 6, Color(Pal.INK, 0.5 * k), 1.5, true)
	if patched and phase == Phase.HANGING:
		# Legen's bubble: a thin, shimmering skin around the body.
		var wob := 1.0 + 0.03 * sin(_clock * 7.0)
		f.draw_arc(pos, (radius + 8.0) * wob, 0.0, TAU, 40, Color(Pal.MEDIC_BADGE, 0.55), 2.0, true)
		f.draw_arc(pos, (radius + 8.0) * wob, -2.4, -1.5, 10, Color(Pal.EYE, 0.6), 2.4, true)
	if champion and phase == Phase.HANGING:
		# The champion's aura: a fine gold ring close to the body, a bright
		# glint travelling round it, and a soft warm glow behind.
		var hr := radius * depth_scale() + 7.0
		f.draw_arc(pos, hr + 3.0, 0.0, TAU, 48, Color(Pal.GOLD_LIGHT, 0.12), 6.0, true)
		f.draw_arc(pos, hr, 0.0, TAU, 48, Color(Pal.GOLD, 0.55), 1.4, true)
		var g0 := _clock * 1.6
		f.draw_arc(pos, hr, g0, g0 + 0.9, 12, Color(Pal.GOLD_LIGHT, 0.95), 2.2, true)
	_draw_charm(f)
	_draw_arm(f)
	_draw_stance(f)
	if kind == Kind.BOSS and phase == Phase.HANGING:
		# A fine brass ring with ticks, turning slowly against the plates:
		# the Spinneren's presence, drawn as a dial.
		var rr := radius + 22.0
		f.draw_arc(pos, rr, 0.0, TAU, 64, Color(Tok.PRIMARY, 0.22), 1.2, true)
		for i in 24:
			var d := Vector2.from_angle(-orbit * 0.35 + i * TAU / 24.0)
			var long := i % 6 == 0
			f.draw_line(pos + d * rr, pos + d * (rr + (5.0 if long else 2.5)), Color(Tok.PRIMARY, 0.5 if long else 0.28), 1.2, true)
		# Health: brass studs, dark once spent (not on show in the collection).
		var hp_max: int = 0 if posed else HP[kind]
		for i in hp_max:
			var x := (i - (hp_max - 1) * 0.5) * 11.0
			var p := pos + Vector2(x, radius + 40.0)
			f.disc(p + Vector2(0.8, 1.0), 3.4, Color(0, 0, 0, 0.4))
			f.disc(p, 3.2, Color(Tok.PRIMARY_LO, 0.9))
			if i < hp:
				f.disc(p - Vector2(0.4, 0.4), 2.4, Tok.PRIMARY_HI)
	f.draw_set_transform_matrix(Transform2D.IDENTITY)
	var col := color()
	_fc_col = col
	col.a *= 1.0 - 0.9 * hidden_amt
	_details(col)
	_eye()
	if (champion or is_leader) and phase == Phase.HANGING:
		_crown(col.a)
	elif hat != Hat.NONE and phase == Phase.HANGING and not posed:
		_hat(col)
	_gear(col)
	if nemesis > 0:
		_scar(col.a)
	if crying > 0.0 and phase == Phase.HANGING:
		_tears(col.a)
	if hurry and phase == Phase.HANGING:
		_sweat_fly(col.a)
	elif trait_kind == Trait.SLEEPY and fposmod(_clock * 0.1 + _hue_shift * 37.0, 1.0) < 0.3 and calm_for_fun():
		# A sleepy one dozes off now and then (three seconds in ten).
		_snooze(col.a)
	if seeing_stars() or phase == Phase.FALLING:
		_stars(col.a)


## What a Vakt wears, set at a jaunty angle on the upper left of the rim (the
## string keeps the top), turning and squashing with the body.
func _hat(col: Color) -> void:
	var f := _ink
	var a := col.a
	var ang := -PI * 0.5 - 0.55
	var u := Vector2.from_angle(ang)              # out of the rim
	var t := u.orthogonal()                       # along it
	var b := u * (radius - 1.5)
	var w := maxf(9.0, radius * 0.42)
	var sh := Color(0, 0, 0, 0.3 * a)
	match hat:
		Hat.BEANIE:
			# A knitted cap: a dome with a rolled band and a pompom.
			var cap := Color(col.darkened(0.28), a)
			var dome := PackedVector2Array()
			for i in 11:
				var q := PI * i / 10.0
				dome.append(b + t * cos(q) * w + u * sin(q) * w * 0.95)
			f.draw_colored_polygon(dome, cap)
			for k in 3:
				var q := PI * (0.3 + 0.2 * k)
				f.draw_line(b + t * cos(q) * w * 0.25, b + t * cos(q) * w * 0.82 + u * sin(q) * w * 0.8, Color(col.darkened(0.45), 0.7 * a), 1.0, true)
			f.draw_line(b - t * w * 1.04, b + t * w * 1.04, Color(col.lightened(0.3), a), 3.2, true)
			var pom := b + u * (w * 0.95 + 2.6)
			f.disc(pom + Vector2(0.8, 1.0), 3.4, sh)
			f.disc(pom, 3.4, Color(Pal.EYE, a))
			f.disc(pom - Vector2(1.0, 1.0), 1.3, Color(1, 1, 1, 0.8 * a))
		Hat.SPROUT:
			# A seedling: a curved stem and two leaves.
			var leaf := Color(Color("8FD6A0").lerp(col, 0.25), a)
			var tip := b + u * (w * 1.1) + t * 2.0
			f.draw_polyline(PackedVector2Array([b, b + u * w * 0.55 + t * 1.5, tip]), Color(leaf.darkened(0.3), a), 1.8, true)
			for sx: float in [-1.0, 1.0]:
				var dir := (u + t * sx * 1.1).normalized()
				var base := tip - u * 1.0
				var mid := base + dir * w * 0.5
				var side := dir.orthogonal() * w * 0.2
				f.draw_colored_polygon(PackedVector2Array([base, mid + side, base + dir * w * 0.95, mid - side]), leaf)
				f.draw_line(base, base + dir * w * 0.8, Color(leaf.darkened(0.25), a), 0.9, true)
		Hat.BOW:
			# A ribbon bow on the side of the head.
			var rib := Color(col.lightened(0.42), a)
			var edge := Color(col.darkened(0.35), a)
			var c := b + u * 2.0
			for sx: float in [-1.0, 1.0]:
				var loop := PackedVector2Array([c, c + t * sx * w * 0.95 + u * w * 0.55, c + t * sx * w * 1.05 - u * w * 0.35])
				f.draw_colored_polygon(loop, rib)
				f.draw_polyline(PackedVector2Array([loop[0], loop[1], loop[2], loop[0]]), edge, 1.0, true)
				f.draw_line(c, c + t * sx * w * 0.5 - u * w * 0.9, rib, 2.0, true)
			f.disc(c, 2.6, edge)
			f.disc(c, 1.8, rib)
		Hat.PROPELLER:
			# A beanie with a propeller on a stem: it turns with the breeze
			# and whirs when the wearer moves or falls.
			var cap := Color(col.darkened(0.22), a)
			var dome := PackedVector2Array()
			for i in 9:
				var q := PI * i / 8.0
				dome.append(b + t * cos(q) * w * 0.9 + u * sin(q) * w * 0.7)
			f.draw_colored_polygon(dome, cap)
			f.draw_line(b - t * w * 0.92, b + t * w * 0.92, Color(col.lightened(0.3), a), 2.2, true)
			var hub := b + u * (w * 0.7 + 6.0)
			f.draw_line(b + u * w * 0.6, hub, Color(Pal.INK_DIM, a), 1.8, true)
			var span := w * 1.35 * cos(_prop)
			if absf(span) > 0.6:
				f.draw_line(hub - t * span, hub + t * span, Color(Pal.METAL_DARK, 0.8 * a), 5.6, true)
				f.draw_line(hub - t * span, hub + t * span, Color(Pal.METAL_LIGHT.lerp(Pal.EYE, 0.45), a), 3.8, true)
			f.disc(hub, 2.2, Color(Pal.INK, a))


## Kit some kinds always wear: the Dykker's swimming goggles pushed up on its
## brow, the Skygge's shades perched on its head. Never over the eye: the
## eye shows when it is about to move.
func _gear(col: Color) -> void:
	var f := _ink
	var a := col.a
	if a <= 0.02:
		return
	if kind == Kind.DROP:
		var y := -radius * 1.05
		var lr := radius * 0.18
		var strap := Color(col.darkened(0.55), 0.9 * a)
		var hw := radius * 0.44
		f.draw_line(Vector2(-hw, y + 0.5), Vector2(hw, y + 0.5), strap, 2.0, true)
		for sx: float in [-1.0, 1.0]:
			var c := Vector2(sx * radius * 0.22, y)
			f.disc(c + Vector2(0.6, 0.9), lr + 1.5, Color(0, 0, 0, 0.3 * a))
			f.disc(c, lr + 1.4, Color(Pal.METAL_DARK.lerp(col, 0.3), a))
			f.disc(c, lr, Color(Pal.world("rim").lerp(Pal.EYE, 0.5), 0.9 * a))
			f.disc(c - Vector2(lr, lr) * 0.35, lr * 0.35, Color(1, 1, 1, 0.85 * a))
	elif kind == Kind.SHADE:
		# Two dark lenses on a fine bridge, tilted along the rim.
		var c := Vector2(-radius * 0.55, -radius * 0.8)
		var lw := radius * 0.2
		var frame := Color(Pal.PUPIL, 0.95 * a)
		# Squashed to an oval and tilted along the rim (the batch's own
		# transform: two plain discs, no polygons).
		f.draw_set_transform_matrix(Transform2D(-0.42, Vector2(1.0, 0.7), 0.0, c))
		for sx: float in [-1.0, 1.0]:
			f.disc(Vector2(sx * lw * 1.05, 0.0), lw, frame)
			f.draw_line(Vector2(sx * lw * 1.05 - lw * 0.5, -lw * 0.25), Vector2(sx * lw * 1.05 - lw * 0.05, -lw * 0.6), Color(1, 1, 1, 0.55 * a), 1.2, true)
		f.draw_line(Vector2(-lw * 0.2, -lw * 0.3), Vector2(lw * 0.2, -lw * 0.3), frame, 1.6, true)
		f.draw_set_transform_matrix(Transform2D.IDENTITY)


## Stars round its head: a hit it survived (for a moment), or out cold as it
## falls.
func _stars(a: float) -> void:
	var f := _ink
	var k := 1.0 if phase == Phase.FALLING else minf(1.0, dizzy_t / 0.25)
	var speed := 2.0 if Prefs.reduced_motion else 4.2
	var rx := maxf(radius * 0.75, 16.0)
	var ry := radius * 0.2
	var cy := -radius - 10.0
	var col := Pal.EYE.lerp(Pal.GOLD_LIGHT, 0.3)
	for i in 3:
		var q := _clock * speed + i * TAU / 3.0
		var front := 0.5 + 0.5 * sin(q)
		var p := Vector2(cos(q) * rx, cy + sin(q) * ry)
		var r := lerpf(4.0, 6.4, front)
		var al := lerpf(0.6, 1.0, front) * a * k
		# Six points (three strokes): a star, never a plus (that is the
		# Legen's cross).
		f.disc(p + Vector2(0.5, 0.8), r * 0.75, Color(Pal.PUPIL, 0.4 * al))
		for j in 3:
			var d := Vector2.from_angle(_clock * 2.5 + j * PI / 3.0) * r
			f.draw_line(p - d, p + d, Color(col, al), 2.0, true)
		f.disc(p, r * 0.36, Color(1, 1, 1, al))


## A sleepy one left alone dozes: small z's drift up from it. (In body
## space, so they lean with it; drawn only while nothing is aimed at it.)
func _snooze(a: float) -> void:
	var f := _ink
	var col := Color(Pal.EYE, 0.8 * a)
	for i in 2:
		var k := fposmod(_clock * 0.45 + i * 0.5, 1.0)
		var fade := sin(PI * k)
		if fade < 0.05:
			continue
		var s := lerpf(3.0, 5.5, k)
		var p := Vector2(radius * 0.55 + k * 12.0 + sin(k * 6.0) * 2.0, -radius * 0.7 - k * 22.0)
		var z := PackedVector2Array([p + Vector2(-s, -s), p + Vector2(s, -s), p + Vector2(-s, s), p + Vector2(s, s)])
		f.draw_polyline(z, Color(Pal.PUPIL, 0.4 * a * fade), 3.2, true)
		f.draw_polyline(z, Color(col, col.a * fade), 1.6, true)


## The last of a wave, sinking fast: sweat flies off it.
func _sweat_fly(a: float) -> void:
	var f := _ink
	var c := Color(Pal.DROP.lightened(0.45), 0.95 * a)
	var rim := Color(Pal.PUPIL, 0.45 * a)
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		var k := 0.4 if Prefs.reduced_motion else fposmod(_clock * 1.6 + i * 0.5, 1.0)
		var p := Vector2(sx * (radius * 0.7 + k * 16.0), -radius * 0.6 - k * 14.0 + k * k * 20.0)
		var fade := minf(1.0, sin(PI * k) * 1.6)
		f.disc(p, 4.4, Color(rim, rim.a * fade))
		f.disc(p, 3.4, Color(c, c.a * fade))
		f.draw_colored_polygon(PackedVector2Array([p + Vector2(-2.6, -1.2), p + Vector2(-sx * 1.2, -7.0), p + Vector2(2.6, -1.2)]), Color(c, c.a * fade))
		f.disc(p + Vector2(-1.0, -1.0), 1.0, Color(1, 1, 1, 0.8 * a * fade))


## A crown set on the top of the body, in its own space, so it turns and
## squashes with it and is sized to the body (a champion's a little grander).
func _crown(a: float) -> void:
	var w := radius * (0.95 if champion else 0.75)
	var h := w * 0.55
	var base := -radius * (0.92 if kind != Kind.ROD else 0.9) + 1.0
	if kind == Kind.ROD:
		base = -radius
	var pts := PackedVector2Array([
		Vector2(-w * 0.5, base), Vector2(-w * 0.55, base - h * 0.75), Vector2(-w * 0.26, base - h * 0.38),
		Vector2(0.0, base - h), Vector2(w * 0.26, base - h * 0.38), Vector2(w * 0.55, base - h * 0.75),
		Vector2(w * 0.5, base)])
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(1.2, 1.4))
	_ink.draw_colored_polygon(sh, Color(0, 0, 0, 0.35 * a))
	_ink.draw_colored_polygon(pts, Color(Pal.GOLD, a))
	# A band along the base and a highlight on the left points (lamp side).
	_ink.draw_line(Vector2(-w * 0.5, base - 1.2), Vector2(w * 0.5, base - 1.2), Color(Pal.GOLD_DARK, a), 2.4, true)
	_ink.draw_line(pts[1], pts[2], Color(Pal.GOLD_LIGHT, 0.8 * a), 1.2, true)
	_ink.draw_line(pts[2], pts[3], Color(Pal.GOLD_LIGHT, 0.6 * a), 1.2, true)
	for k in [1, 3, 5]:
		_ink.disc(pts[k] + Vector2(0, 1.5), 1.6, Color(Pal.GOLD_LIGHT, a))
	if champion:
		_ink.disc(Vector2(0, base - h * 0.35), 2.2, Color(Pal.CORAL.lerp(Pal.SHADE, 0.5), a))


## Cute and crying: tears roll from both sides of the eye, over the face.
func _tears(a: float) -> void:
	var er := _eye_r()
	var eo := Vector2(0.0, -er * 0.35)
	for sx: float in [-1.0, 1.0]:
		var k := fposmod(_clock * 1.3 + (0.5 if sx > 0.0 else 0.0), 1.0)
		var p := eo + Vector2(sx * er * 0.95, er * 0.2 + k * radius * 0.55)
		var c := Color(Pal.DROP.lightened(0.35), 0.9 * (1.0 - k * 0.7) * a)
		_ink.disc(p, 2.4, c)
		_ink.draw_colored_polygon(PackedVector2Array([p + Vector2(-2.0, -0.6), p + Vector2(0, -5.0), p + Vector2(2.0, -0.6)]), c)


## Nemesis: a stitched scar slashed across the eye (one more per level).
func _scar(a: float) -> void:
	var h := maxf(_hole(), radius * 0.45)
	for k in mini(nemesis, 2):
		var o := Vector2(k * h * 0.35, -k * h * 0.2)
		var p0 := Vector2(-h * 0.75, -h * 0.8) + o
		var p1 := Vector2(h * 0.55, h * 0.75) + o
		_ink.draw_line(p0 + Vector2(1, 1), p1 + Vector2(1, 1), Color(0, 0, 0, 0.35 * a), 3.0, true)
		_ink.draw_line(p0, p1, Color(Color("E9B7AE"), 0.95 * a), 2.2, true)
		var n := (p1 - p0).orthogonal().normalized() * 3.5
		for s in 3:
			var m := p0.lerp(p1, 0.25 + 0.25 * s)
			_ink.draw_line(m - n, m + n, Color(Pal.PUPIL, 0.8 * a), 1.2, true)


## Bubbles rising slowly through jelly; rivets on the heavy's ring (gone
## once it cracks), bolts on the sentry, a hub on the reel.
func _details(col: Color) -> void:
	var f := _ink
	if rush_t > 0.0 and phase == Phase.HANGING:
		# Sinking fast for the team: two arrows under it, running down.
		var k := minf(1.0, rush_t / 0.3) * col.a
		for i in 2:
			var y := radius + 9.0 + i * 8.5 + fposmod(_clock * 16.0, 8.5)
			var c := Color(Pal.CORAL.lerp(Pal.EYE, 0.25), 0.95 * k * (1.0 - i * 0.35))
			var chev := PackedVector2Array([Vector2(-7.0, y - 4.5), Vector2(0.0, y + 2.0), Vector2(7.0, y - 4.5)])
			f.draw_polyline(chev, Color(Pal.PUPIL, 0.45 * c.a), 4.4, true)
			f.draw_polyline(chev, c, 2.6, true)
	if mood == Mood.GRUMPY and anger > 0.35 and phase == Phase.HANGING:
		# Steam from the top: two wisps rising and fading, faster when angrier.
		for sx: float in [-1.0, 1.0]:
			var k := fposmod(_clock * lerpf(0.8, 1.8, anger) + (0.5 if sx > 0.0 else 0.0), 1.0)
			var p := Vector2(sx * radius * 0.55, -radius - 4.0 - k * 16.0)
			f.disc(p + Vector2(sin(k * 6.0) * 2.0 * sx, 0), 3.5 + k * 4.0, Color(Pal.INK.lightened(0.2), minf(1.0, (anger - 0.35) * 1.4) * 0.85 * (1.0 - k) * col.a))

	if kind == Kind.PIPP:
		# A tuft of down on top (its beak is its mouth: see _mouth).
		for i in 3:
			var x := (i - 1) * 4.0
			f.draw_line(Vector2(x, -radius + 1.0), Vector2(x * 1.8, -radius - 7.0 - (2.0 if i == 1 else 0.0)), Color(col.lightened(0.3), col.a), 2.0, true)
	elif kind == Kind.PAKKIS:
		# Its little sack of tricks, tied at the neck, on its side.
		var sc := Vector2(radius * 0.78, radius * 0.45)
		var sack := Color("C99A6A", col.a)
		f.draw_circle(sc + Vector2(1.5, 1.5), 9.5, Color(0, 0, 0, 0.3 * col.a), true, -1.0, true)
		f.draw_circle(sc, 9.5, sack, true, -1.0, true)
		f.draw_circle(sc + Vector2(-2.5, -2.5), 3.0, Color(Color("E6C39A"), 0.8 * col.a), true, -1.0, true)
		f.draw_line(sc + Vector2(-4, -9), sc + Vector2(4, -9), Color(Color("8A6340"), col.a), 3.0, true)
		if charm_flash > 0.0:
			for k in 3:
				var a := -PI * 0.5 + (k - 1) * 0.6
				f.draw_line(sc + Vector2.from_angle(a) * 12.0, sc + Vector2.from_angle(a) * (16.0 + 4.0 * charm_flash), Color(Pal.GOLD_LIGHT, charm_flash * col.a), 1.5, true)
	if morale > 0.35 and phase == Phase.HANGING and not panicked():
		# Nervous sweat: a drop that runs down the side and fades.
		var k := fposmod(_clock * 0.8 + _hue_shift * 20.0, 1.0)
		var a := (morale - 0.35) / 0.65 * sin(PI * k) * col.a
		var p := Vector2(radius * 0.55, -radius * 0.55 + k * radius * 0.6)
		f.disc(p, 2.6, Color(Pal.DROP.lightened(0.4), 0.8 * a))
		f.draw_colored_polygon(PackedVector2Array([p + Vector2(-2.2, -0.8), p + Vector2(0, -5.5), p + Vector2(2.2, -0.8)]), Color(Pal.DROP.lightened(0.4), 0.8 * a))
	if _admire_t > 0.0:
		# The Speilet catching its own reflection: a small star on the glint.
		var s := sin(PI * minf(1.0, _admire_t / 1.3)) * 4.5
		var sp := Vector2(-radius * 0.42, -radius * 0.42)
		f.draw_line(sp - Vector2(s, 0), sp + Vector2(s, 0), Color(1, 1, 1, 0.9 * col.a), 1.4, true)
		f.draw_line(sp - Vector2(0, s), sp + Vector2(0, s), Color(1, 1, 1, 0.9 * col.a), 1.4, true)
	if kind == Kind.MEDIC:
		# White enamel, a mint line round the inside, and the healer's
		# cross set into the top of the rim like an inlay.
		var h := _hole()
		var c := Vector2(0.0, -(h + radius) * 0.5)
		var arm := (radius - h) * 0.5 + 2.5
		var mint := Color(Pal.MEDIC_BADGE, col.a)
		f.draw_arc(Vector2.ZERO, h + 0.6, 0.0, TAU, 40, Color(Pal.MEDIC_BADGE, 0.8 * col.a), 1.6, true)
		for q: Vector2 in [Vector2(0.8, 1.0), Vector2.ZERO]:
			var cc := Color(0, 0, 0, 0.3 * col.a) if q != Vector2.ZERO else mint
			f.draw_line(c + q - Vector2(arm, 0), c + q + Vector2(arm, 0), cc, 3.6, true)
			f.draw_line(c + q - Vector2(0, arm), c + q + Vector2(0, arm), cc, 3.6, true)
	elif kind == Kind.MIRROR:
		# Two glints across the polished face.
		# They slide across the face as the viewer leans (and it turns).
		var g := Color(1, 1, 1, 0.35 * col.a)
		var sh := (view_dir.rotated(-body_rot) * radius * 0.35)
		f.draw_line(Vector2(-radius * 0.7, radius * 0.1) + sh, Vector2(-radius * 0.1, -radius * 0.7) + sh, g, 3.0, true)
		f.draw_line(Vector2(-radius * 0.35, radius * 0.45) + sh * 1.4, Vector2(radius * 0.2, -radius * 0.1) + sh * 1.4, Color(g, g.a * 0.6), 1.6, true)
	if kind == Kind.SNEAK:
		# Its hood: a dark cowl over the crown, and when caught out, a
		# little tune whistled to nobody in particular.
		var hood := Color(col.darkened(0.55), col.a)
		f.draw_arc(Vector2(0, radius * 0.08), radius * 0.86, PI * 1.02, PI * 1.98, 24, hood, radius * 0.42, true)
		f.draw_arc(Vector2(0, radius * 0.08), radius * 0.66, PI * 1.08, PI * 1.92, 20, Color(col.darkened(0.7), 0.6 * col.a), 1.4, true)
		if innocent > 0.5:
			var k := fposmod(_clock * 0.9, 1.0)
			var np := Vector2(radius * 0.7 + k * 10.0, -radius * 0.2 - k * 18.0)
			var na := (innocent - 0.5) * 2.0 * sin(PI * k) * col.a
			f.disc(np, 2.6, Color(Pal.EYE, 0.85 * na))
			f.draw_line(np + Vector2(2.4, 0), np + Vector2(2.4, -9), Color(Pal.EYE, 0.85 * na), 1.3, true)
			f.draw_line(np + Vector2(2.4, -9), np + Vector2(6.0, -7), Color(Pal.EYE, 0.85 * na), 1.3, true)
	if kind == Kind.SPLIT:
		# Where it will come apart: a stitched seam across the top and the
		# bottom of the rim.
		var h := _hole()
		for sy: float in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			for k in 5:
				var t := float(k) / 4.0
				pts.append(Vector2((1.6 if k % 2 == 0 else -1.6), sy * lerpf(h + 0.5, radius - 1.5, t)))
			f.draw_polyline(pts, Color(col.darkened(0.55), col.a), 1.6, true)
	if soft:
		var h := _hole()
		if h > 0.0:
			for i in 3:
				var ph := _clock * (7.0 + i * 2.5) + i * 17.0 + _hue_shift * 300.0
				var y := h * 0.7 - fposmod(ph, h * 1.4)
				var x := sin(_clock * 0.9 + i * 2.1) * h * 0.45
				var fade := 1.0 - absf(y) / (h * 0.75)
				if fade > 0.0:
					f.disc(Vector2(x, y), 1.4 + i * 0.5, Color(col.lightened(0.35), 0.3 * fade * col.a))
		return
	var rv := Color(col.lightened(0.45), col.a)
	var sh := Color(0, 0, 0, 0.4 * col.a)
	match kind:
		Kind.CAPTAIN:
			# A brass helmet: a dome over the crown with a lit rim and a
			# short crest, and brass pips at the shoulders. It flashes as an
			# order goes out.
			var brass := Color(Tok.PRIMARY.lerp(Tok.PRIMARY_HI, order_flash / 0.7), col.a)
			var hc := Vector2(0, -radius * 0.12)
			f.draw_arc(hc + Vector2(1.0, 1.5), radius * 0.86, PI * 1.08, PI * 1.92, 22, sh, radius * 0.3, true)
			f.draw_arc(hc, radius * 0.86, PI * 1.08, PI * 1.92, 22, brass, radius * 0.3, true)
			f.draw_arc(hc, radius * 0.72, PI * 1.1, PI * 1.9, 20, Color(Tok.PRIMARY_LO, col.a), 1.6, true)
			f.draw_arc(hc, radius * 0.98, PI * 1.25, PI * 1.55, 10, Color(Tok.PRIMARY_HI, 0.8 * col.a), 1.4, true)
			var top := hc + Vector2(0, -radius * 1.0)
			f.draw_colored_polygon(PackedVector2Array([top + Vector2(-3, 2), top + Vector2(0, -9), top + Vector2(3, 2)]), brass)
			for sx: float in [-1.0, 1.0]:
				var ep := Vector2(sx * radius * 0.82, radius * 0.18)
				f.disc(ep + Vector2(0.7, 0.9), 3.4, sh)
				f.disc(ep, 3.2, brass)
		Kind.HEAVY:
			if hp > 1:
				# Its armour: a riveted steel band round the ring (gone once
				# it cracks).
				var br := radius - 6.0
				f.draw_arc(Vector2(0.8, 1.2), br, 0.0, TAU, 48, sh, 6.0, true)
				f.draw_arc(Vector2.ZERO, br, 0.0, TAU, 48, Color(Pal.METAL_LIGHT, col.a), 5.0, true)
				f.draw_arc(Vector2.ZERO, br - 1.6, PI * 1.05, PI * 1.7, 16, Color(Pal.INK, 0.35 * col.a), 1.0, true)
				for i in 8:
					var p := Vector2.from_angle(i * TAU / 8.0 + 0.2) * br
					f.disc(p + Vector2(0.7, 0.7), 1.7, sh)
					f.disc(p, 1.5, Color(Pal.INK, 0.9 * col.a))
		Kind.SHIELD:
			for i in 4:
				var p := Vector2.from_angle(i * TAU / 4.0 + PI / 4.0) * (radius - 5.0)
				f.disc(p + Vector2(0.7, 0.7), 2.0, sh)
				f.disc(p, 1.8, rv)
		Kind.REEL:
			# A spool: line wound on the rim, three spokes to a hub, and a
			# little crank handle.
			var line := Color(Pal.INK.lerp(col, 0.3), 0.55 * col.a)
			for k in 4:
				f.draw_arc(Vector2.ZERO, radius - 2.0 - k * 1.5, PI * 0.15, PI * 0.85, 18, line, 0.9, true)
			var hole := _hole()
			for k in 3:
				var d := Vector2.from_angle(k * TAU / 3.0 + PI * 0.5)
				f.draw_line(d * 10.0, d * (hole + 1.0), Color(col.darkened(0.4), col.a), 2.4, true)
			var hp0 := Vector2.from_angle(-PI * 0.2) * (radius + 1.0)
			f.draw_line(hp0, hp0 + Vector2(6, -3), Color(Pal.METAL_LIGHT, col.a), 2.4, true)
			f.disc(hp0 + Vector2(6, -3), 2.6, Color(col.darkened(0.3), col.a))
		Kind.BOSS:
			# Cracks spread across the shell stage by stage.
			if boss_stage >= 1:
				var cc := Color(col.darkened(0.55), col.a)
				var cracks := [[Vector2(0.55, -0.7), Vector2(0.3, -0.35), Vector2(0.42, -0.1)], [Vector2(-0.8, 0.2), Vector2(-0.45, 0.28), Vector2(-0.3, 0.55)]]
				if boss_stage >= 2:
					cracks.append([Vector2(0.1, 0.85), Vector2(0.2, 0.5), Vector2(0.05, 0.3)])
					cracks.append([Vector2(-0.6, -0.6), Vector2(-0.35, -0.42), Vector2(-0.4, -0.15)])
				for c: Array in cracks:
					var pts := PackedVector2Array()
					for q: Vector2 in c:
						pts.append(q * radius)
					f.draw_polyline(pts, cc, 2.0, true)


## The mouth, at the origin (drawn in its own space, under the eyes). It
## carries the mood first: out cold, woozy, clenched, startled, taunting,
## raging, worried or smug, and at rest the character's own (see CAST). Some
## marks stay through every mood: the Tungvekt's fangs, the Vokter's
## moustache, the Pipp's beak, the Snelle's straw.
func _mouth(er: float) -> void:
	var f := _ink
	var style: String = CAST[kind][4]
	var w := er * 1.7 * _mouth_w
	var a := modulate.a * (1.0 - 0.8 * hidden_amt)
	var ink := _ink_col(0.95)
	var dark := Color(Pal.PUPIL, 0.95 * a)
	var tongue := Color(Color("E8798F"), a)
	var tooth := Color(Color("FBF8F1"), a)
	var pts := PackedVector2Array()
	if style == "beak":
		_beak(f, w, a)
		return
	if phase == Phase.FALLING:
		# Out cold: a slack wavy line, the tongue lolling out of one corner.
		for i in 7:
			var t := lerpf(-1.0, 1.0, i / 6.0)
			pts.append(Vector2(t * w * 0.42, sin(t * 5.0) * 1.4))
		f.draw_polyline(pts, ink, 2.0, true)
		f.disc(Vector2(w * 0.24, w * 0.18), w * 0.14, tongue)
	elif seeing_stars():
		# Woozy: a wobbling line.
		for i in 7:
			var t := lerpf(-1.0, 1.0, i / 6.0)
			pts.append(Vector2(t * w * 0.38, 1.0 + sin(t * 6.0 + _clock * 9.0) * 1.3))
		f.draw_polyline(pts, ink, 2.0, true)
	elif _closed_t > 0.0:
		# Clenched: teeth gritted behind a tight grimace.
		var r := Rect2(-w * 0.36, -w * 0.1, w * 0.72, w * 0.2)
		f.draw_rect(r.grow(1.2), ink)
		f.draw_rect(r, tooth)
		for k in 3:
			var x := lerpf(r.position.x, r.end.x, (k + 1) / 4.0)
			f.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), ink, 1.0, true)
	elif startle_t > 0.0 or panicked():
		# An "O" of fright.
		f.disc(Vector2(0, 1.0), w * 0.2 + 1.4, ink)
		f.disc(Vector2(0, 1.0), w * 0.2, dark)
		f.disc(Vector2(0, 1.0 + w * 0.09), w * 0.1, tongue)
	elif _taunt >= 0.0:
		# A wide-open laugh with the tongue out.
		var grin := PackedVector2Array()
		for i in 11:
			var q := PI * i / 10.0
			grin.append(Vector2(cos(q) * w * 0.46, -1.0 + sin(q) * w * 0.38))
		f.draw_colored_polygon(grin, dark)
		f.draw_polyline(grin, ink, 1.4, true)
		f.disc(Vector2(w * 0.1, w * 0.26), w * 0.2, tongue)
		f.draw_line(Vector2(-w * 0.46, -1.0), Vector2(w * 0.46, -1.0), ink, 2.0, true)
	elif enraged:
		# A snarl: the corners pulled down.
		for i in 7:
			var t := lerpf(-1.0, 1.0, i / 6.0)
			pts.append(Vector2(t * w * 0.42, 2.0 - (1.0 - t * t) * 3.4))
		f.draw_polyline(pts, ink, 2.6, true)
	elif squint or aimed or tele_t > 0.0 or hurry:
		# Worried: a wobbly downturned line (teeth chattering, for a Vakt).
		var shake := sin(_clock * 40.0) * 0.6 if style == "buck" else 0.0
		for i in 7:
			var t := lerpf(-1.0, 1.0, i / 6.0)
			pts.append(Vector2(t * w * 0.3, 1.6 - (1.0 - t * t) * 1.8 + (shake if i % 2 == 0 else -shake)))
		f.draw_polyline(pts, ink, 2.0, true)
	elif smug > 0.35 or (_wink_t > 0.0 and calm_for_fun()):
		# Smirk: flat on one side, curled up on the other.
		var sm := maxf(smug, 0.8)
		for i in 7:
			var t := i / 6.0
			pts.append(Vector2(lerpf(-w * 0.38, w * 0.46, t), 0.5 - pow(t, 3.0) * 3.4 * sm))
		f.draw_polyline(pts, ink, 2.3, true)
	else:
		_rest_mouth(f, style, w, ink, dark, tooth, tongue)
	# Marks that stay whatever the mood.
	match style:
		"fangs":
			if phase != Phase.FALLING and startle_t <= 0.0:
				for sx: float in [-1.0, 1.0]:
					var b := Vector2(sx * w * 0.3, 1.5)
					f.draw_colored_polygon(PackedVector2Array([b + Vector2(-2.2, 0.8), b + Vector2(0.0, -4.6), b + Vector2(2.2, 0.8)]), tooth)
					f.draw_polyline(PackedVector2Array([b + Vector2(-2.2, 0.8), b + Vector2(0.0, -4.6), b + Vector2(2.2, 0.8)]), ink, 1.0, true)
		"stache":
			_moustache(f, w, ink, a)
		"whistle":
			if phase != Phase.FALLING and startle_t <= 0.0 and _taunt < 0.0:
				# A grass stalk in the corner of its mouth, bobbing as it chews.
				var b := Vector2(w * 0.32, 0.5)
				var tip := b + Vector2(w * 0.5, -w * 0.28 + sin(_clock * 2.2) * 1.5)
				f.draw_line(b, tip, Color(Color("C9B36A"), a), 1.8, true)
				f.draw_line(tip, tip + Vector2(2.5, -2.5), Color(Color("A8C46A"), a), 1.4, true)


## The character's mouth at rest (see CAST).
func _rest_mouth(f: Ink, style: String, w: float, ink: Color, dark: Color, tooth: Color, tongue: Color) -> void:
	var pts := PackedVector2Array()
	match style:
		"buck":
			# A gormless little smile and two big front teeth.
			for i in 7:
				var t := lerpf(-1.0, 1.0, i / 6.0)
				pts.append(Vector2(t * w * 0.34, (1.0 - t * t) * 2.2 * maxf(0.3, _smile)))
			f.draw_polyline(pts, ink, 1.9, true)
			var y0 := 2.2 * maxf(0.3, _smile) - 0.6
			for sx: float in [-1.0, 1.0]:
				var r := Rect2(Vector2(0.2 if sx > 0.0 else -w * 0.13 - 0.2, y0), Vector2(w * 0.13, w * 0.16))
				f.draw_rect(r.grow(1.0), ink)
				f.draw_rect(r, tooth)
		"stitch":
			# Sewn shut, crooked: a zigzag seam with cross stitches.
			for i in 7:
				var t := lerpf(-1.0, 1.0, i / 6.0)
				pts.append(Vector2(t * w * 0.4, (1.4 if i % 2 == 0 else -1.4) + t * 1.2))
			f.draw_polyline(pts, ink, 1.6, true)
			for k in 4:
				var x := lerpf(-w * 0.3, w * 0.3, k / 3.0)
				f.draw_line(Vector2(x, -2.8 + x * 0.03), Vector2(x, 2.8 + x * 0.03), ink, 1.1, true)
		"hum":
			# Humming: a small round mouth.
			f.disc(Vector2(0, 1.0), w * 0.12 + 1.2, ink)
			f.disc(Vector2(0, 1.0), w * 0.12, dark)
		"pucker":
			# Lips pursed, as if about to blow a bubble.
			f.disc(Vector2(w * 0.05, 1.0), w * 0.15 + 1.3, ink)
			f.disc(Vector2(w * 0.05, 1.0), w * 0.15, tongue.darkened(0.15))
			f.disc(Vector2(w * 0.05, 1.0), w * 0.06, dark)
		"stache":
			# Under the moustache, only a stern line.
			f.draw_line(Vector2(-w * 0.18, 2.4), Vector2(w * 0.18, 2.4), ink, 1.6, true)
		"jaws":
			# A wide grin full of saw teeth.
			var top := PackedVector2Array()
			for i in 11:
				var t := lerpf(-1.0, 1.0, i / 10.0)
				top.append(Vector2(t * w * 0.48, -1.5 + (1.0 - t * t) * 1.0))
			var bottom := PackedVector2Array()
			for i in 11:
				var t := lerpf(1.0, -1.0, i / 10.0)
				bottom.append(Vector2(t * w * 0.48, -1.5 + (1.0 - t * t) * 6.5))
			var poly := top.duplicate()
			poly.append_array(bottom)
			f.draw_colored_polygon(poly, dark)
			for i in 6:
				var x := lerpf(-w * 0.4, w * 0.4, i / 5.0)
				var y := -1.5 + (1.0 - pow(x / (w * 0.48), 2.0)) * 1.0
				f.draw_colored_polygon(PackedVector2Array([Vector2(x - 2.4, y), Vector2(x + 2.4, y), Vector2(x, y + 3.6)]), tooth)
			f.draw_polyline(poly, ink, 1.4, true)
		"whistle":
			# Laid back: a lopsided easy smile.
			for i in 8:
				var t := lerpf(-1.0, 1.0, i / 7.0)
				pts.append(Vector2(t * w * 0.32, (1.0 - t * t) * 1.6 - t * 1.0))
			f.draw_polyline(pts, ink, 1.9, true)
		"sly":
			for i in 7:
				var t := i / 6.0
				pts.append(Vector2(lerpf(-w * 0.3, w * 0.36, t), 0.5 - pow(t, 2.5) * 3.0))
			f.draw_polyline(pts, ink, 2.0, true)
		"kind":
			# A gentle, closed smile.
			for i in 7:
				var t := lerpf(-1.0, 1.0, i / 6.0)
				pts.append(Vector2(t * w * 0.3, (1.0 - t * t) * 2.6))
			f.draw_polyline(pts, ink, 1.8, true)
		"pout":
			# A pout: two little lobes of lip, rosy.
			var lip := Color(Color("E97FA0"), ink.a)
			f.disc(Vector2(-w * 0.07, 0.6), w * 0.1, lip)
			f.disc(Vector2(w * 0.07, 0.6), w * 0.1, lip)
			f.disc(Vector2(0.0, 2.2), w * 0.12, lip)
			f.draw_line(Vector2(-w * 0.15, 1.4), Vector2(w * 0.15, 1.4), Color(ink, ink.a * 0.7), 1.0, true)
		"gap":
			# A cheeky grin with a tooth missing.
			var grin := PackedVector2Array()
			for i in 11:
				var q := PI * i / 10.0
				grin.append(Vector2(cos(q) * w * 0.42, -0.5 + sin(q) * w * 0.26))
			f.draw_colored_polygon(grin, dark)
			var row := Rect2(-w * 0.36, -0.5, w * 0.72, w * 0.1)
			f.draw_rect(row, tooth)
			f.draw_rect(Rect2(w * 0.02, -0.5, w * 0.1, w * 0.1), dark)
			f.draw_polyline(grin, ink, 1.5, true)
			f.draw_line(Vector2(-w * 0.42, -0.5), Vector2(w * 0.42, -0.5), ink, 1.6, true)
		"bark":
			# Barking orders: the mouth open as an order goes out, otherwise
			# a stern straight line.
			if order_flash > 0.0:
				var o := Rect2(-w * 0.22, -w * 0.08, w * 0.44, w * 0.26 * minf(1.0, order_flash / 0.3) + 2.0)
				f.draw_rect(o.grow(1.3), ink)
				f.draw_rect(o, dark)
				f.draw_rect(Rect2(o.position, Vector2(o.size.x, 2.0)), tooth)
			else:
				f.draw_line(Vector2(-w * 0.26, 1.0), Vector2(w * 0.26, 0.6), ink, 2.2, true)
		"prim":
			# Pursed and pleased with itself.
			for i in 7:
				var t := lerpf(-1.0, 1.0, i / 6.0)
				pts.append(Vector2(t * w * 0.18, 1.0 - (1.0 - t * t) * 0.8))
			f.draw_polyline(pts, ink, 1.9, true)
			f.draw_line(Vector2(w * 0.18, 1.0), Vector2(w * 0.24, -0.4), ink, 1.6, true)
		"smirk":
			# Up to something: a crooked grin and one tooth showing.
			for i in 8:
				var t := i / 7.0
				pts.append(Vector2(lerpf(-w * 0.34, w * 0.38, t), 1.2 - pow(t, 2.0) * 3.2))
			f.draw_polyline(pts, ink, 2.1, true)
			f.draw_rect(Rect2(w * 0.08, -0.4, w * 0.1, w * 0.12), Color(Color("FBF8F1"), ink.a))
		_:
			for i in 7:
				var t := lerpf(-1.0, 1.0, i / 6.0)
				pts.append(Vector2(t * w * 0.34, (1.0 - t * t) * 2.6 * _smile))
			f.draw_polyline(pts, ink, 1.8, true)


## The Pipp's beak: closed, or open in fright and in a taunt.
func _beak(f: Ink, w: float, a: float) -> void:
	var open := 0.0
	if startle_t > 0.0 or panicked() or _taunt >= 0.0:
		open = 1.0
	elif phase == Phase.FALLING or _closed_t > 0.0:
		open = 0.0
	var bk := Color(Color("F2A65A"), a)
	var edge := Color(Color("B86A2A"), a)
	var bw := maxf(4.5, w * 0.24)
	var upper := PackedVector2Array([Vector2(-bw, -1.0), Vector2(bw, -1.0), Vector2(0.0, 4.0 - open * 1.5)])
	f.draw_colored_polygon(upper, bk)
	f.draw_polyline(PackedVector2Array([upper[0], upper[2], upper[1]]), edge, 1.0, true)
	if open > 0.0:
		var lower := PackedVector2Array([Vector2(-bw * 0.8, 3.5), Vector2(bw * 0.8, 3.5), Vector2(0.0, 8.0)])
		f.draw_colored_polygon(lower, bk.darkened(0.1))
		f.draw_polyline(PackedVector2Array([lower[0], lower[2], lower[1]]), edge, 1.0, true)


## The Vokter's walrus moustache: two full lobes drooping over the mouth.
func _moustache(f: Ink, w: float, ink: Color, a: float) -> void:
	var hair := Color(_fc_col.darkened(0.55), a)
	for sx: float in [-1.0, 1.0]:
		# Along the top from the middle out to the tip, then back along the
		# full, drooping underside.
		var lobe := PackedVector2Array()
		for i in 7:
			var t := i / 6.0
			lobe.append(Vector2(sx * lerpf(w * 0.03, w * 0.6, t), -2.2 + t * 2.4 - sin(PI * t) * 0.9))
		for i in range(5, 0, -1):
			var t := i / 6.0
			lobe.append(Vector2(sx * lerpf(w * 0.03, w * 0.6, t), 0.2 + t * 0.2 + sin(PI * t) * w * 0.24))
		f.draw_colored_polygon(lobe, hair)
		lobe.append(lobe[0])
		f.draw_polyline(lobe, ink, 1.0, true)


## A pair of eyes' brows, one over each: the mood's when one is showing,
## otherwise the character's own (see CAST).
func _brows(f: Ink, ec: Vector2, er: float, gap: float) -> void:
	var style: String = CAST[kind][3]
	if enraged or (mood == Mood.GRUMPY and startle_t <= 0.0):
		style = "angry"
	elif startle_t > 0.0 or panicked():
		style = "up"
	elif seeing_stars() or ((aimed or hurry or morale > 0.6) and smug < 0.3 and _taunt < 0.0):
		style = "worried"
	elif smug > 0.2:
		style = "raised"
	elif mood == Mood.CUTE:
		style = "soft"
	if style == "none":
		return
	var ink := _ink_col(0.9)
	var y0 := ec.y - er * 1.42
	if style == "mono":
		# One thick brow across both eyes, dipping in the middle.
		var pts := PackedVector2Array()
		for i in 5:
			var t := lerpf(-1.0, 1.0, i / 4.0)
			pts.append(Vector2(ec.x + t * (gap + er * 1.05), y0 + (1.0 - absf(t)) * er * 0.3 - absf(t) * er * 0.1))
		f.draw_polyline(pts, ink, 3.6, true)
		return
	# [inner end height, outer end height, arch, width]: heights in eye radii,
	# minus is up.
	var shape := {
		"worried": [-0.38, 0.12, 0.06, 2.1], "angry": [0.34, -0.22, 0.0, 2.9], "soft": [-0.12, -0.04, 0.22, 1.6],
		"arched": [-0.02, 0.06, 0.42, 1.9], "level": [0.0, 0.0, 0.0, 3.0], "lazy": [0.16, 0.3, 0.08, 2.2],
		"bushy": [-0.06, 0.02, 0.18, 3.6], "up": [-0.55, -0.42, 0.2, 2.0], "raised": [0.04, 0.04, 0.05, 2.0],
		"shifty": [0.2, -0.12, 0.05, 2.1],
	}
	var sp: Array = shape.get(style, shape["soft"])
	for sx: float in [-1.0, 1.0]:
		var inner: float = sp[0]
		var outer: float = sp[1]
		var arch: float = sp[2]
		if style == "raised" and sx > 0.0:
			inner = -0.48
			outer = -0.55
			arch = 0.25
		elif style == "shifty" and sx > 0.0:
			# Both brows lean the same way: a sidelong look.
			var tmp := inner
			inner = outer
			outer = tmp
		var cx := ec.x + sx * gap
		var pts := PackedVector2Array()
		for i in 4:
			var t := i / 3.0
			var x := cx + lerpf(-0.95, 1.0, t) * er * sx * -1.0
			var y := y0 + lerpf(inner, outer, 1.0 - t) * er - sin(PI * t) * er * arch
			pts.append(Vector2(x, y))
		f.draw_polyline(pts, ink, float(sp[3]), true)
		if style == "bushy":
			f.draw_polyline(pts, Color(ink, ink.a * 0.5), float(sp[3]) + 1.6, true)


## The character's own marks around the face (see CAST): the Legen's
## glasses, the Speilet's lashes and blush, the Tungvekt's stubble, a pair's
## cheeks when it is sweet.
func _signature(f: Ink, fc: Vector2, er: float) -> void:
	var cast: Array = CAST[kind]
	var a := modulate.a * (1.0 - 0.8 * hidden_amt)
	var ink := _ink_col(0.9)
	var pair := int(cast[0]) == 2
	var gap: float = er * float(cast[2])
	var ey := fc.y - er * 0.35
	if phase == Phase.FALLING:
		return
	match kind:
		Kind.MEDIC:
			# Round brass spectacles over both eyes.
			var rim := Color(Tok.PRIMARY, 0.95 * a)
			for sx: float in [-1.0, 1.0]:
				f.draw_arc(Vector2(fc.x + sx * gap, ey), er + 3.6, 0.0, TAU, 24, rim, 1.2, true)
			f.draw_line(Vector2(fc.x - gap + er + 3.4, ey - 1.5), Vector2(fc.x + gap - er - 3.4, ey - 1.5), rim, 1.2, true)
		Kind.MIRROR:
			# Long lashes and a blush: very pleased with itself.
			for sx: float in [-1.0, 1.0]:
				var c := Vector2(fc.x + sx * gap, ey)
				for k in 3:
					var q := -PI * 0.5 + sx * (0.35 + 0.3 * k)
					var d := Vector2.from_angle(q)
					f.draw_line(c + d * (er + 1.2), c + d * (er + 5.0) + Vector2(sx * 1.2, -0.6), ink, 1.4, true)
				f.disc(c + Vector2(sx * er * 0.9, er * 1.35), er * 0.38, Color(Color("F2A0B8"), 0.4 * a))
		Kind.HEAVY:
			# Stubble on the jaw.
			for k in 7:
				var x := fc.x + lerpf(-er * 1.4, er * 1.4, k / 6.0)
				var y := fc.y + er * 1.45 + sin(k * 1.7) * 1.2 + absf(x - fc.x) * 0.12
				f.disc(Vector2(x, y), 0.8, Color(ink, ink.a * 0.55))
		Kind.PIPP, Kind.PAKKIS:
			# Rosy cheeks.
			for sx: float in [-1.0, 1.0]:
				f.disc(Vector2(fc.x + sx * (gap + er * 0.7), ey + er * 1.15), er * 0.36, Color(Color("F29CB0"), 0.45 * a))
	if calm_for_fun() and not Prefs.reduced_motion:
		var mouth := fc + Vector2(0.0, er * 1.05)
		if kind == Kind.ROD:
			# Humming as it swings: a note drifts up now and then.
			var k := fposmod(_clock * 0.55 + _hue_shift * 21.0, 1.0)
			if k < 0.6:
				var q := k / 0.6
				var np := mouth + Vector2(er * 1.6 + q * 8.0 + sin(q * 7.0) * 2.0, -q * 22.0)
				var na := sin(PI * q) * a
				f.disc(np, 2.2, Color(ink, ink.a * na))
				f.draw_line(np + Vector2(1.9, 0.0), np + Vector2(1.9, -7.0), Color(ink, ink.a * na), 1.2, true)
				f.draw_line(np + Vector2(1.9, -7.0), np + Vector2(5.0, -5.5), Color(ink, ink.a * na), 1.2, true)
		elif kind == Kind.DROP:
			# Lips pursed: a bubble swells, lets go and floats up.
			var k := fposmod(_clock * 0.4 + _hue_shift * 13.0, 1.0)
			if k < 0.7:
				var q := k / 0.7
				var bp := mouth + Vector2(er * 0.25 + sin(q * 9.0) * 1.5, -q * 26.0 + 1.0)
				var br := lerpf(1.2, 3.4, minf(1.0, q * 3.0))
				var ba := (1.0 - q) * a
				f.draw_arc(bp, br, 0.0, TAU, 14, Color(Pal.EYE, 0.8 * ba), 1.1, true)
				f.disc(bp - Vector2(br, br) * 0.35, br * 0.25, Color(1, 1, 1, 0.7 * ba))
	if pair and mood == Mood.CUTE and kind != Kind.PIPP and kind != Kind.PAKKIS:
		for sx: float in [-1.0, 1.0]:
			f.disc(Vector2(fc.x + sx * (gap + er * 0.6), ey + er * 1.1), er * 0.34, Color(Pal.SHADE, 0.4 * a))


## The face: one eye or a pair, the brows, the mouth and the character's own
## marks (see CAST). Drawn in body space.
func _eye() -> void:
	var f := _ink
	var cast: Array = CAST[kind]
	var fc := _face_c()
	var er := _eye_r()
	if int(cast[0]) == 2:
		var gap: float = er * float(cast[2])
		var ey := fc.y - er * 0.35
		for sx: float in [-1.0, 1.0]:
			_eye_one(f, Vector2(fc.x + sx * gap, ey), er * _eye_mul(sx), sx)
		f.draw_set_transform_matrix(Transform2D.IDENTITY)
		_brows(f, Vector2(fc.x, ey), er, gap)
	else:
		_eye_one(f, fc + Vector2(0.0, -er * 0.35), er, 0.0)
	f.draw_set_transform_matrix(Transform2D(0.0, fc + Vector2(0.0, er * (1.05 if int(cast[0]) == 2 else 0.95))))
	_mouth(er)
	f.draw_set_transform_matrix(Transform2D.IDENTITY)
	_signature(f, fc, er)

## Eye radius for this kind, and this one's own eye size. A pair shares the
## face (see _face_r); a single eye takes more of it.
func _eye_r() -> float:
	var cast: Array = CAST[kind]
	var er: float
	if kind == Kind.BOSS:
		er = 13.0
	elif int(cast[0]) == 2:
		er = clampf(_face_r() * 0.37 * float(cast[1]), 5.2, 11.5)
	else:
		er = clampf(radius * 0.4, 9.5, 14.0)
	return er * _eye_scale


## Where the face sits (body space): the middle, but in the thick part of the
## Skygge's crescent, a little low in the Dykker's drop and the Luring's pear.
func _face_c() -> Vector2:
	match kind:
		Kind.SHADE:
			return Vector2(-radius * 0.6, 0.0)
		Kind.DROP:
			return Vector2(0.0, radius * 0.08)
		Kind.SNEAK:
			return Vector2(0.0, radius * 0.18)
	return Vector2.ZERO


## How much room the face has (a radius): a ring's face plate, most of a
## filled body.
func _face_r() -> float:
	var h := _hole()
	if h > 0.0:
		return h
	match kind:
		Kind.ROD:
			return radius * 1.05
		Kind.PIPP:
			return radius * 0.85
	return radius * 0.78


## The Splitter is of two minds: one eye bigger than the other.
func _eye_mul(sx: float) -> float:
	if kind == Kind.SPLIT:
		return 1.14 if sx < 0.0 else 0.84
	return 1.0

## The colour right around the eye, which the lids are made of: the face
## plate of a ring body, or the body itself for filled ones.
func _skin() -> Color:
	var c := _fc_col
	if _hole() > 0.0:
		return plate_color().darkened(0.1)
	return c.darkened(0.12)


## A ring body's face plate (its membrane): a light tint of its own colour,
## so the face reads on it in dark lines (v8.6; it used to be a dark recess).
func plate_color() -> Color:
	var c := _fc_col
	return Color(c.lerp(Color(1.0, 0.97, 0.92), 0.62), c.a)


## The ink a face is drawn in: a deep shade of its own colour.
func _ink_col(a := 1.0) -> Color:
	return Color(Pal.PUPIL.lerp(_fc_col, 0.22), a * modulate.a * (1.0 - 0.8 * hidden_amt))

## (The eyes' layout is in _eye.)
func _eye_parts() -> void:
	pass

## One eye at `eo` (body space) of radius `er`; `side` is -1/1 for one of a
## pair (the Spinneren's), 0 for a single eye.
func _eye_one(f: Ink, eo: Vector2, er: float, side: float) -> void:
	_eo = eo
	var bx := Transform2D(0.0, eo)
	f.draw_set_transform_matrix(bx)
	var wide := maxf(1.0, _open)
	var pr := er * 0.48 / wide * _pupil_scale
	er *= lerpf(1.0, wide, 0.5)
	var lash := Color(Pal.PUPIL, 0.9)
	var ink := _ink_col(0.95)
	if phase == Phase.FALLING:
		# Knocked out: a small cross for an eye.
		var xr := er * 0.62
		f.draw_line(Vector2(-xr, -xr), Vector2(xr, xr), ink, 2.4, true)
		f.draw_line(Vector2(-xr, xr), Vector2(xr, -xr), ink, 2.4, true)
		return
	# How far the lids are closed (0 open .. 1 shut).
	var upper := 1.0 - clampf(_open, 0.0, 1.0)
	upper = maxf(upper, smug * 0.5)
	if mood == Mood.GRUMPY and startle_t <= 0.0:
		# A glare: the lids never quite lift.
		upper = maxf(upper, 0.24 + 0.1 * anger)
	if trait_kind == Trait.SLEEPY and startle_t <= 0.0 and not panicked():
		upper = maxf(upper, 0.32)
	# Each kind's own look: the Tungvekt heavy-lidded and unimpressed, the
	# Skygge sly, the Spinneren's pair hooded and cold.
	if startle_t <= 0.0 and not panicked():
		match kind:
			Kind.HEAVY:
				upper = maxf(upper, 0.22)
			Kind.SHADE:
				upper = maxf(upper, 0.26)
			Kind.BOSS:
				upper = maxf(upper, 0.18)
	if kind == Kind.SEER and tired_t > 0.0:
		# Spent after a read: drowsy, lids heavy, no dodging.
		upper = maxf(upper, 0.8)
	var lower := 0.0
	if squint or tele_t > 0.0:
		lower = 0.22
	if _closed_t > 0.0 and not seeing_stars():
		upper = 1.0
	if ((_wink_t > 0.0 and side >= 0.0) or (_taunt >= 0.0 and _taunt < TAUNT_TIME * 0.7)) and calm_for_fun():
		# A wink, or the glee of a taunt: the eye shut in a happy upturned
		# curve. (Only when nothing is aimed at it: see calm_for_fun.)
		_lid_curve(f, er, 0.15, -1.0, ink, 2.3)
		if _wink_t > 0.0:
			var sp := Vector2(er * 1.05, -er * 0.9)
			var s := sin(PI * clampf(_wink_t / 0.5, 0.0, 1.0)) * 3.5
			f.draw_line(sp - Vector2(s, 0), sp + Vector2(s, 0), Color(Pal.GOLD_LIGHT, 0.95), 1.4, true)
			f.draw_line(sp - Vector2(0, s), sp + Vector2(0, s), Color(Pal.GOLD_LIGHT, 0.95), 1.4, true)
		return
	if upper + lower > 0.92:
		# Shut: a single soft curve, the lashes of a closed lid.
		_lid_curve(f, er, 0.08, 1.0, ink, 2.1)
		return
	# Fear dilates the pupil (panic, the last of a wave, a nervous team);
	# a sudden fright shrinks it to a pinpoint instead.
	if startle_t <= 0.0 and (panicked() or hurry or morale > 0.55):
		pr = minf(pr * 1.4, er * 0.72)
	f.disc(Vector2.ZERO, er + 1.5, ink)
	f.disc(Vector2.ZERO, er, Pal.EYE)
	var look := _pupil
	if trait_kind == Trait.SHY and not aimed and not incoming:
		# Shy: never quite meets your eye.
		look = Vector2(-look.x * 0.6, look.y * 0.4 + 0.35)
	if kind == Kind.SNEAK and innocent > 0.05:
		# Caught: it looks anywhere but at you (up and away, whistling).
		look = look.lerp(Vector2(0.62, -0.62), innocent)
	if kind == Kind.SPLIT and side > 0.0 and calm_for_fun() and not Prefs.reduced_motion:
		# Of two minds: its other eye wanders off on its own.
		look = Vector2(sin(_clock * 0.9), cos(_clock * 0.7)) * 0.7
	var pupil := look * (er - pr - 1.2)
	f.disc(pupil, pr, Pal.PUPIL)
	var glint_p := pupil - Vector2(pr, pr) * 0.35
	var gs := maxf(0.6, pr * 0.28)
	f.draw_rect(Rect2(glint_p - Vector2(gs, gs), Vector2(gs, gs) * 2.0), Color(Pal.EYE, 0.75))
	var skin := _skin()
	if upper > 0.02:
		_lid(f, er, upper, true, skin, lash)
	if lower > 0.02:
		_lid(f, er, lower, false, skin, lash)
	if mood == Mood.CUTE and side == 0.0:
		var cheek := minf(er * 1.3, radius * 0.6)
		var cr := minf(er * 0.3, radius * 0.18)
		for sx: float in [-1.0, 1.0]:
			f.disc(_in_hole(Vector2(sx * cheek, er * 0.95), cr + 1.0), cr, Color(Pal.SHADE, 0.35))
		f.disc(pupil + Vector2(pr * 0.4, pr * 0.35), pr * 0.16, Color(Pal.EYE, 0.8))
	if trait_kind == Trait.SHY and aimed and soft and side == 0.0:
		# A faint blush when it is looked at down the sights.
		for sx: float in [-1.0, 1.0]:
			f.disc(_in_hole(Vector2(sx * er * 1.25, er * 0.95), er * 0.32 + 1.0), er * 0.32, Color(Pal.SHADE, 0.28))
	if kind == Kind.SEER and side >= 0.0:
		# The monocle: a brass rim round the eye on a fine chain; it flashes
		# the instant the Seer reads your shot.
		var rim := Color(Tok.PRIMARY, 0.95)
		f.draw_arc(Vector2(0.8, 1.0), er + 3.0, 0.0, TAU, 28, Color(0, 0, 0, 0.35), 2.6, true)
		f.draw_arc(Vector2.ZERO, er + 3.0, 0.0, TAU, 28, rim, 2.2, true)
		f.draw_arc(Vector2.ZERO, er + 3.0, PI * 1.1, PI * 1.5, 8, Color(Tok.PRIMARY_HI, 0.9), 1.2, true)
		var c0 := Vector2.from_angle(PI * 0.3) * (er + 3.0)
		f.draw_polyline(PackedVector2Array([c0, c0 + Vector2(4, 6), c0 + Vector2(6, 14), c0 + Vector2(5, 20)]), Color(Tok.PRIMARY, 0.7), 1.2, true)
		if read_flash > 0.0:
			var k := read_flash / 0.45
			var gp := Vector2(-er * 0.5, -er * 0.5)
			f.draw_line(gp - Vector2(6, 0) * k, gp + Vector2(6, 0) * k, Color(1, 1, 1, 0.9 * k), 1.6, true)
			f.draw_line(gp - Vector2(0, 6) * k, gp + Vector2(0, 6) * k, Color(1, 1, 1, 0.9 * k), 1.6, true)
	if kind == Kind.DROP and upper < 0.5:
		# The Dråpe's lashes: three quick flicks over the eye.
		for k in 3:
			var a := -PI * 0.5 + (k - 1) * 0.42
			var d := Vector2.from_angle(a)
			f.draw_line(d * (er + 0.5), d * (er + 4.5) + Vector2((k - 1) * 0.8, 0), Color(Pal.PUPIL, 0.85), 1.6, true)
	if side != 0.0:
		return
	# Brows: fine arcs, set by mood (and by personality at rest).
	var bc := _ink_col(0.85)
	var worried := (aimed or panicked() or hurry or morale > 0.6) and not enraged and smug < 0.3 and _taunt < 0.0
	if enraged or mood == Mood.GRUMPY:
		# A frown: the brows dip toward the middle (lower still when angrier).
		var k := 0.85 if enraged else lerpf(1.02, 0.86, anger)
		_brow(f, er, -1.0, -k, -1.42, bc)
		_brow(f, er, 1.0, -k, -1.42, bc)
	elif worried:
		_brow(f, er, -1.0, -1.25, -1.55, bc)
		_brow(f, er, 1.0, -1.25, -1.55, bc)
	elif smug > 0.2:
		# One brow up, the other level: the look of someone unimpressed.
		_brow(f, er, -1.0, -1.35, -1.3, Color(bc, bc.a * smug))
		_brow(f, er, 1.0, -1.55 - 0.25 * smug, -1.4, Color(bc, bc.a * smug))
	elif trait_kind == Trait.PROUD:
		_brow(f, er, -1.0, -1.45, -1.5, Color(bc, 0.45))
		_brow(f, er, 1.0, -1.45, -1.5, Color(bc, 0.45))
	elif mood == Mood.CUTE:
		# Soft, raised brows: all innocence.
		_brow(f, er, -1.0, -1.6, -1.45, Color(bc, 0.4))
		_brow(f, er, 1.0, -1.6, -1.45, Color(bc, 0.4))
	elif kind == Kind.HEAVY or kind == Kind.BOSS:
		# A low, level brow: the heavyweights are never impressed.
		var inner := -1.12 if side == 0.0 else -1.02
		_brow(f, er, -1.0, inner, -1.22, Color(bc, 0.8))
		_brow(f, er, 1.0, inner, -1.22, Color(bc, 0.8))


## A lid over the round eye: filled in the skin colour from the top (or the
## bottom) down to a gently curved edge, with a fine lash line along it.
func _lid(f: Ink, er: float, amount: float, top: bool, skin: Color, lash: Color) -> void:
	var r := er + 0.9
	var edge := -er + 2.0 * er * amount if top else er - 2.0 * er * amount
	var hw := sqrt(maxf(0.0, r * r - edge * edge))
	if hw < 0.5:
		return
	# The edge sags toward the middle (top) or lifts (bottom): an almond.
	var sag := er * 0.22 * (1.0 - amount) * (1.0 if top else -1.0)
	var pts := PackedVector2Array()
	var a0 := atan2(edge, hw)
	var a1 := atan2(edge, -hw)
	# Around the outside of the eye, from one end of the edge to the other.
	var span := (a1 - a0) if top else (a1 - a0 - TAU)
	if top and span > 0.0:
		span -= TAU
	if not top and span < 0.0:
		span += TAU
	for i in 8:
		pts.append(Vector2.from_angle(a0 + span * i / 7.0) * r)
	var edge_pts := PackedVector2Array()
	for i in 6:
		var t := lerpf(-1.0, 1.0, i / 5.0)
		edge_pts.append(Vector2(t * hw, edge + sag * (1.0 - t * t)))
	# The edge's end points coincide with the arc's: leave them out, or the
	# polygon has duplicate corners and will not triangulate.
	pts.append_array(edge_pts.slice(1, edge_pts.size() - 1))
	f.draw_colored_polygon(pts, skin)
	f.draw_polyline(edge_pts, lash, 1.5 if top else 1.1, true)


## The line of a closed eye: a soft curve, bowed down.
func _lid_curve(f: Ink, er: float, y: float, bow: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var t := lerpf(-1.0, 1.0, i / 8.0)
		pts.append(Vector2(t * er * 0.85, y * er + er * 0.22 * bow * (1.0 - t * t)))
	f.draw_polyline(pts, col, w, true)


## One brow, as a fine arc above the eye; `inner_y` and `outer_y` are in
## eye radii (negative is up), `sx` the side. On a ring body the brow runs
## from the dark hole onto the ring; there it is drawn in line-art style, a
## pale stroke edged in dark, so it reads as a brow on either (a bare pale
## stroke on the ring reads as a scratch).
func _brow(f: Ink, er: float, sx: float, inner_y: float, outer_y: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var t := i / 5.0
		var x := lerpf(0.28, 1.12, t) * er * sx
		var y := lerpf(inner_y, outer_y, t) * er - sin(PI * t) * er * 0.12
		pts.append(Vector2(x, y))
	if _hole() > 0.0:
		f.draw_polyline(pts, Color(Pal.PUPIL, col.a * 0.7), 3.6, true)
		f.draw_polyline(pts, Color(col, minf(1.0, col.a * 1.25)), 1.5, true)
		return
	f.draw_polyline(pts, col, 1.7, true)


## A point of the face (eye space, see _eo) kept `pad` px inside a ring
## body's hole, so what is drawn on the dark recess never spills onto the
## ring itself.
func _in_hole(p: Vector2, pad: float) -> Vector2:
	var h := _hole()
	if h <= 0.0:
		return p
	var q := _eo + p
	var lim := maxf(1.0, h - pad)
	var l := q.length()
	return p if l <= lim or l < 0.001 else q * (lim / l) - _eo
