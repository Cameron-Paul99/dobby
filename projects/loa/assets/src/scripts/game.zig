const GameAPI = @import("game_api").GameAPI;
const GameMemory = @import("game_api").GameMemory;
const Physics = @import("game_api").PhysicsAPI;
const Input = @import("game_api").InputKeyExtern;
const Mouse = @import("game_api").MouseAPI;
const Camera = @import("game_api").Camera2DAPI;
const Sprite = @import("game_api").SpriteAPI;
const std = @import("std");
const slot_mod = @import("slot.zig");
const chip_mod = @import("chip.zig");
const Transform2D = @import("game_api").Transform2D;
const Position = @import("game_api").Position;

pub var g_api: *GameAPI = undefined;
pub var g_memory: *GameMemory = undefined;
pub var g_physics: *Physics = undefined;
pub var g_camera: *Camera = undefined;
pub var g_mouse: *Mouse = undefined;
pub var g_sprite: *Sprite = undefined;
var g_initialized: bool = false;
var g_allocator: ?*std.mem.Allocator = null;

pub const HEIGHT = 128;
pub const Board = [HEIGHT]u64;
pub const PLAY_MIN_ROW = 120;

const GameState = struct {
    version: u32,
    board: Board,
    chips_initialized: bool = false,
    chips: std.ArrayList(chip_mod.Chip),
};

fn getState() *GameState {
    return @ptrCast(@alignCast(g_memory.*.ptr));
}

fn bit(col: u6) u64 {
    return @as(u64, 1) << col;
}

fn isOccupied(state: *const GameState, col: u6, row: u32) bool {
    return (state.board[row] & bit(col)) != 0;
}

fn occupy(state: *GameState, col: u6, row: u32) void {
    state.board[row] |= bit(col);
}

fn colToWorldX(col: u8) f32 {
    return @as(f32, @floatFromInt(col)) * slot_mod.TILE_SIZE_X;
}

fn rowToWorldY(row: u32) f32 {
    return @as(f32, @floatFromInt(row)) * slot_mod.TILE_SIZE_Y;
}

fn worldYToRow(y: f32) u32 {
    return @intFromFloat(@floor(y / slot_mod.TILE_SIZE_Y));
}

pub var prev_pos = struct { x: f32 = 0, y: f32 = 0 }{};

pub export fn game_init(
    api: *GameAPI, 
    game_memory: *GameMemory, 
    physics: *Physics, 
    camera: *Camera, 
    mouse: *Mouse,
    spriteAPI: *Sprite) callconv(.c) void {

    g_api = api;
    g_memory = game_memory;
    g_physics = physics;
    g_camera = camera;
    g_mouse = mouse;
    g_sprite = spriteAPI;

    const allocator_fn = g_api.*.get_allocator();
    const allocator: *std.mem.Allocator = @ptrCast(@alignCast(allocator_fn));
    g_allocator = allocator;

    const state = getState();

    if (state.chips_initialized) {
        state.chips.deinit(allocator.*);
        state.chips_initialized = false;
    }

    state.version = 1;
    state.board = [_]u64{0} ** HEIGHT;
    state.chips = std.ArrayList(chip_mod.Chip).initCapacity(allocator.*, 0) catch unreachable;
    state.chips_initialized = true;

    g_initialized = true;

    var slots = std.ArrayList(slot_mod.Slot).initCapacity(allocator.*, 0)
        catch unreachable;
    defer slots.deinit(allocator.*);

    for (120..HEIGHT) |y| {
        var row: u64 = ~@as(u64, 0); 

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

    for (slots.items) |slot| {
        const id = g_api.*.add_entity();
        const desc = slot_mod.slotToSpriteDesc(slot, id, 0, g_api);
        g_sprite.*.spawn_sprite(&desc, id);

    }

}

pub export fn game_start() callconv(.c) void {
    g_camera.*.set_camera_world_pos(.{
        .x = slot_mod.HALF_BOARD_W,
        .y = (120.0 * slot_mod.TILE_SIZE_Y + slot_mod.BOARD_WORLD_H - 1365) * 0.5,
    }, 1.0);
}

pub export fn game_update(time_sec: f64) callconv(.c) void{
    _ = time_sec;
    const state = getState();

    
    var i: usize = 0;
    while (i < state.chips.items.len) {
        const chip = &state.chips.items[i];
        const pos = g_sprite.*.get_entity_sprites_world_pos(chip.entity);

        // Convert current y to board row
        var row = worldYToRow(pos.y);
        const locked_x = colToWorldX(chip.col);
        if (row < PLAY_MIN_ROW) {
            i += 1;
            continue;
        }

        if (row >= HEIGHT) {
            row = HEIGHT - 1;
        }

        if (shouldSettle(state, chip.col, row)) {
            const snap_y = rowToWorldY(row);

            g_sprite.*.set_entity_sprites_world_pos(chip.entity, .{
                .x = locked_x,
                .y = snap_y,
            });

            g_physics.*.remove_physics(chip.entity);
            occupy(state, chip.col, row);

            _ = state.chips.swapRemove(i);
            continue;
        }

        i += 1;
    }


}

pub export fn game_input_pressed(key: u8) callconv(.c) void {
    
    if (key == Input.w.value) {
        // w was pressed
    }
    if (key == Input.space.value) {
        // space was pressed
    }
    if (key == Input.mouse_left.value) {

        const state = getState();

        const mouse_loc = g_mouse.*.get_mouse_world_pos();
        const col_i = @as(i32, @intFromFloat(@floor(mouse_loc.x / slot_mod.TILE_SIZE_X)));

        if (col_i < 0) return;
        if (col_i >= @as(i32, @intCast(slot_mod.WIDTH))) return;

        const col: u6 = @intCast(col_i);

        // Optional: if top playable row is already occupied, reject spawn.
        //if (isOccupied(state, col, PLAY_MIN_ROW)) return;

        const chip_id = g_api.*.add_entity();

        const chip = chip_mod.Chip{
            .entity = chip_id,
            .col = col,
            .pos_x = colToWorldX(col),
            .pos_y = mouse_loc.y,
        };

        const chip_desc = chip_mod.ChipToDesc(chip_id, 0, chip.pos_x, chip.pos_y, g_api);
        g_sprite.*.spawn_sprite(&chip_desc, chip_id);
        g_physics.*.add_physics(chip_id);
        g_physics.*.enable_gravity(chip_id);

        const allocator_fn = g_api.*.get_allocator();
        const allocator: *std.mem.Allocator = @ptrCast(@alignCast(allocator_fn));
        state.chips.append(allocator.*, chip) catch unreachable;

    }

}
pub export fn game_deinit() callconv(.c) void {
    if (!g_initialized) return;

    const allocator = g_allocator orelse return;
    const state = getState();

    if (state.chips_initialized) {
        state.chips.deinit(allocator.*);
        state.chips_initialized = false;
    }

    state.version = 0;
    g_allocator = null;
    g_initialized = false;
}
pub export fn game_input_down(key: u8) callconv(.c) void {
    _ = key;


}
pub export fn game_input_up(key: u8) callconv(.c) void {
    _ = key;


}
pub export fn reload_game() callconv(.c) void {



}

fn shouldSettle(state: *const GameState, col: u6, row: u32) bool {
    // Bottom-most playable row
    if (row >= HEIGHT - 1) return true;

    // If next row below is occupied, settle on current row
    return isOccupied(state, col, row + 1);
}
