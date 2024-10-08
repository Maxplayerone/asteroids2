package game

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

_ :: fmt

Game_Memory :: struct {
	player:        Player,
	enemy_spawner: EnemySpawner,
}

g_mem: ^Game_Memory

Width :: 1280
Height :: 720

get_triangle_from_pos_and_radius :: proc(
	pos: rl.Vector2,
	radius: f32,
) -> (
	rl.Vector2,
	rl.Vector2,
	rl.Vector2,
) {

	top_vertex := rl.Vector2{pos.x, pos.y + radius}
	left_vertex := rl.Vector2{pos.x - 0.87 * radius, pos.y - 0.5 * radius}
	right_vertex := rl.Vector2{pos.x + 0.87 * radius, pos.y - 0.5 * radius}

	return top_vertex, left_vertex, right_vertex
}


//---------math related procedures-------------
rotate_point_around_point :: proc(v1, v2: rl.Vector2, angle: f32) -> rl.Vector2 {
	v1 := v1
	v1 -= v2
	v1 = {
		v1.x * math.cos(angle) - v1.y * math.sin(angle),
		v1.y * math.cos(angle) + v1.x * math.sin(angle),
	}
	v1 += v2
	return v1
}

angle_btw_vecs :: proc(v1, v2: rl.Vector2) -> f32 {
	return math.acos(
		v1.x * v2.x +
		v1.y * v2.y / math.sqrt(v1.x * v1.x + v1.y * v1.y) * math.sqrt(v2.x * v2.x + v2.y * v2.y),
	)
}

pos :: proc(rect: rl.Rectangle) -> rl.Vector2 {
	return rl.Vector2{rect.x, rect.y}
}

pos_center :: proc(rect: rl.Rectangle) -> rl.Vector2 {
	return rl.Vector2{rect.x + rect.width / 2, rect.y + rect.height / 2}
}

vec_dist :: proc(v1, v2: rl.Vector2) -> f32 {
	dx := v1.x - v2.x
	dy := v1.y - v2.y
	return math.sqrt(dx * dx + dy * dy)
}

to_deg :: proc(angle_rad: f32) -> f32 {
	return angle_rad * 180.0 / math.PI
}


//--------------rect related procedures-------------
rect_shrink :: proc(rect: rl.Rectangle, shrink_amount: f32 = 2.0) -> rl.Rectangle {
	return rl.Rectangle {
		rect.x + shrink_amount,
		rect.y + shrink_amount,
		rect.width - 2 * shrink_amount,
		rect.height - 2 * shrink_amount,
	}
}

rect_slice_per :: proc(rect: rl.Rectangle, slice_per: f32) -> rl.Rectangle {
	return rl.Rectangle{rect.x, rect.y, rect.width * slice_per, rect.height}
}

collission_mouse_rect :: proc(rect: rl.Rectangle) -> bool {
	pos := rl.GetMousePosition()
	if pos.x > rect.x &&
	   pos.x < rect.x + rect.width &&
	   pos.y > rect.y &&
	   pos.y < rect.y + rect.height {
		return true
	}
	return false
}

rect_without_outline :: proc(rect: rl.Rectangle, offset: f32 = 5.0) -> rl.Rectangle {
	return {rect.x + offset, rect.y + offset, rect.width - 2 * offset, rect.height - 2 * offset}
}

rect_with_outline :: proc(rect: rl.Rectangle, offset: f32 = 5.0) -> rl.Rectangle {
	return {rect.x - offset, rect.y - offset, rect.width + 2 * offset, rect.height + 2 * offset}
}

//-----------text related
fit_text_in_line :: proc(text: string, scale: int, width: f32, min_scale := 15) -> int {
	text_cstring := strings.clone_to_cstring(text, context.temp_allocator)
	if f32(rl.MeasureText(text_cstring, i32(min_scale))) > width {
		return 1000
	}
	scale := scale
	for scale > min_scale {
		if f32(rl.MeasureText(text_cstring, i32(scale))) < width {
			break
		}
		scale -= 1
	}
	return scale
}

fit_text_in_column :: proc(scale: int, height: f32, min_scale: f32 = 15) -> int {
	if f32(scale) < height {
		return scale
	} else if height >= min_scale {
		return int(height)
	} else {
		return 1000
	}
}

