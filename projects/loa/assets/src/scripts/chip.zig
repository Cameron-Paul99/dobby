const std = @import("std");
const g_api = @import("game_api");
const slot = @import("slot.zig");
const SpriteDesc = g_api.SpriteDesc;
const Transform2D = g_api.Transform2D;

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

pub fn ChipToDesc(
    id: u32,
    atlas_id: u32,
    api: anytype,
    ) SpriteDesc {

    const entity_transform = Transform2D{
        .pos_x = 0.0,
        .pos_y = 11700.0,
        .scale_x = slot.TILE_SIZE_X,
        .scale_y = slot.TILE_SIZE_Y,
    };

    api.set_transform_2D(id, entity_transform);

    return SpriteDesc {
        .name = "Chip",
        .tint = .{ 1.0, 1.0, 1.0, 1.0 },
        .atlas_id = atlas_id,
    };


}
