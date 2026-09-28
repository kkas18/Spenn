class_name Contacts
extends RefCounted
## The game's contact physics, run each 1/120 s step (see Game._step):
## hanging bodies against each other (a broad phase first, then soft
## contacts, billiard knocks and the chains they start), strings against
## the bodies they meet and against each other, falling bodies crushing
## what hangs below, balls against each other, and a ball against bodies,
## strings and plates.

var g: Game
var _hang: Array[Target] = []     # broad phase: the hanging bodies,
var _reach: Array[float] = []     # how far each one's shape reaches,
var _pushers: Array[Target] = []  # and the bodies that push strings aside


func _init(game: Game) -> void:
	g = game


## Soft contacts between hanging targets: overlap is pushed apart by
## inverse mass and the closing speed is exchanged with low restitution,
## so a struck target can nudge its neighbours.
func target_contacts() -> void:
	var sc := g.layout.scale
	Target.rope_clock += 1
	# Broad phase: the hanging bodies once, each with how far its shape can
	# reach from its centre, so far-apart pairs are dropped on two
	# subtractions before any closest-point work.
	_hang.clear()
	_reach.clear()
	for t in g.targets:
		if t.phase != Target.Phase.OFF:
			t.update_rope_box()
		if t.is_hittable():
			_hang.append(t)
			_reach.append(t.shape_radius() + (t.rod_half if t.kind == Target.Kind.ROD else 0.0))
	var n := _hang.size()
	for i in n:
		var a := _hang[i]
		var ra: float = _reach[i]
		for j in range(i + 1, n):
			var c := _hang[j]
			var rsum: float = ra + _reach[j]
			if absf(a.pos.x - c.pos.x) >= rsum or absf(a.pos.y - c.pos.y) >= rsum:
				continue
			# Shapes: circles, and a capsule for the Pendel (closest points on
			# its segment), so a rod is struck along its whole length.
			var pa := a.closest_point(c.pos)
			var pc := c.closest_point(pa)
			pa = a.closest_point(pc)
			var d := pc - pa
			var rr := a.shape_radius() + c.shape_radius()
			var dist := d.length()
			if dist >= rr or dist < 0.001:
				continue
			var nrm := d / dist
			var ia := 1.0 / a.mass()
			var ic := 1.0 / c.mass()
			# Push apart past a small slop, most of the way: stacked bodies
			# settle instead of jittering.
			var pen := maxf(0.0, rr - dist - 0.5) * 0.8
			var corr := nrm * pen / (ia + ic)
			a.pos -= corr * ia
			c.pos += corr * ic
			var contact := pa + nrm * a.shape_radius()
			# Jelly resting against a neighbour flattens where they touch, a
			# quiet patch that lasts as long as the contact (see Target.press);
			# only a real knock (below) sets it wobbling.
			var flat := (rr - dist) * 0.5 + 1.2
			a.press(contact, flat)
			c.press(contact, flat)
			var rel := a.vel - c.vel
			var closing := rel.dot(nrm)
			if closing <= 0.0:
				continue
			# Restitution by material: jelly on jelly barely bounces (it
			# squashes), shell on shell clacks apart, mixed in between.
			var e := 0.15 if (a.soft and c.soft) else (0.55 if not a.soft and not c.soft else 0.32)
			var j_imp := minf(closing * (1.0 + e) / (ia + ic), 520.0)
			# Friction along the contact: a glancing blow sets them spinning.
			var tan := rel - nrm * closing
			var f_imp := Vector2.ZERO
			if tan.length() > 1.0:
				f_imp = -tan.normalized() * minf(tan.length() / (ia + ic), j_imp * 0.35)
			a.push(-nrm * j_imp + f_imp, contact)
			c.push(nrm * j_imp - f_imp, contact)
			if closing > 70.0:
				a.dent(contact, closing * 0.8)
				c.dent(contact, closing * 0.8)
			a.bump(-nrm, closing)
			c.bump(nrm, closing)
			# Billiards: a target sent flying by a hit takes a neighbour with it.
			if closing > Game.KNOCK_SPEED * sc and (a.struck_t > 0.0 or c.struck_t > 0.0) and (g.state == Game.State.PLAYING or g.state == Game.State.STARTING):
				var striker := a if a.struck_t >= c.struck_t else c
				var victim := c if striker == a else a
				striker.struck_t = 0.0
				var dir := nrm if striker == a else -nrm
				g._chain_hit(victim, dir * j_imp * 0.5, contact, closing, striker.chain_depth + 1)
				continue
			if closing > 110.0 and g._knock_sfx_cd <= 0.0:
				g._knock_sfx_cd = 0.07
				var loud := linear_to_db(clampf(closing / 600.0, 0.15, 0.75))
				if a.soft and c.soft:
					Sfx.play("squish", randf_range(1.05, 1.25), loud - 4.0)
				elif not a.soft and not c.soft:
					Sfx.play("clank", randf_range(1.1, 1.3), loud - 3.0)
				else:
					Sfx.play("knock", randf_range(0.9, 1.1), loud)
				Sfx.haptic(6, 0.2)
	# Ropes slide around the bodies they meet instead of passing through,
	# and bodies keep inside the walls.
	# Only bodies inside a string's bounding box can touch it.
	_pushers.clear()
	for o in g.targets:
		if o.is_solid() or o.is_crushing(0.0):
			_pushers.append(o)
	for i in n:
		var t := _hang[i]
		t.keep_in(g.layout.size.x)
		var box := t.rope_box
		for o in _pushers:
			if o == t:
				continue
			var r := o.shape_radius() + (o.rod_half if o.kind == Target.Kind.ROD else 0.0) + 2.0
			if o.pos.x + r < box.position.x or o.pos.x - r > box.end.x or o.pos.y + r < box.position.y or o.pos.y - r > box.end.y:
				continue
			# Hanging bodies and falling ones alike push strings aside.
			t.rope_avoid(o)
		for j in range(i + 1, n):
			var o := _hang[j]
			if box.intersects(o.rope_box.grow(6.0)):
				t.rope_rope(o)