fit_text_in_rect :: proc(
	text: string,
	dims: rl.Vector2,
	wanted_scale: int,
	min_scale: f32 = 15,
) -> int {
	scale_x := fit_text_in_line(text, wanted_scale, dims.x, int(min_scale))
	scale_y := fit_text_in_column(wanted_scale, dims.y, min_scale)

	if scale_x < scale_y && scale_y != 1000 {
		return scale_x
	} else if scale_y < scale_x && scale_x != 1000 {
		return scale_y
	} else if scale_x == scale_y && scale_x != 1000 {
		return scale_x
	} else {
		return 0
	}
}

adjust_and_draw_text :: proc(
	text: string,
	rect: rl.Rectangle,
	padding: rl.Vector2 = {10.0, 10.0},
	wanted_scale: int = 100,
	color := rl.BLACK,
) {
	scale := fit_text_in_rect(
		text,
		{rect.width - 2 * padding.x, rect.height - 2 * padding.y},
		wanted_scale,
	)

	text_cstring := strings.clone_to_cstring(text, context.temp_allocator)
	text_width := f32(rl.MeasureText(text_cstring, i32(scale)))

	centering_padding := f32((rect.width - text_width) / 2)

	if scale != 0 {
		rl.DrawText(
			text_cstring,
			i32(rect.x + padding.x + centering_padding),
			i32(rect.y + padding.y),
			i32(scale),
			color,
		)
	}
}


//------------timer related
Timer :: struct {
	time:     f32,
	max_time: f32,
}

create_timer :: proc(max_time: f32) -> Timer {
	return Timer{time = 0.0, max_time = max_time}
}

update_timer :: proc(timer: ^Timer, dt: f32) -> bool {
	finished := false
	timer.time += dt
	if timer.time >= timer.max_time {
		finished = true
		timer.time = 0.0
	}
	return finished
}

update_timer_manual :: proc(timer: ^Timer, dt: f32) -> bool {
	timer.time += dt
	return timer.time >= timer.max_time
}

reset_timer_manual :: proc(timer: ^Timer) {
	timer.time = 0.0
}

draw_timer :: proc(timer: Timer, name: string = "") {
	fmt.println(name, ": ", timer.time, " | ", timer.max_time)
}

//-----------xp related
xp_to_lvl :: proc(xp: int) -> (int, int) {
	lvl: int
	xp_required := 100
	xp := xp
	for xp >= xp_required {
		lvl += 1
		xp -= xp_required
		xp_required *= 2
	}
	return xp, lvl
}

xp_for_next_lvl :: proc(xp: int) -> (int, int) {
	xp := xp
	xp_required := 100
	for xp >= xp_required {
		xp -= xp_required
		xp_required *= 2
	}
	return xp, xp_required
}

draw_xp_bar :: proc(xp: int) {
	xp_bar_outline := rl.Rectangle{500.0, Height - 75.0, 300.0, 50.0}
	xp_bar := rect_without_outline(xp_bar_outline, 3.0)
	rl.DrawRectangleRec(xp_bar_outline, rl.WHITE)

	xp_now, xp_required := xp_for_next_lvl(xp)
	xp_ratio := f32(xp_now) / f32(xp_required)
	rl.DrawRectangleRec(rect_slice_per(xp_bar, xp_ratio), rl.LIME)

	buf: [16]byte
	buf2: [16]byte
	xp_now_str := strconv.itoa(buf[:], xp_now)
	xp_required_str := strconv.itoa(buf2[:], xp_required)
	xp_progress_str := strings.join(
		{xp_now_str, xp_required_str},
		sep = "/",
		allocator = context.temp_allocator,
	)
	adjust_and_draw_text(xp_progress_str, xp_bar, color = rl.BLACK)
}


//-----------player related
Player :: struct {
	pos:     rl.Vector2,
	radius:  f32,
	color:   rl.Color,
	dir:     rl.Vector2,
	speed:   f32,
	bullets: [dynamic]Bullet,
	damage:  int,
	//xp based
	xp:      int,
}

draw_player_triangle :: proc(player: Player) {
	v1 := g_mem.player.dir
	v2 := rl.Vector2{0.0, 1.0}
	angle := angle_btw_vecs(v1, v2)

	if rl.GetMousePosition().x > player.pos.x {
		angle = -angle
	}

	v3, v4, v5 := get_triangle_from_pos_and_radius(player.pos, player.radius)
	v3 = rotate_point_around_point(v3, player.pos, angle)
	v4 = rotate_point_around_point(v4, player.pos, angle)
	v5 = rotate_point_around_point(v5, player.pos, angle)

	rl.DrawLineEx(v3, v4, 2.0, player.color)
	rl.DrawLineEx(v4, v5, 2.0, player.color)
	rl.DrawLineEx(v5, v3, 2.0, player.color)
}

