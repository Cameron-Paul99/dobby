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

pub const TILE_SIZE_X: f32 = 100.0;
pub const TILE_SIZE_Y: f32 = 100.0;

const BOARD_WORLD_W: f32 = @as(f32, WIDTH) * TILE_SIZE_X;
const BOARD_WORLD_H: f32 = @as(f32, HEIGHT) * TILE_SIZE_Y;

const HALF_BOARD_W: f32 = BOARD_WORLD_W * 0.5;
const HALF_BOARD_H: f32 = BOARD_WORLD_H * 0.5;

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
        .pos_x = world_x,
        .pos_y = world_y,
        .scale_x = TILE_SIZE_X,
        .scale_y = TILE_SIZE_Y,
    };
    
    api.add_transform_2D( id ,entity_transform);

    return SpriteDesc{
        .id = id,
        .name = "Slot",
        .tint = .{ 1.0, 1.0, 1.0, 1.0 },
        .atlas_id = atlas_id,
    };
}

