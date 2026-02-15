const std = @import("std");
const utils = @import("utils");
const c = @import("clibs.zig").c;
const helper = @import("helper.zig");
const two_bit = utils.two_bit;
const math = utils.math;

pub const InputBitSet = u64;

pub const RawInput = struct {
    buttons_down: InputBitSet = 0,
    buttons_pressed: InputBitSet = 0,
    mouse_pos: math.Vec2 = math.Vec2.ZERO,
    mouse_delta: math.Vec2 = math.Vec2.ZERO,
    scroll: f32 = 1.0,
};

pub const EditorIntent = struct {
    camera_move: math.Vec3 = math.Vec3.ZERO,
    camera_rotate: math.Vec2 = math.Vec2.ZERO,
    drag_delta: math.Vec2 = math.Vec2.ZERO,
    zoom_changed: bool = false,
    zoom: f32 = 10.0,
    drag_speed: f32 = 0,
    selection_mask: u64 = 0,
    mouse_pos: math.Vec2 = math.Vec2.ZERO,
};

pub const InputKey = enum(u8) {
    // Letters
    a, b, c, d, e, f, g,
    h, i, j, k, l, m, n,
    o, p, q, r, s, t, u,
    v, w, x, y, z,

    // Numbers
    num_0,
    num_1,
    num_2,
    num_3,
    num_4,
    num_5,
    num_6,
    num_7,
    num_8,
    num_9,

    // Modifiers and system keys
    space,
    enter,
    escape,
    tab,
    backspace,

    shift,
    ctrl,
    alt,
    delete,

    // Mouse buttons
    mouse_left,
    mouse_right,
    mouse_middle,
    mouse_x1,
    mouse_x2,

    // Xbox and Play Station
    pad_a,
    pad_b,
    pad_x,
    pad_y,

    pad_lb,
    pad_rb,

    pad_back,
    pad_start,

    pad_ls, // left stick click
    pad_rs, // right stick click
    
    // D Pad digital
    pad_up,
    pad_down,
    pad_left,
    pad_right,

};
    
    
    
pub fn MapSDLScancode(sc: c.SDL_Scancode) ?InputKey {
    const res: ?InputKey =  switch (sc) {
        // Letters (physical keys, layout-independent)
        c.SDL_SCANCODE_A => .a,
        c.SDL_SCANCODE_B => .b,
        c.SDL_SCANCODE_C => .c,
        c.SDL_SCANCODE_D => .d,
        c.SDL_SCANCODE_E => .e,
        c.SDL_SCANCODE_F => .f,
        c.SDL_SCANCODE_G => .g,
        c.SDL_SCANCODE_H => .h,
        c.SDL_SCANCODE_I => .i,
        c.SDL_SCANCODE_J => .j,
        c.SDL_SCANCODE_K => .k,
        c.SDL_SCANCODE_L => .l,
        c.SDL_SCANCODE_M => .m,
        c.SDL_SCANCODE_N => .n,
        c.SDL_SCANCODE_O => .o,
        c.SDL_SCANCODE_P => .p,
        c.SDL_SCANCODE_Q => .q,
        c.SDL_SCANCODE_R => .r,
        c.SDL_SCANCODE_S => .s,
        c.SDL_SCANCODE_T => .t,
        c.SDL_SCANCODE_U => .u,
        c.SDL_SCANCODE_V => .v,
        c.SDL_SCANCODE_W => .w,
        c.SDL_SCANCODE_X => .x,
        c.SDL_SCANCODE_Y => .y,
        c.SDL_SCANCODE_Z => .z,

        // Numbers (top row, not numpad)
        c.SDL_SCANCODE_0 => .num_0,
        c.SDL_SCANCODE_1 => .num_1,
        c.SDL_SCANCODE_2 => .num_2,
        c.SDL_SCANCODE_3 => .num_3,
        c.SDL_SCANCODE_4 => .num_4,
        c.SDL_SCANCODE_5 => .num_5,
        c.SDL_SCANCODE_6 => .num_6,
        c.SDL_SCANCODE_7 => .num_7,
        c.SDL_SCANCODE_8 => .num_8,
        c.SDL_SCANCODE_9 => .num_9,

        // Whitespace / control
        c.SDL_SCANCODE_SPACE      => .space,
        c.SDL_SCANCODE_RETURN    => .enter,
        c.SDL_SCANCODE_ESCAPE    => .escape,
        c.SDL_SCANCODE_TAB       => .tab,
        c.SDL_SCANCODE_BACKSPACE => .backspace,
        c.SDL_SCANCODE_DELETE => .delete,

        // Modifiers
        c.SDL_SCANCODE_LSHIFT, c.SDL_SCANCODE_RSHIFT => .shift,
        c.SDL_SCANCODE_LCTRL,  c.SDL_SCANCODE_RCTRL  => .ctrl,
        c.SDL_SCANCODE_LALT,   c.SDL_SCANCODE_RALT   => .alt,

        else => null,
    };

    if (res) |key| {
        std.log.info( "InputKey.{s}", .{@tagName(key) });
    }

    return res;
}


