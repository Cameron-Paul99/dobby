const std = @import("std");

pub const SpriteDesc = struct {
    id: u32 = 0,
    name: []const u8,
    sprite_pos: [2]f32 = .{0.0, 0.0}, 
    sprite_scale: [2]f32 = .{0.0, 0.0}, 
    sprite_rotation: [2]f32 = .{0.0, 0.0}, 
    tint: [4]f32, 
    atlas_id: u32,
};

pub const InputDesc = extern struct {
    buttons_down: u64,
    buttons_pressed: u64,
    mouse_pos: [2]f32,
    mouse_delta: [2]f32,
    scroll: f32 = 1.0,
};


pub const Transform2D = extern struct {
    pos_x: f32 = 0.0,
    pos_y: f32 = 0.0,
    scale_x: f32 = 0.0,
    scale_y: f32 = 0.0,
    rot_x: f32 = 0.0,
    rot_y: f32 = 0.0,
};

pub const InputKey = enum(u8) {
    // Letters
    a = 0, b, c, d, e, f, g,
    h, i, j, k, l, m, n,
    o, p, q, r, s, t, u,
    v, w, x, y, z,
    // Numbers
    num_0, num_1, num_2, num_3, num_4,
    num_5, num_6, num_7, num_8, num_9,
    // Modifiers and system keys
    space, enter, escape, tab, backspace,
    shift, ctrl, alt, delete,
    // Mouse buttons
    mouse_left, mouse_right, mouse_middle, mouse_x1, mouse_x2,
    // Xbox and PlayStation
    pad_a, pad_b, pad_x, pad_y,
    pad_lb, pad_rb, pad_back, pad_start,
    pad_ls, pad_rs,
    // D Pad digital
    pad_up, pad_down, pad_left, pad_right,
};