update_player :: proc(player: ^Player, dt: f32) {
	if rl.IsKeyDown(.W) {
		player.pos.y -= player.speed * dt
	}
	if rl.IsKeyDown(.S) {
		player.pos.y += player.speed * dt
	}
	if rl.IsKeyDown(.A) {
		player.pos.x -= player.speed * dt
	}
	if rl.IsKeyDown(.D) {
		player.pos.x += player.speed * dt
	}

	if rl.IsMouseButtonPressed(.LEFT) {
		append(&player.bullets, create_bullet(player.pos, player.dir))
	}

	g_mem.player.dir = rl.Vector2Normalize(rl.GetMousePosition() - g_mem.player.pos)
}

Bullet :: struct {
	dir:    rl.Vector2,
	pos:    rl.Vector2,
	radius: f32,
	speed:  f32,
	color:  rl.Color,
}


create_bullet :: proc(pos, dir: rl.Vector2) -> Bullet {
	return Bullet {
		pos = pos,
		dir = dir,
		speed = 1000.0,
		color = rl.Color{255, 180, 115, 255},
		radius = 8.0,
	}
}

update_bullet :: proc(bullet: ^Bullet, dt: f32) -> bool {
	bullet.pos += bullet.dir * dt * bullet.speed

	if bullet.pos.x < 0.0 || bullet.pos.x > Width || bullet.pos.y < 0.0 || bullet.pos.y > Height {
		return true
	}
	return false
}

draw_bullet :: proc(bullet: Bullet) {
	rl.DrawCircleLinesV(bullet.pos, bullet.radius, bullet.color)
}

EnemySpawner :: struct {
	time_btw_spawns:        Timer,
	max_enemy_count:        int,
	enemies:                [dynamic]Enemy,
	//spawn particle stuff
	particle_spanwer_timer: Timer,
	spawn_particles_flag:   bool,
	spawn_particle:         ParticleInstance,
}

create_enemy_spawner :: proc() -> EnemySpawner {
	return EnemySpawner {
		enemies = make([dynamic]Enemy, context.allocator),
		time_btw_spawns = create_timer(1.0),
		particle_spanwer_timer = create_timer(1.0),
		max_enemy_count = 3,
	}
}

update_enemy_spawner :: proc(spawner: ^EnemySpawner, dt: f32) {
	if spawner.spawn_particles_flag {
		if ready_to_spawn := update_timer(&spawner.particle_spanwer_timer, dt); ready_to_spawn {
			append(&spawner.enemies, create_enemy_with_pos(spawner.spawn_particle.pos))
			spawner.spawn_particles_flag = false
		}
		update_particle_instance(&spawner.spawn_particle, dt)
		draw_particle_instance(spawner.spawn_particle)
		return
	}

	if ready_to_spawn := update_timer(&spawner.time_btw_spawns, dt);
	   ready_to_spawn && len(spawner.enemies) < spawner.max_enemy_count {
		spawner.spawn_particles_flag = true
		delete(spawner.spawn_particle.particles)
		spawner.spawn_particle = create_particle_instance(get_new_enemy_pos(spawner.enemies))
	}
}

EnemyState :: enum {
	Shooting,
	Walking,
}

Enemy :: struct {
	rect:            rl.Rectangle,
	color:           rl.Color,
	speed:           f32,
	min_dist:        f32,
	damaged:         bool,
	damaged_color:   rl.Color,
	damaged_timer:   Timer,
	health:          int,
	state:           EnemyState,
	time_btw_states: Timer,
	time_btw_shots:  Timer,
	bullets:         [dynamic]Bullet,
}

create_enemy :: proc(enemies: [dynamic]Enemy) -> Enemy {
	x := (rand.int31() % (Width - 150)) + 75
	y := (rand.int31() % (Height - 150)) + 75
	i := 0
	for i < len(enemies) {
		if rl.CheckCollisionRecs(enemies[i].rect, {f32(x), f32(y), 40.0, 40.0}) {
			x = (rand.int31() % (Width - 150)) + 75
			y = (rand.int31() % (Height - 150)) + 75
			i = 0
		}

		i += 1
	}

	return create_enemy_with_pos({f32(x), f32(y)})
}

