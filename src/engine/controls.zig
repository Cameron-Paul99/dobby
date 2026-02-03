const std = @import("std");
const utils = @import("utils");
const c = @import("clibs.zig").c;
const math = utils.math;

pub const InputBitSet = u64;

pub const RawInput = struct {
    buttons_down: InputBitSet = 0,
    buttons_pressed: InputBitSet = 0,
    mouse_pos: math.Vec2 = math.Vec2.ZERO,
    mouse_delta: math.Vec2 = math.Vec2.ZERO,
    scroll: f32 = 0,
};

pub const EditorIntent = struct {
    camera_move: math.Vec3 = math.Vec3.ZERO,
    camera_rotate: math.Vec2 = math.Vec2.ZERO,
    drag_delta: math.Vec2 = math.Vec2.ZERO,
    drag_speed: f32 = 0,
    selection_mask: u64 = 0,
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

pub fn BuildEditorIntent(intent: *EditorIntent, input: RawInput) void {
    const drag_s = intent.drag_speed;
    intent.* = EditorIntent{
        .drag_speed = drag_s,
    }; // reset intent each frame

    if (input.buttons_down & Bit(.mouse_right) != 0) {

        intent.drag_delta = input.mouse_delta;
        intent.drag_delta = intent.drag_delta.Mul(intent.drag_speed);
    }
}

pub inline fn Bit(key: InputKey) InputBitSet {
    const idx: u8 = @intFromEnum(key);
    std.debug.assert(idx < 64);
    return (@as(InputBitSet, 1) << @intCast(idx));
}