pub fn MapSDLMouseButton(button: u8) ?InputKey {
    const res: ?InputKey =  switch (button) {
        c.SDL_BUTTON_LEFT   => .mouse_left,
        c.SDL_BUTTON_RIGHT  => .mouse_right,
        c.SDL_BUTTON_MIDDLE => .mouse_middle,
        c.SDL_BUTTON_X1     => .mouse_x1,
        c.SDL_BUTTON_X2     => .mouse_x2,
        else => null,
    };

    return res;
}

pub fn DeleteEditorIntent(
    alive: *two_bit,
    has_sprite: *two_bit,
    select_buffer: *std.ArrayList(u32),
    input: RawInput,
) void {

    const delete_pressed = (input.buttons_pressed & Bit(.delete)) != 0;
    if (!delete_pressed) return;
    
    for (select_buffer.items) |entity| {
        alive.Clear(entity);
        has_sprite.Clear(entity);
    }

    select_buffer.clearRetainingCapacity();

}

pub fn BuildEditorSelectIntent(
    sprites: *std.ArrayList(helper.SpriteDraw),
    mouse_pos: math.Vec2,
    select_buffer: *std.ArrayList(u32),
    input: RawInput,
    allocator: std.mem.Allocator,
) !void {

    const left_pressed = (input.buttons_pressed & Bit(.mouse_left)) != 0;
    const multi_held   = (input.buttons_down & Bit(.shift)) != 0;
    //std.log.info("Selected buffer length is: {d}", .{select_buffer.items.len});

    if (!left_pressed) return;

    const entity = Select(sprites, mouse_pos);

    if (entity) |e| {

        if (multi_held){

            std.log.info("Multi held is being pressed", .{});

            for (select_buffer.items) |existing| {
                if (existing == e) return;
            }

            try select_buffer.append(allocator, e);

        } else {
            std.log.info("SELECTED", .{});
            select_buffer.clearRetainingCapacity();
            try select_buffer.append(allocator, e);

        }
    }else {
        std.log.info("Deselecting", .{}); 
        select_buffer.clearRetainingCapacity();

    }

}

pub fn BuildEditorIntent(
    sprites: *std.ArrayList(helper.SpriteDraw), 
    intent: *EditorIntent, 
    input: RawInput,
    mouse_pos: math.Vec2,
) void {

    const prev_zoom = intent.zoom;
    const drag_s = intent.drag_speed;

    intent.* = EditorIntent{
        .drag_speed = drag_s,
        .zoom = prev_zoom,
        .mouse_pos = input.mouse_pos,
    };

    // Drag
    if (input.buttons_down & Bit(.mouse_right) != 0) {
        intent.drag_delta = math.Vec2.Make(
            -input.mouse_delta.x,
            -input.mouse_delta.y,
        ).Mul(intent.drag_speed);
    }

    // Zoom
    if (input.scroll != 0) {
        const zoom_speed: f32 = 1.1;
        intent.zoom *= std.math.pow(f32, zoom_speed, input.scroll);
        intent.zoom = std.math.clamp(intent.zoom, 0.13, 5.0);
    }

    intent.zoom_changed = intent.zoom != prev_zoom;

    _ = sprites;
    _ = mouse_pos;
}

pub inline fn Bit(key: InputKey) InputBitSet {
    const idx: u8 = @intFromEnum(key);
    std.debug.assert(idx < 64);
    return (@as(InputBitSet, 1) << @intCast(idx));
}

pub fn Select(
    sprites: *std.ArrayList(helper.SpriteDraw),
    mouse: math.Vec2,
) ?u32 {
    var i: usize = sprites.items.len;
    while (i > 0) {
        i -= 1;

        const sprite = sprites.items[i];

        const min_x = sprite.sprite_pos[0];
        const max_x = sprite.sprite_pos[0] + sprite.sprite_scale[0];
        const min_y = sprite.sprite_pos[1];
        const max_y = sprite.sprite_pos[1] + sprite.sprite_scale[1];

        if (mouse.x >= min_x and mouse.x <= max_x and
            mouse.y >= min_y and mouse.y <= max_y)
        {
            std.log.info("Selected entity: {d} \n in location: {d}, {d}",
                .{ sprite.entity, sprite.sprite_pos[0], sprite.sprite_pos[1] });

            return sprite.entity;
        }
    }
    return null;
}

pub fn WorldToSlot(
    mouse_world: math.Vec2,
) ?struct { x: u32, y: u32 } {

    const TILE_W: f32 = 100.0;
    const TILE_H: f32 = 50.0;

    const BOARD_W: f32 = 64.0 * TILE_W;
    const BOARD_H: f32 = 128.0 * TILE_H;

    const half_w = BOARD_W * 0.5;
    const half_h = BOARD_H * 0.5;

    // Convert from centered world space → board-local space
    const local_x = mouse_world.x + half_w;
    const local_y = mouse_world.y + half_h;

    if (local_x < 0 or local_x >= BOARD_W) return null;
    if (local_y < 0 or local_y >= BOARD_H) return null;

    const x = @as(u32, @intFromFloat(local_x / TILE_W));
    const y = @as(u32, @intFromFloat(local_y / TILE_H));

    return .{ .x = x, .y = y };

}

