#+feature dynamic-literals
package main

import "core:fmt"
import "core:strings"
import ray "vendor:raylib"

entity :: struct {
	rect:     ray.Rectangle,
	velocity: ray.Vector2,
}

gravity: f32 : 10
windowWidth, windowHeight: i32 : 720, 720

main :: proc() {
	//
	//	window initialization
	//
	ray.InitWindow(windowWidth, windowHeight, "Ball Miner")
	ray.SetTargetFPS(60)
	defer ray.CloseWindow()

	//
	//	player initialization
	//
	player := entity{ray.Rectangle{360, 40, 30, 30}, ray.Vector2{}}
	player.rect.x = f32(windowWidth / 2)

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

	for !ray.WindowShouldClose() {
		//
		//	animation
		// 
		player_animation_timer += ray.GetFrameTime()

		if player_animation_timer >= 0.08333 {
			player_frame += 1
			player_animation_timer = 0
		}

		if player_frame > 3 {
			player_frame = 0
		}


		//
		// drawing
		//
		ray.BeginDrawing()
		ray.ClearBackground(ray.BLACK)
		ray.DrawTexturePro(
			player_textures[player_frame],
			ray.Rectangle{0, 0, 8, 8},
			player.rect,
			ray.Vector2{0, 0},
			0,
			ray.WHITE,
		)
		ray.EndDrawing()
	}
}

create_texture_array :: proc(image_filenames: [dynamic]cstring) -> [dynamic]ray.Texture2D {
	texture_array: [dynamic]ray.Texture2D

	for i in image_filenames {
		image := ray.LoadImage(i)

		if !ray.IsImageValid(image) {
			// tabs added to make it stand out better
			error_message := strings.concatenate(
				{"																image was not valid, not loading image: ", string(i)},
			)
			fmt.eprintln(error_message)
			continue
		}

		texture := ray.LoadTextureFromImage(image)
		append(&texture_array, texture)
	}

	return texture_array
}
