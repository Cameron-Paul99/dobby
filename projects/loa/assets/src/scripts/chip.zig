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

pub const ChipState = enum {
    Falling,
    Settled,
    default,
};

pub const Chip = struct {
    entity: u32 = 0,
    col: u6 = 0,
    pos_y: f32 = 0.0,
    pos_x: f32 = 0.0,
};

pub fn ChipToDesc(
    id: u32,
    atlas_id: u32,
    x: f32,
    y: f32,
    api: anytype,
    ) SpriteDesc {

    const entity_transform = Transform2D{
        .position = .{.x = x, .y = y},
        .scale = .{ .x = slot.TILE_SIZE_X, .y = slot.TILE_SIZE_Y },
    };

    api.add_transform_2D(id, entity_transform);

    return SpriteDesc {
        .id = id,
        .name = "Chip",
        .position = .{.x = 0, .y =0},
        .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 },
        .atlas_id = atlas_id,
    };


}
