#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:strconv"
import "core:strings"
import "core:terminal"
import ray "vendor:raylib"

block :: struct {
	rect: ray.Rectangle,
	type: int,
}

gravity: f32 : 0.1
drag: f32 : 0.1
windowWidth, windowHeight: i32 : 720, 720

score: i64 = 0
highscore: i64 = 0
player := ray.Rectangle{f32(windowWidth / 2), 40, 20, 20}
blocks: [dynamic]block = create_blocks(ray.Vector2{0, 120}, 30, 25, 24, 24)

went_in_portal: bool = false

player_velocity := ray.Vector2{0, 0}
player_terminal_velocity: f32 = 8

main :: proc() {
	ray.InitWindow(windowWidth, windowHeight, "Ball Miner")
	ray.SetTargetFPS(60)
	defer ray.CloseWindow()

	player_frame := 0
	player_animation_timer: f32 = 0
	player_textures := create_texture_array(
		[dynamic]cstring {
			"assets/player/player_0.png",
			"assets/player/player_1.png",
			"assets/player/player_2.png",
			"assets/player/player_3.png",
		},
	)

	block_textures := create_texture_array(
		[dynamic]cstring {
			"assets/blocks/blocks_0.png",
			"assets/blocks/blocks_1.png",
			"assets/blocks/blocks_2.png",
			"assets/blocks/blocks_3.png",
			"assets/blocks/blocks_4.png",
		},
	)

	font := ray.LoadFont("assets/PixelOperatorMono.ttf")

	smash_down_cooldown: f32 = 0

	for !ray.WindowShouldClose() {
		player_animation_timer += ray.GetFrameTime()
		smash_down_cooldown += ray.GetFrameTime()

		if player_animation_timer >= 0.08333 {
			player_frame += 1
			player_animation_timer = 0
		}

		if player_frame > 3 {
			player_frame = 0
		}

		if player_velocity.x > 0 do player_velocity.x -= drag
		if player_velocity.x < 0 do player_velocity.x += drag
		if abs(player_velocity.x) < drag do player_velocity.x = 0

		player_velocity.y += gravity
		if player_velocity.y < -3 do player_velocity.y = -3

		if ray.IsKeyDown(ray.KeyboardKey.D) || ray.IsKeyDown(ray.KeyboardKey.RIGHT) do player_velocity.x += 0.2
		if ray.IsKeyDown(ray.KeyboardKey.A) || ray.IsKeyDown(ray.KeyboardKey.LEFT) do player_velocity.x -= 0.2
		if ray.IsKeyReleased(ray.KeyboardKey.R) do reset_game()

		if player.x >= 690 || player.x <= 0 do player_velocity.x *= -0.9
		if player.x >= 690 do player.x = 689
		if player.x <= 0 do player.x = 1
		if player.y >= 690 do reset_game()

		if player_velocity.x > player_terminal_velocity do player_velocity.x = player_terminal_velocity
		if player_velocity.x < -player_terminal_velocity do player_velocity.x = -player_terminal_velocity

		if player_velocity.y > player_terminal_velocity do player_velocity.y = player_terminal_velocity
		if player_velocity.y < -player_terminal_velocity do player_velocity.y = -player_terminal_velocity

		player.x += player_velocity.x
		player.y += player_velocity.y

		player.x = math.round_f32(player.x)
		player.y = math.round_f32(player.y)

		for i := 0; i < len(blocks); i += 1 {
			if ray.CheckCollisionRecs(blocks[i].rect, player) {
				player_velocity.y -= 1.5 * (player_velocity.y < 0 ? -0.5 : 1.5)
				player_velocity.x -= 1.5 * (player_velocity.x < 0 ? -1 : 1)
				blocks[i].rect.x = -100
				blocks[i].rect.y = -100

				switch blocks[i].type {
				case 0:
					score += 1
				case 1:
					score += 3
				case 2:
					score += 8
				case 3:
					score += 15
				case 4:
					went_in_portal = true
					reset_game()
				}
			}
		}

		ray.BeginDrawing()
		ray.ClearBackground(ray.BLACK)
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

		buf: [19]byte
		score_text := strings.clone_to_cstring(strconv.write_int(buf[:], score, 10))
		highscore_text := strings.clone_to_cstring(strconv.write_int(buf[:], highscore, 10))

		score_text_measurement := ray.MeasureTextEx(font, cstring(score_text), 40, 0)

		ray.DrawTextPro(
			font,
			cstring(score_text),
			ray.Vector2{f32(windowWidth / 2), 25},
			ray.Vector2{score_text_measurement.x / 2, 0},
			0,
			40,
			0,
			ray.RAYWHITE,
		)


		ray.DrawTextPro(
			font,
			cstring(highscore_text),
			ray.Vector2{25, 25},
			ray.Vector2{0, 0},
			0,
			30,
			0,
			ray.YELLOW,
		)


		ray.EndDrawing()
	}
}

reset_game :: proc() {
	player.x = f32(windowWidth / 2)
	player.y = 40
	player_velocity = ray.Vector2{0, 0}
	clear(&blocks)
	blocks = create_blocks(ray.Vector2{0, 120}, 30, 25, 24, 24)

	if !went_in_portal {
		if score > highscore do highscore = score
		score = 0
	}

	went_in_portal = false
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
