const std = @import("std");
const g_api = @import("game_api");
const SpriteDesc = g_api.SpriteDesc;
const Transform2D = g_api.Transform2D;


pub const Slot = struct {
    id: u32 = 0,
    x: u6,
    y: u7,
    occupied: bool,
};
pub const WIDTH: u32 = 64;
pub const HEIGHT: u32 = 128;

pub const TILE_SIZE_X: f32 = 150.0;
pub const TILE_SIZE_Y: f32 = 150.0;

const BOARD_WORLD_W: f32 = @as(f32, WIDTH) * TILE_SIZE_X;
pub const BOARD_WORLD_H: f32 = @as(f32, HEIGHT) * TILE_SIZE_Y;

pub const HALF_BOARD_W: f32 = BOARD_WORLD_W * 0.5;
pub const HALF_BOARD_H: f32 = BOARD_WORLD_H * 0.5;

pub fn slotToSpriteDesc(
    slot: Slot, 
    id: u32 ,
    atlas_id: u32, 
    api: anytype) SpriteDesc {

    const world_x =
        @as(f32, @floatFromInt(slot.x)) * TILE_SIZE_X;

    const world_y =
        @as(f32, @floatFromInt(slot.y)) * TILE_SIZE_Y;

    // set transform
    const entity_transform = Transform2D{
        .position = .{.x = world_x, .y = world_y},
        .scale = .{ .x = TILE_SIZE_X, .y = TILE_SIZE_Y},
    };
    
    api.add_transform_2D( id ,entity_transform);

    return SpriteDesc{
        .id = id,
        .name = "Slot",
        .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 },
        .atlas_id = atlas_id,
    };
}