## A killed shell or a cut target falls; whatever still hangs in its way is
## knocked off its string (or loses a point of health) and falls in turn.
func falling_contacts() -> void:
	var min_speed := Game.CRUSH_SPEED * g.layout.scale
	for f in g.targets:
		if not f.is_crushing(min_speed):
			continue
		for t in g.targets:
			if t == f or not t.is_solid() or f.crushed.has(t.get_instance_id()):
				continue
			var cp := t.closest_point(f.pos)
			var rr := f.contact_radius() * 0.85 + (t.radius if t.kind != Target.Kind.ROD else t.radius * 0.6)
			if f.pos.distance_squared_to(cp) >= rr * rr:
				continue
			f.crushed.append(t.get_instance_id())
			var n := (cp - f.pos).normalized()
			var closing := (f.vel - t.vel).dot(n)
			if closing < min_speed * 0.6:
				continue
			# The faller gives up much of its speed and glances off.
			f.vel -= n * closing * 0.6
			f.spin *= -0.6
			g._chain_hit(t, n * closing * f.mass() * 0.9, cp - n * t.radius * 0.5, closing, f.chain_depth + 1)


## Balls in flight knock into each other (a triple fan, or a fresh shot
## meeting a bouncing one): equal masses, a lively bounce, friction spin.
func ball_contacts() -> void:
	for i in g.balls.size():
		var a := g.balls[i]
		if not a.active or a.hit_rail:
			continue
		for j in range(i + 1, g.balls.size()):
			var c := g.balls[j]
			if not c.active or c.hit_rail:
				continue
			var d := c.pos - a.pos
			var dist := d.length()
			if dist >= Ball.RADIUS * 2.0 or dist < 0.001:
				continue
			var n := d / dist
			var pen := Ball.RADIUS * 2.0 - dist
			a.pos -= n * pen * 0.5
			c.pos += n * pen * 0.5
			var vn := (a.vel - c.vel).dot(n)
			if vn <= 0.0:
				continue
			var jn := (1.0 + 0.85) * vn * 0.5
			a.vel -= n * jn
			c.vel += n * jn
			a.friction(-n, c.vel, jn, 0.15, 1.0)
			c.friction(n, a.vel, jn, 0.15, 1.0)
			a.impact(-n)
			c.impact(n)
			Sfx.play("clank", randf_range(1.5, 1.7), linear_to_db(clampf(vn / 1200.0, 0.1, 0.5)) - 6.0)


func collide(b: Ball) -> void:
	var cut_speed := Game.CUT_SPEED * g.layout.scale * (0.8 if g.perk("edge") > 0 else 1.0)
	var cut_r := 9.0 if g.perk("edge") > 0 else 5.0
	if b.hit_rail:
		# Spent against the rail: it drops out of play instead of raining
		# back down through the field.
		return
	for t in g.targets:
		if not t.is_hittable():
			continue
		# A fast ball severs the string it crosses; a slower one plucks it.
		# Cut: the ball's centre (±5 px) crosses the string near its hook on
		# the way up, fast, before touching the rail. A precision shot.
		if t.kind != Target.Kind.BOSS and not b.cut_any and not b.hit_rail and b.vel.y < 0.0 and b.vel.length() > cut_speed and t.rope_hit(b.pos, cut_r):
			b.cut_any = true
			if g.perk("edge") > 0 or t.strike_string(b.pos):
				g._on_cut(b, t)
			else:
				g.fx.sparks(b.pos, Pal.INK_DIM, 6)
				Sfx.play("twang", 1.2, -6.0)
				Sfx.haptic(8, 0.2)
			continue
		if t.charm != Target.Charm.NONE and b.pos.distance_to(t.charm_pos()) < Ball.RADIUS + 7.0:
			g._break_charm(t)
		var rdv := t.rope_contact(b.pos, b.pos - b.vel * Game.SUBSTEP, b.vel, Ball.RADIUS)
		if rdv != Vector2.ZERO:
			b.vel += rdv
			# The string rubs the ball: a touch of spin from the drag.
			b.w += clampf(rdv.cross(b.vel.normalized()) * 0.004, -6.0, 6.0)
			if t.consume_pluck():
				Sfx.haptic(5, 0.15)
		if not b.can_touch(t.get_instance_id()) or not t.is_solid():
			continue
		var cp := t.closest_point(b.pos)
		var d := b.pos - cp
		var rr := Ball.RADIUS + t.radius
		if t.kind == Target.Kind.SHIELD:
			rr += 5.0
		elif t.kind == Target.Kind.BOSS:
			rr += 11.0
		var dist := d.length()
		if dist >= rr:
			# Near miss: the target flinches and its eye pops wide.
			if dist < rr + 34.0 and b.vel.length() > 500.0:
				t.startle(b.pos)
				t.annoy(0.25)
			continue
		var n := d / dist if dist > 0.001 else -b.vel.normalized()
		if t.kind == Target.Kind.MIRROR and not b.special and b.banks == 0 and b.hits == 0:
			g._on_mirror(b, t, n, cp, rr)
		elif not b.special and t.blocks(n):
			g._on_block(b, t, n, cp, rr)
		else:
			g._on_hit(b, t, n, cp, rr)
		if not b.special:
			return
