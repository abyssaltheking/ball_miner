#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strconv"
import "core:strings"

import ray "vendor:raylib"

block :: struct {
	rect: ray.Rectangle,
	type: int,
}

gravity: f32 : 0.1
drag: f32 : 0.1
window_width, window_height: i32 : 720, 720

score: i64 = 0
highscore: i64 = 0
player := ray.Rectangle{f32(window_width / 2), 40, 20, 20}
blocks: [dynamic]block = create_blocks(ray.Vector2{0, 120}, 30, 25, 24, 24)

went_in_portal: bool = false
is_paused: bool = true
debug_mode: bool = false

player_velocity := ray.Vector2{0, 0}
player_terminal_velocity: f32 = 8

player_frame := 0
player_animation_timer: f32 = 0
player_textures, block_textures: [dynamic]ray.Texture2D

font: ray.Font

lose_sound, mine_sound, ore_sound, portal_sound: ray.Sound

sounds :: enum {
	lose,
	mine,
	ore,
	portal,
}

main :: proc() {
	initialization()
	defer shutdown()

	for !ray.WindowShouldClose() {
		animate()
		update()
		draw()
	}
}

initialization :: proc() {
	ray.InitWindow(window_width, window_height, "Ball Miner")
	ray.SetTargetFPS(60)
	ray.InitAudioDevice()

	player_frame = 0
	player_animation_timer = 0
	player_textures = create_texture_array(
		[dynamic]cstring {
			"assets/player/player_0.png",
			"assets/player/player_1.png",
			"assets/player/player_2.png",
			"assets/player/player_3.png",
		},
	)

	block_textures = create_texture_array(
		[dynamic]cstring {
			"assets/blocks/blocks_0.png",
			"assets/blocks/blocks_1.png",
			"assets/blocks/blocks_2.png",
			"assets/blocks/blocks_3.png",
			"assets/blocks/blocks_4.png",
		},
	)

	font = ray.GetFontDefault()

	lose_sound = ray.LoadSound("assets/audio/lose.wav")
	portal_sound = ray.LoadSound("assets/audio/portal.wav")
	ore_sound = ray.LoadSound("assets/audio/mineOre.wav")
	mine_sound = ray.LoadSound("assets/audio/mine.wav")
}

shutdown :: proc() {
	ray.CloseWindow()
	ray.CloseAudioDevice()
}

animate :: proc() {
	player_animation_timer += ray.GetFrameTime()

	if player_animation_timer >= 0.08333 {
		player_frame += 1
		player_animation_timer = 0
	}

	if player_frame > 3 {
		player_frame = 0
	}
}

update :: proc() {
	if ray.IsMouseButtonReleased(ray.MouseButton.LEFT) do is_paused = !is_paused
	if ray.IsKeyReleased(ray.KeyboardKey.F3) do debug_mode = !debug_mode

	if !is_paused {
		if player_velocity.x > 0 do player_velocity.x -= drag
		if player_velocity.x < 0 do player_velocity.x += drag
		if abs(player_velocity.x) < drag do player_velocity.x = 0

		player_velocity.y += gravity
		if player_velocity.y < -3 do player_velocity.y = -3

		if ray.IsKeyDown(ray.KeyboardKey.D) || ray.IsKeyDown(ray.KeyboardKey.RIGHT) do player_velocity.x += 0.2
		if ray.IsKeyDown(ray.KeyboardKey.A) || ray.IsKeyDown(ray.KeyboardKey.LEFT) do player_velocity.x -= 0.2

		if player.x >= 690 || player.x <= 0 do player_velocity.x *= -0.9
		if player.x >= 690 do player.x = 689
		if player.x <= 0 do player.x = 1
		if player.y >= 690 do reset_game()

		if player_velocity.x > player_terminal_velocity do player_velocity.x = player_terminal_velocity
		if player_velocity.x < -player_terminal_velocity do player_velocity.x = -player_terminal_velocity

		if player_velocity.y > player_terminal_velocity do player_velocity.y = player_terminal_velocity
		if player_velocity.y < -player_terminal_velocity do player_velocity.y = -player_terminal_velocity

		for i := 0; i < len(blocks); i += 1 {
			if ray.CheckCollisionRecs(blocks[i].rect, player) {
				player_velocity.y -= 1.5 * (player_velocity.y < 0 ? -0.5 : 1.5)
				player_velocity.x -= 1.5 * (player_velocity.x < 0 ? -1 : 1)
				blocks[i].rect.x = -100
				blocks[i].rect.y = -100

				switch blocks[i].type {
				case 0:
					score += 1
					play_sound(sounds.mine)
				case 1:
					score += 3
					play_sound(sounds.ore)
				case 2:
					score += 8
					play_sound(sounds.ore)
				case 3:
					score += 15
					play_sound(sounds.ore)
				case 4:
					went_in_portal = true
					play_sound(sounds.portal)
					reset_game()
				}
			}
		}

		player.x += player_velocity.x
		player.y += player_velocity.y

		player.x = math.round_f32(player.x)
		player.y = math.round_f32(player.y)
	}
}

