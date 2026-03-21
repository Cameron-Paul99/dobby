const std = @import("std");
const g_api = @import("game_api");
const g_sprite = g_api.SpriteAPI;
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
        .position = .{.x = 0, .y = 0},
        .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 },
        .atlas_id = atlas_id,
    };
}

pub fn span_col_up(
    slots: *std.ArrayList(Slot), 
    allocator: std.mem.Allocator,
    row: u6,
    col: u7,
    length: u7) void {

    const end: u7 = col - length;
    for (end..col) |c|
    {
        slots.append(allocator, Slot{
            .x = row,
            .y = @intCast(c),
            .occupied = false,
        }) catch unreachable;
    }

}
//
pub fn span(
    slots: *std.ArrayList(Slot), 
    allocator: std.mem.Allocator,
    start_row: u6,
    start_col: u7,
    col_len: u7,
    row_len: u7) void {

    const end_col: u7 = start_col - col_len;
    const end_row = start_row + row_len;
    for (end_col..start_col) |c|
    {
        for (start_row..end_row) |r| {
            slots.append(allocator, Slot{
                .x = @intCast(r),
                .y = @intCast(c),
                .occupied = false,
            }) catch unreachable;
        }
    }
}

pub fn spawn_lock(id: u32, api: anytype) void {
    
    const desc = SpriteDesc {
        .id = id,
        .name = "Keyhole",
        .position = .{.x = 0.0, .y = -8.0},
        .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 },
        .atlas_id = 0,
    };
    api.*.spawn_sprite(&desc, id);
}
