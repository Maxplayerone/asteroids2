package game

import "core:fmt"
import "core:math"
import "core:math/rand"
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

vec_dist :: proc(v1, v2: rl.Vector2) -> f32 {
	dx := v1.x - v2.x
	dy := v1.y - v2.y
	return math.sqrt(dx * dx + dy * dy)
}

Timer :: struct {
	time:     f32,
	max_time: f32,
	finished: bool,
}

create_timer :: proc(max_time: f32) -> Timer {
	return Timer{time = 0.0, max_time = max_time, finished = false}
}

update_timer :: proc(timer: ^Timer, dt: f32) -> bool {
	timer.time += dt
	if timer.time >= timer.max_time {
		timer.finished = true
	}
	return timer.finished
}

Player :: struct {
	pos:     rl.Vector2,
	radius:  f32,
	color:   rl.Color,
	dir:     rl.Vector2,
	speed:   f32,
	bullets: [dynamic]Bullet,
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
	time_btw_spawns: f32,
	timer:           f32,
	max_enemy_count: int,
	enemies:         [dynamic]Enemy,
}

create_enemy_spawner :: proc() -> EnemySpawner {
	return EnemySpawner {
		enemies = make([dynamic]Enemy, context.allocator),
		max_enemy_count = 10,
		time_btw_spawns = 1.0,
	}
}

update_enemy_spawner :: proc(spawner: ^EnemySpawner, dt: f32) {
	spawner.timer += dt
	if spawner.timer >= spawner.time_btw_spawns {
		if len(spawner.enemies) < spawner.max_enemy_count {
			append(&spawner.enemies, create_enemy(spawner.enemies))
		}
		spawner.timer = 0.0
	}
}

Enemy :: struct {
	rect:          rl.Rectangle,
	color:         rl.Color,
	speed:         f32,
	min_dist:      f32,
	damaged:       bool,
	damaged_color: rl.Color,
	damaged_timer: Timer,
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
	return Enemy {
		rect = {f32(x), f32(y), 40.0, 40.0},
		color = {247, 76, 252, 255},
		min_dist = 200.0,
		speed = 400.0,
		damaged = false,
		damaged_color = {255, 171, 247, 255},
		damaged_timer = create_timer(0.1),
	}
}

update_enemy :: proc(
	e: ^Enemy,
	player_pos: rl.Vector2,
	enemy_idx: int,
	enemies: [dynamic]Enemy,
	dt: f32,
) -> bool {
	enemy_dead: bool
	dist := vec_dist(pos(e.rect), player_pos)
	if dist > e.min_dist {
		epos := pos(e.rect)
		dir := rl.Vector2Normalize(player_pos - epos)
		epos += dir * e.speed * dt

		for enemy, i in enemies {
			if i != enemy_idx &&
			   rl.CheckCollisionRecs({epos.x, epos.y, e.rect.width, e.rect.height}, enemy.rect) {
				return enemy_dead
			}
		}

		e.rect.x = epos.x
		e.rect.y = epos.y
	}

	//damaged thingys
	if e.damaged {
		if finish_damaged_state := update_timer(&e.damaged_timer, dt); finish_damaged_state {
			e.damaged = false
			enemy_dead = true
		}
	}

	return enemy_dead
}

draw_enemy :: proc(enemy: Enemy) {
	if enemy.damaged {
		rl.DrawRectangleLinesEx(enemy.rect, 3.0, enemy.damaged_color)
	} else {
		rl.DrawRectangleLinesEx(enemy.rect, 3.0, enemy.color)
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
		for bullet in g_mem.player.bullets {
			if rl.CheckCollisionCircleRec(bullet.pos, bullet.radius, enemy.rect) {
				enemy.damaged = true
			}
		}

		if delete_enemy := update_enemy(
			&enemy,
			g_mem.player.pos,
			i,
			g_mem.enemy_spawner.enemies,
			dt,
		); delete_enemy {
			unordered_remove(&g_mem.enemy_spawner.enemies, i)
		}
	}

	if rl.IsKeyPressed(.I) {
		clear(&g_mem.enemy_spawner.enemies)
	}

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	draw_player_triangle(g_mem.player)
	for bullet in g_mem.player.bullets {
		draw_bullet(bullet)
	}
	for enemy in g_mem.enemy_spawner.enemies {
		draw_enemy(enemy)
	}

	rl.DrawLineEx(g_mem.player.pos, g_mem.player.pos + g_mem.player.dir * 50, 5, rl.ORANGE)

	rl.EndDrawing()
	return !rl.WindowShouldClose()
}

@(export)
game_shutdown :: proc() {
	delete(g_mem.player.bullets)
	delete(g_mem.enemy_spawner.enemies)
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