create_enemy_with_pos :: proc(pos: rl.Vector2) -> Enemy {
	return Enemy {
		rect = {pos.x, pos.y, 40.0, 40.0},
		color = {247, 76, 252, 255},
		min_dist = 200.0,
		speed = 200.0,
		damaged = false,
		damaged_color = {255, 171, 247, 255},
		damaged_timer = create_timer(0.1),
		health = 100,
		state = .Walking,
		time_btw_states = create_timer(2.0),
		time_btw_shots = create_timer(0.5),
	}
}

get_new_enemy_pos :: proc(enemies: [dynamic]Enemy) -> rl.Vector2 {
	x := (rand.int31() % (Width - 150)) + 75
	y := (rand.int31() % (Height - 150)) + 75
	i := 0
	for i < len(enemies) {
		if rl.CheckCollisionRecs(enemies[i].rect, {f32(x), f32(y), 40.0, 40.0}) {
			x = (rand.int31() % (Width - 150)) + 75
			y = (rand.int31() % (Height - 150)) + 75
			i = 0
		}

		i += 1
	}

	return rl.Vector2{f32(x), f32(y)}
}


draw_healthbar :: proc(
	bar_rect: rl.Rectangle,
	max_hp, current_hp: int,
	healthbar_color := rl.RED,
) {
	inner_rect := rect_slice_per(rect_shrink(bar_rect, 3.0), f32(current_hp) / f32(max_hp))
	rl.DrawRectangleRec(bar_rect, rl.LIGHTGRAY)
	rl.DrawRectangleRec(inner_rect, healthbar_color)
}

get_healthbar_rect :: proc(
	pos: rl.Vector2,
	size := rl.Vector2{40.0, 20.0},
	offset_y: f32 = 30.0,
) -> rl.Rectangle {
	return rl.Rectangle{pos.x, pos.y - f32(offset_y), size.x, size.y}
}

update_enemy :: proc(
	e: ^Enemy,
	player_pos: rl.Vector2,
	cur_enemy_idx: int,
	enemies: [dynamic]Enemy,
	dt: f32,
) {

	if timer_ready := update_timer(&e.time_btw_states, dt); timer_ready {
		rand_state := rand.int31() % 2
		if rand_state == 0 {
			e.state = .Walking
		} else if rand_state == 1 {
			e.state = .Shooting
		}
	}

	switch e.state {
	case .Walking:
		dist := vec_dist(pos(e.rect), player_pos)
		if dist > e.min_dist {
			epos := pos(e.rect)
			dir := rl.Vector2Normalize(player_pos - epos)
			epos += dir * e.speed * dt

			update_pos := true
			for enemy, i in enemies {
				if rl.CheckCollisionRecs(
					   enemy.rect,
					   rl.Rectangle{epos.x, epos.y, e.rect.width, e.rect.height},
				   ) &&
				   i != cur_enemy_idx {
					update_pos = false
					break
				}
			}

			if update_pos {
				e.rect.x = epos.x
				e.rect.y = epos.y
			}
		}
	case .Shooting:
		if timer_ready := update_timer(&e.time_btw_shots, dt); timer_ready {
			dir := rl.Vector2Normalize(player_pos - pos_center(e.rect))
			append(&e.bullets, create_bullet(pos_center(e.rect), dir))
		}
	}


	if collission_mouse_rect(e.rect) {
		draw_healthbar(get_healthbar_rect(pos(e.rect)), 100, e.health)
	}

	if e.damaged {
		if finish_damaged_state := update_timer(&e.damaged_timer, dt); finish_damaged_state {
			e.damaged = false
		}
	}
}

damage_enemy :: proc(e: ^Enemy, damage: int) -> bool {
	e.damaged = true
	e.health -= damage
	return e.health <= 0.0
}

draw_enemy :: proc(enemy: Enemy) {
	if enemy.damaged {
		rl.DrawRectangleRec(enemy.rect, enemy.damaged_color)
		rl.DrawRectangleLinesEx(enemy.rect, 3.0, enemy.color)
	} else {
		rl.DrawRectangleLinesEx(enemy.rect, 3.0, enemy.color)
	}
}

