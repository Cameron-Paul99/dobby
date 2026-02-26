const GameAPI = @import("game_api").GameAPI;
const GameMemory = @import("game_api").GameMemory;
const Physics = @import("game_api").PhysicsAPI;
const std = @import("std");
const slot_mod = @import("slot.zig");
const chip_mod = @import("chip.zig");
const Transform2D = @import("game_api").Transform2D;

pub var g_api: *GameAPI = undefined;
pub var g_memory: *GameMemory = undefined;
pub var g_physics: *Physics = undefined;

pub const HEIGHT = 128;
pub const Board = [HEIGHT]u64;

const GameState = struct {
    version: u32,
    board: [HEIGHT]u64,
};

var first_chip = chip_mod.Chip{};
pub var prev_pos = struct { x: f32 = 0, y: f32 = 0 }{};

pub export fn game_init(api: *GameAPI, game_memory: *GameMemory, physics: *Physics) callconv(.c) void {
    g_api = api;
    g_memory = game_memory;
    g_physics = physics;


    const allocator_fn = g_api.*.get_allocator();
    const allocator: *std.mem.Allocator = @ptrCast(@alignCast(allocator_fn));

    const board: Board = [_]u64{~@as(u64, 0)} ** HEIGHT;

    var slots = std.ArrayList(slot_mod.Slot).initCapacity(allocator.*, 0)
        catch unreachable;
    defer slots.deinit(allocator.*);

    for (120..HEIGHT) |y| {
        var row: u64 = board[y];

        while (row != 0) {
            const x: u6 = @intCast(@ctz(row));

            slots.append(allocator.*, slot_mod.Slot{
                .x = x,
                .y = @intCast(y),
                .occupied = false,
            }) catch unreachable;

            row &= row - 1; // clear lowest set bit
        }
    }

    const chip_id = g_api.*.add_entity();
    first_chip.entity = chip_id;
    const chip_desc = chip_mod.ChipToDesc(chip_id, 0, g_api);
    g_api.*.spawn_sprite(&chip_desc, chip_id);
    g_api.*.add_physics(chip_id);
    g_physics.*.enable_gravity(chip_id);

    for (slots.items) |slot| {
        const id = g_api.*.add_entity();
        const desc = slot_mod.slotToSpriteDesc(slot, id, 0, g_api);
        g_api.*.spawn_sprite(&desc, id);

    }



}
pub var has_stopped: bool = false;
pub export fn game_update(time_sec: f64) callconv(.c) void{
   std.log.info("Updated, {d}", .{time_sec});

}

pub export fn reload_game() callconv(.c) void {



}