draw :: proc() {
	ray.BeginDrawing()
	ray.ClearBackground(ray.BLACK)

	buf: [19]byte
	score_text := strings.clone_to_cstring(strconv.write_int(buf[:], score, 10))
	highscore_text := strings.clone_to_cstring(strconv.write_int(buf[:], highscore, 10))

	score_text_measurement := ray.MeasureTextEx(font, score_text, 40, 0)

	proper_highscore_text_measurement := ray.MeasureTextEx(
		font,
		strings.clone_to_cstring(
			strings.concatenate({"Highscore: ", strconv.write_int(buf[:], highscore, 10)}),
		),
		30,
		4,
	)
	start_text_measurement := ray.MeasureTextEx(font, "Click to start!", 50, 4)
	title_text_measurement := ray.MeasureTextEx(font, "BALL MINER", 70, 15)
	instructions_text_measurement := ray.MeasureTextEx(
		font,
		"A/D or left/right to move, tunnel towards the portal!",
		20,
		4,
	)

	if !is_paused {
		ray.DrawTexturePro(
			player_textures[player_frame],
			ray.Rectangle{0, 0, 6, 6},
			player,
			ray.Vector2{0, 0},
			0,
			ray.WHITE,
		)

		for i := 0; i < len(blocks); i += 1 {
			ray.DrawTexturePro(
				block_textures[blocks[i].type],
				ray.Rectangle{0, 0, 8, 8},
				blocks[i].rect,
				ray.Vector2{0, 0},
				0,
				ray.WHITE,
			)
		}

		ray.DrawTextPro(
			font,
			score_text,
			ray.Vector2{f32(window_width / 2), 25},
			ray.Vector2{score_text_measurement.x / 2, 0},
			0,
			40,
			4,
			ray.RAYWHITE,
		)

		ray.DrawTextPro(
			font,
			highscore_text,
			ray.Vector2{25, 25},
			ray.Vector2{0, 0},
			0,
			30,
			4,
			ray.YELLOW,
		)
	} else {
		ray.DrawTextPro(
			font,
			"Click to start!",
			ray.Vector2{360, 360},
			ray.Vector2{start_text_measurement.x / 2, start_text_measurement.y / 2},
			0,
			50,
			4,
			ray.RAYWHITE,
		)

		ray.DrawTextPro(
			font,
			"BALL MINER",
			ray.Vector2{360, 180},
			ray.Vector2{title_text_measurement.x / 2, title_text_measurement.y / 2},
			0,
			70,
			15,
			ray.SKYBLUE,
		)

		ray.DrawTextPro(
			font,
			strings.clone_to_cstring(
				strings.concatenate({"Highscore: ", strconv.write_int(buf[:], highscore, 10)}),
			),
			ray.Vector2{360, 520},
			ray.Vector2 {
				proper_highscore_text_measurement.x / 2,
				proper_highscore_text_measurement.y / 2,
			},
			0,
			30,
			4,
			ray.YELLOW,
		)

		ray.DrawTextPro(
			font,
			"A/D or left/right to move, tunnel towards the portal!",
			ray.Vector2{360, 660},
			ray.Vector2{instructions_text_measurement.x / 2, instructions_text_measurement.y / 2},
			0,
			20,
			4,
			ray.GRAY,
		)
	}

	if debug_mode {
		ray.DrawFPS(10, 10)
	}

	ray.EndDrawing()
}

reset_game :: proc() {
	player.x = f32(window_width / 2)
	player.y = 40
	player_velocity = ray.Vector2{0, 0}
	clear(&blocks)
	blocks = create_blocks(ray.Vector2{0, 120}, 30, 25, 24, 24)

	if !went_in_portal {
		play_sound(sounds.lose)
		if score > highscore do highscore = score
		score = 0
	}

	went_in_portal = false
}

play_sound :: proc(sound: sounds) {
	sound_to_play: ray.Sound

	switch sound {
	case sounds.lose:
		sound_to_play = lose_sound
	case sounds.mine:
		sound_to_play = mine_sound
	case sounds.ore:
		sound_to_play = ore_sound
	case sounds.portal:
		sound_to_play = portal_sound
	}

	pitch: f32 = rand.float32_range(0.6, 1.3)
	ray.SetSoundPitch(sound_to_play, pitch)
	ray.PlaySound(sound_to_play)
}

create_blocks :: proc(
	start_position: ray.Vector2,
	total_length: int,
	total_height: int,
	block_width: int,
	block_height: int,
) -> [dynamic]block {
	end_array: [dynamic]block
	posX := 0
	posY := 0
	used_portal := false

	for posX < total_length {
		for posY <= total_height {
			rng := rand.float32_range(0, (used_portal ? 49 : 50))
			rng = math.round(rng)
			type: int


			if rng < 33 {
				type = 0
			} else if rng < 40 {
				type = 1
			} else if rng < 48 {
				type = 2
			} else if rng < 50 {
				type = 3
			} else if rng == 50 && !used_portal && rand.float32_range(0, 1) > 0.75 {
				type = 4
				used_portal = true
			}

			if !used_portal && (posX == total_length - 2 && posY == total_height - 2) {
				type = 4
			}

			append(
				&end_array,
				block {
					ray.Rectangle {
						f32(posX * block_width) + start_position.x,
						f32(posY * block_height) + start_position.y,
						f32(block_width),
						f32(block_height),
					},
					type,
				},
			)
			posY += 1

			if posY == total_height && posX != total_length {
				posY = 0
				posX += 1
			}
		}
	}
	return end_array
}

create_texture_array :: proc(image_filenames: [dynamic]cstring) -> [dynamic]ray.Texture2D {
	texture_array: [dynamic]ray.Texture2D

	for i in image_filenames {
		image := ray.LoadImage(i)

		if !ray.IsImageValid(image) {
			error_message := strings.concatenate(
				{"image was not valid, not loading image: ", string(i)},
			)
			fmt.eprintln(error_message)
			continue
		}

		texture := ray.LoadTextureFromImage(image)
		append(&texture_array, texture)
	}

	return texture_array
}