ParticleInstance :: struct {
	pos:          rl.Vector2,
	max_particle: int,
	particles:    [dynamic]Particle,
}

Particle :: struct {
	pos:   rl.Vector2,
	dir:   rl.Vector2,
	size:  f32,
	color: rl.Color,
	speed: f32,
}

create_particle_instance :: proc(pos: rl.Vector2) -> ParticleInstance {
	particles := make([dynamic]Particle)
	color := rl.Color{254, 99, 189, 255}
	size := f32(5.0)
	speed := f32(50.0)
	for _ in 0 ..< 20 {
		angle := f32(rand.int31() % 6240) / 1000.0
		dir := rotate_point_around_point({0.0, -1.0}, {0.0, 0.0}, angle)
		append(
			&particles,
			Particle{pos = pos, dir = dir, size = size, color = color, speed = speed},
		)
	}

	return ParticleInstance{pos = pos, max_particle = 20, particles = particles}

}

update_particle_instance :: proc(inst: ^ParticleInstance, dt: f32) {
	for &p in inst.particles {
		p.pos += p.dir * p.speed * dt
		p.speed *= 0.999
	}
}

draw_particle_instance :: proc(inst: ParticleInstance) {
	for p in inst.particles {
		rl.DrawCircleV(p.pos, p.size, p.color)
	}
}

@(export)
game_init_window :: proc() {
	rl.InitWindow(1280, 720, "Odin + Raylib + Hot Reload template!")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
}

@(export)
game_init :: proc() {
	g_mem = new(Game_Memory)

	player := Player {
		pos    = {1280 / 2, 720 / 2},
		radius = 25,
		color  = rl.WHITE,
		speed  = 500.0,
		damage = 20,
	}

	g_mem^ = Game_Memory {
		player        = player,
		enemy_spawner = create_enemy_spawner(),
	}

	game_hot_reloaded(g_mem)
}

@(export)
game_update :: proc() -> bool {
	dt := rl.GetFrameTime()

	update_player(&g_mem.player, dt)
	for &bullet, i in g_mem.player.bullets {
		if delete_bullet := update_bullet(&bullet, dt); delete_bullet {
			unordered_remove(&g_mem.player.bullets, i)
		}
	}

	update_enemy_spawner(&g_mem.enemy_spawner, dt)

	for &enemy, i in g_mem.enemy_spawner.enemies {
		update_enemy(&enemy, g_mem.player.pos, i, g_mem.enemy_spawner.enemies, dt)


		for bullet, j in g_mem.player.bullets {
			if rl.CheckCollisionCircleRec(bullet.pos, bullet.radius, enemy.rect) {
				if damage_enemy(&enemy, g_mem.player.damage) {
					delete(enemy.bullets)
					unordered_remove(&g_mem.enemy_spawner.enemies, i)
				}
				unordered_remove(&g_mem.player.bullets, j)
			}
		}

		for &bullet, j in enemy.bullets {
			if delete_bullet := update_bullet(&bullet, dt); delete_bullet {
				unordered_remove(&enemy.bullets, j)
			}
		}
	}

	if rl.IsKeyPressed(.I) {
		clear(&g_mem.enemy_spawner.enemies)
	}

	if rl.IsKeyDown(.R) {
		g_mem.player.xp += 1
	}
	if rl.IsKeyDown(.E) {
		g_mem.player.xp -= 1
	}
	//fmt.println(g_mem.player.xp)

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	draw_player_triangle(g_mem.player)
	for bullet in g_mem.player.bullets {
		draw_bullet(bullet)
	}
	for enemy in g_mem.enemy_spawner.enemies {
		for bullet in enemy.bullets {
			draw_bullet(bullet)
		}
		draw_enemy(enemy)
	}

	rl.DrawLineEx(g_mem.player.pos, g_mem.player.pos + g_mem.player.dir * 50, 5, rl.ORANGE)

	draw_xp_bar(g_mem.player.xp)

	rl.EndDrawing()

	free_all(context.temp_allocator)

	return !rl.WindowShouldClose()
}

@(export)
game_shutdown :: proc() {
	delete(g_mem.player.bullets)
	for enemy in g_mem.enemy_spawner.enemies {
		delete(enemy.bullets)
	}
	delete(g_mem.enemy_spawner.enemies)
	delete(g_mem.enemy_spawner.spawn_particle.particles)
	free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g_mem = (^Game_Memory)(mem)
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.Z)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.Q)
}