pub const InputKeyExtern = extern struct {
    value: u8,

    pub const a            = InputKeyExtern{ .value = @intFromEnum(InputKey.a) };
    pub const b            = InputKeyExtern{ .value = @intFromEnum(InputKey.b) };
    pub const c            = InputKeyExtern{ .value = @intFromEnum(InputKey.c) };
    pub const d            = InputKeyExtern{ .value = @intFromEnum(InputKey.d) };
    pub const e            = InputKeyExtern{ .value = @intFromEnum(InputKey.e) };
    pub const f            = InputKeyExtern{ .value = @intFromEnum(InputKey.f) };
    pub const g            = InputKeyExtern{ .value = @intFromEnum(InputKey.g) };
    pub const h            = InputKeyExtern{ .value = @intFromEnum(InputKey.h) };
    pub const i            = InputKeyExtern{ .value = @intFromEnum(InputKey.i) };
    pub const j            = InputKeyExtern{ .value = @intFromEnum(InputKey.j) };
    pub const k            = InputKeyExtern{ .value = @intFromEnum(InputKey.k) };
    pub const l            = InputKeyExtern{ .value = @intFromEnum(InputKey.l) };
    pub const m            = InputKeyExtern{ .value = @intFromEnum(InputKey.m) };
    pub const n            = InputKeyExtern{ .value = @intFromEnum(InputKey.n) };
    pub const o            = InputKeyExtern{ .value = @intFromEnum(InputKey.o) };
    pub const p            = InputKeyExtern{ .value = @intFromEnum(InputKey.p) };
    pub const q            = InputKeyExtern{ .value = @intFromEnum(InputKey.q) };
    pub const r            = InputKeyExtern{ .value = @intFromEnum(InputKey.r) };
    pub const s            = InputKeyExtern{ .value = @intFromEnum(InputKey.s) };
    pub const t            = InputKeyExtern{ .value = @intFromEnum(InputKey.t) };
    pub const u            = InputKeyExtern{ .value = @intFromEnum(InputKey.u) };
    pub const v            = InputKeyExtern{ .value = @intFromEnum(InputKey.v) };
    pub const w            = InputKeyExtern{ .value = @intFromEnum(InputKey.w) };
    pub const x            = InputKeyExtern{ .value = @intFromEnum(InputKey.x) };
    pub const y            = InputKeyExtern{ .value = @intFromEnum(InputKey.y) };
    pub const z            = InputKeyExtern{ .value = @intFromEnum(InputKey.z) };
    pub const num_0        = InputKeyExtern{ .value = @intFromEnum(InputKey.num_0) };
    pub const num_1        = InputKeyExtern{ .value = @intFromEnum(InputKey.num_1) };
    pub const num_2        = InputKeyExtern{ .value = @intFromEnum(InputKey.num_2) };
    pub const num_3        = InputKeyExtern{ .value = @intFromEnum(InputKey.num_3) };
    pub const num_4        = InputKeyExtern{ .value = @intFromEnum(InputKey.num_4) };
    pub const num_5        = InputKeyExtern{ .value = @intFromEnum(InputKey.num_5) };
    pub const num_6        = InputKeyExtern{ .value = @intFromEnum(InputKey.num_6) };
    pub const num_7        = InputKeyExtern{ .value = @intFromEnum(InputKey.num_7) };
    pub const num_8        = InputKeyExtern{ .value = @intFromEnum(InputKey.num_8) };
    pub const num_9        = InputKeyExtern{ .value = @intFromEnum(InputKey.num_9) };
    pub const space        = InputKeyExtern{ .value = @intFromEnum(InputKey.space) };
    pub const enter        = InputKeyExtern{ .value = @intFromEnum(InputKey.enter) };
    pub const escape       = InputKeyExtern{ .value = @intFromEnum(InputKey.escape) };
    pub const tab          = InputKeyExtern{ .value = @intFromEnum(InputKey.tab) };
    pub const backspace    = InputKeyExtern{ .value = @intFromEnum(InputKey.backspace) };
    pub const shift        = InputKeyExtern{ .value = @intFromEnum(InputKey.shift) };
    pub const ctrl         = InputKeyExtern{ .value = @intFromEnum(InputKey.ctrl) };
    pub const alt          = InputKeyExtern{ .value = @intFromEnum(InputKey.alt) };
    pub const delete       = InputKeyExtern{ .value = @intFromEnum(InputKey.delete) };
    pub const mouse_left   = InputKeyExtern{ .value = @intFromEnum(InputKey.mouse_left) };
    pub const mouse_right  = InputKeyExtern{ .value = @intFromEnum(InputKey.mouse_right) };
    pub const mouse_middle = InputKeyExtern{ .value = @intFromEnum(InputKey.mouse_middle) };
    pub const mouse_x1     = InputKeyExtern{ .value = @intFromEnum(InputKey.mouse_x1) };
    pub const mouse_x2     = InputKeyExtern{ .value = @intFromEnum(InputKey.mouse_x2) };
    pub const pad_a        = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_a) };
    pub const pad_b        = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_b) };
    pub const pad_x        = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_x) };
    pub const pad_y        = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_y) };
    pub const pad_lb       = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_lb) };
    pub const pad_rb       = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_rb) };
    pub const pad_back     = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_back) };
    pub const pad_start    = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_start) };
    pub const pad_ls       = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_ls) };
    pub const pad_rs       = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_rs) };
    pub const pad_up       = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_up) };
    pub const pad_down     = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_down) };
    pub const pad_left     = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_left) };
    pub const pad_right    = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_right) };

    pub fn toKey(self: InputKeyExtern) InputKey {
        return @enumFromInt(self.value);
    }
};


pub const GameAPI = extern struct {
    user_data: ?*anyopaque,
    add_entity: *const fn () callconv(.c) u32,
    remove_enity: *const fn (u32) callconv(.c) void, 
    spawn_sprite: *const fn (*const SpriteDesc, u32) callconv(.c) void,
    set_sprite_pos: *const fn (u32, f32, f32) callconv(.c) void,
    get_allocator: *const fn () callconv(.c) *anyopaque,
    add_physics: *const fn (u32) callconv(.c) void,
    remove_physics: *const fn (u32) callconv(.c) void,
    add_transform_2D: *const fn (u32, Transform2D) callconv(.c) void,
};

pub const PhysicsAPI = extern struct {
    enable_gravity: *const fn (u32) callconv(.c) void,
    add_force: *const fn (u32, f32, f32) callconv(.c) void,
    add_force_x: *const fn (u32, f32) callconv(.c) void,
    add_force_y: *const fn (u32, f32) callconv(.c) void,
};

pub const CameraAPI = extern struct {
    set_camera_pos: *const fn (f32, f32) callconv(.c) void,
    move_camera_to: *const fn (f32, f32, f32) callconv(.c) void,
    move_camera_vertical: *const fn (f32, f32) callconv(.c) void,
    move_camera_horizontal: *const fn (f32, f32) callconv(.c) void,
    // TODO: Drag and input
};

pub const MouseAPI = extern struct {
    set_mouse_pos: *const fn (f32, f32) callconv(.c) void,

};

pub const GameMemory = extern struct {
    ptr: ?*anyopaque,
    size: usize,
};

pub const GameExports = extern struct {
    init: fn (*GameAPI) callconv(.c) void,
    update: fn (f32) callconv(.c) void,
};



