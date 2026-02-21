const std = @import("std");
const g_api = @import("game_api");
const slot = @import("slot.zig");
const SpriteDesc = g_api.SpriteDesc;

pub const ChipType = enum {
    BOMB,
    TORCH,
    DEFAULT,
};

pub const Chip = struct {
    col: u8,
    pos_y: f32,
    pos_x: f32,
    //state: enum {Falling, Settled},
};

pub fn ChipToDesc(atlas_id: u32) SpriteDesc {

    return SpriteDesc {
        .name = "Chip",
        .sprite_pos = .{ 0.0, 0.0 },
        .sprite_scale = .{ slot.TILE_SIZE_X, slot.TILE_SIZE_Y },
        .sprite_rotation = .{ 0.0, 0.0 },
        .tint = .{ 1.0, 1.0, 1.0, 1.0 },
        .atlas_id = atlas_id,
    };


}
