//! Core game-facing API types for the engine.
//!
//! This module defines the data structures and ABI-safe interfaces exposed to
//! game code. It includes sprite descriptors, input state, transform types,
//! input key enums, and engine API tables for gameplay, rendering, physics,
//! camera, and mouse access.
//!
//! These types are intended to be shared between the host engine and hot-loaded
//! game code.

const std = @import("std");

/// Describes a sprite to be spawned for an entity.
///
/// This is typically passed into `SpriteAPI.spawn_sprite`.
pub const SpriteDesc = struct {

    /// Optional sprite-local identifier.
    id: u32 = 0,

    /// Asset or atlas image name used to look up the sprite.
    name: []const u8,

    /// World position of the sprite.
    position: Position2D = .{.x = 0.0, .y = 0.0},

    /// Width and height scale of the sprite.
    scale: Scale2D = .{.x = 0.0, .y = 0.0},

    /// Rotation data for the sprite
    rotation: Rotation2D = .{.x =0.0, .y =0.0}, 

    /// RGBA tint applied to the sprite.
    color: Color,

    /// Atlas identifier used by the renderer.
    atlas_id: u32,

};


/// Snapshot of current input state.
///
/// This is ABI-safe and suitable for passing across shared library boundaries.
pub const InputDesc = extern struct {

    /// Bitset of buttons currently held down.
    buttons_down: u64,

    /// Bitset of buttons pressed this frame.
    buttons_pressed: u64,

    /// Current mouse position.
    mouse_pos: Position2D,

    /// Mouse movement delta since last frame.
    mouse_delta: Position2D,

    /// Scroll wheel delta or scale factor.
    scroll: f32 = 1.0,
};

/// 2D transform consisting of position, scale, and rotation.
pub const Transform2D = extern struct {

    /// Position component.
    position: Position2D = .{},

    /// Scale component.
    scale: Scale2D = .{},

    /// Rotation component.
    rotation: Rotation2D = .{},
};

/// 2D position in world or local space.
pub const Position2D = extern struct {
    /// X coordinate.
    x: f32 = 0,

    /// Y coordinate.
    y: f32 = 0,
};

/// 2D scale.
pub const Scale2D = extern struct {
    /// Scale on the X axis.
    x: f32 = 0,

    /// Scale on the Y axis.
    y: f32 = 0,
};

/// 2D rotation representation.
pub const Rotation2D = extern struct {
    x: f32 = 0,
    y: f32 = 0,
};


/// RGBA color with float components in the range `[0, 1]`.
pub const Color = extern struct {
    /// Red channel.
    r: f32 = 0,

    /// Green channel.
    g: f32 = 0,

    /// Blue channel.
    b: f32 = 0,

    /// Alpha channel.
    a: f32 = 0,
};

/// Supported logical input keys.
///
/// This enum contains keyboard keys, mouse buttons, and gamepad buttons.
pub const InputKey = enum(u8) {
    /// Letter A.
    a = 0,
    /// Letter B.
    b,
    /// Letter C.
    c,
    /// Letter D.
    d,
    /// Letter E.
    e,
    /// Letter F.
    f,
    /// Letter G.
    g,
    /// Letter H.
    h,
    /// Letter I.
    i,
    /// Letter J.
    j,
    /// Letter K.
    k,
    /// Letter L.
    l,
    /// Letter M.
    m,
    /// Letter N.
    n,
    /// Letter O.
    o,
    /// Letter P.
    p,
    /// Letter Q.
    q,
    /// Letter R.
    r,
    /// Letter S.
    s,
    /// Letter T.
    t,
    /// Letter U.
    u,
    /// Letter V.
    v,
    /// Letter W.
    w,
    /// Letter X.
    x,
    /// Letter Y.
    y,
    /// Letter Z.
    z,

    /// Number 0.
    num_0,
    /// Number 1.
    num_1,
    /// Number 2.
    num_2,
    /// Number 3.
    num_3,
    /// Number 4.
    num_4,
    /// Number 5.
    num_5,
    /// Number 6.
    num_6,
    /// Number 7.
    num_7,
    /// Number 8.
    num_8,
    /// Number 9.
    num_9,

    /// Space bar.
    space,
    /// Enter/return.
    enter,
    /// Escape key.
    escape,
    /// Tab key.
    tab,
    /// Backspace key.
    backspace,
    /// Shift modifier.
    shift,
    /// Control modifier.
    ctrl,
    /// Alt modifier.
    alt,
    /// Delete key.
    delete,

    /// Left mouse button.
    mouse_left,
    /// Right mouse button.
    mouse_right,
    /// Middle mouse button.
    mouse_middle,
    /// Extra mouse button 1.
    mouse_x1,
    /// Extra mouse button 2.
    mouse_x2,

    /// South face button on gamepad.
    pad_a,
    /// East face button on gamepad.
    pad_b,
    /// West face button on gamepad.
    pad_x,
    /// North face button on gamepad.
    pad_y,
    /// Left bumper.
    pad_lb,
    /// Right bumper.
    pad_rb,
    /// Back/select button.
    pad_back,
    /// Start/menu button.
    pad_start,
    /// Left stick press.
    pad_ls,
    /// Right stick press.
    pad_rs,

    /// D-pad up.
    pad_up,
    /// D-pad down.
    pad_down,
    /// D-pad left.
    pad_left,
    /// D-pad right.
    pad_right,
};

/// ABI-safe wrapper around `InputKey`.
///
/// This is useful when exposing input values across `extern` boundaries.
pub const InputKeyExtern = extern struct {
    /// Raw integer value of the key.
    value: u8,

    /// Key constant for `a`.
    pub const a = InputKeyExtern{ .value = @intFromEnum(InputKey.a) };
    /// Key constant for `b`.
    pub const b = InputKeyExtern{ .value = @intFromEnum(InputKey.b) };
    /// Key constant for `c`.
    pub const c = InputKeyExtern{ .value = @intFromEnum(InputKey.c) };
    /// Key constant for `d`.
    pub const d = InputKeyExtern{ .value = @intFromEnum(InputKey.d) };
    /// Key constant for `e`.
    pub const e = InputKeyExtern{ .value = @intFromEnum(InputKey.e) };
    /// Key constant for `f`.
    pub const f = InputKeyExtern{ .value = @intFromEnum(InputKey.f) };
    /// Key constant for `g`.
    pub const g = InputKeyExtern{ .value = @intFromEnum(InputKey.g) };
    /// Key constant for `h`.
    pub const h = InputKeyExtern{ .value = @intFromEnum(InputKey.h) };
    /// Key constant for `i`.
    pub const i = InputKeyExtern{ .value = @intFromEnum(InputKey.i) };
    /// Key constant for `j`.
    pub const j = InputKeyExtern{ .value = @intFromEnum(InputKey.j) };
    /// Key constant for `k`.
    pub const k = InputKeyExtern{ .value = @intFromEnum(InputKey.k) };
    /// Key constant for `l`.
    pub const l = InputKeyExtern{ .value = @intFromEnum(InputKey.l) };
    /// Key constant for `m`.
    pub const m = InputKeyExtern{ .value = @intFromEnum(InputKey.m) };
    /// Key constant for `n`.
    pub const n = InputKeyExtern{ .value = @intFromEnum(InputKey.n) };
    /// Key constant for `o`.
    pub const o = InputKeyExtern{ .value = @intFromEnum(InputKey.o) };
    /// Key constant for `p`.
    pub const p = InputKeyExtern{ .value = @intFromEnum(InputKey.p) };
    /// Key constant for `q`.
    pub const q = InputKeyExtern{ .value = @intFromEnum(InputKey.q) };
    /// Key constant for `r`.
    pub const r = InputKeyExtern{ .value = @intFromEnum(InputKey.r) };
    /// Key constant for `s`.
    pub const s = InputKeyExtern{ .value = @intFromEnum(InputKey.s) };
    /// Key constant for `t`.
    pub const t = InputKeyExtern{ .value = @intFromEnum(InputKey.t) };
    /// Key constant for `u`.
    pub const u = InputKeyExtern{ .value = @intFromEnum(InputKey.u) };
    /// Key constant for `v`.
    pub const v = InputKeyExtern{ .value = @intFromEnum(InputKey.v) };
    /// Key constant for `w`.
    pub const w = InputKeyExtern{ .value = @intFromEnum(InputKey.w) };
    /// Key constant for `x`.
    pub const x = InputKeyExtern{ .value = @intFromEnum(InputKey.x) };
    /// Key constant for `y`.
    pub const y = InputKeyExtern{ .value = @intFromEnum(InputKey.y) };
    /// Key constant for `z`.
    pub const z = InputKeyExtern{ .value = @intFromEnum(InputKey.z) };

    /// Key constant for `0`.
    pub const num_0 = InputKeyExtern{ .value = @intFromEnum(InputKey.num_0) };
    /// Key constant for `1`.
    pub const num_1 = InputKeyExtern{ .value = @intFromEnum(InputKey.num_1) };
    /// Key constant for `2`.
    pub const num_2 = InputKeyExtern{ .value = @intFromEnum(InputKey.num_2) };
    /// Key constant for `3`.
    pub const num_3 = InputKeyExtern{ .value = @intFromEnum(InputKey.num_3) };
    /// Key constant for `4`.
    pub const num_4 = InputKeyExtern{ .value = @intFromEnum(InputKey.num_4) };
    /// Key constant for `5`.
    pub const num_5 = InputKeyExtern{ .value = @intFromEnum(InputKey.num_5) };
    /// Key constant for `6`.
    pub const num_6 = InputKeyExtern{ .value = @intFromEnum(InputKey.num_6) };
    /// Key constant for `7`.
    pub const num_7 = InputKeyExtern{ .value = @intFromEnum(InputKey.num_7) };
    /// Key constant for `8`.
    pub const num_8 = InputKeyExtern{ .value = @intFromEnum(InputKey.num_8) };
    /// Key constant for `9`.
    pub const num_9 = InputKeyExtern{ .value = @intFromEnum(InputKey.num_9) };

    /// Key constant for space.
    pub const space = InputKeyExtern{ .value = @intFromEnum(InputKey.space) };
    /// Key constant for enter.
    pub const enter = InputKeyExtern{ .value = @intFromEnum(InputKey.enter) };
    /// Key constant for escape.
    pub const escape = InputKeyExtern{ .value = @intFromEnum(InputKey.escape) };
    /// Key constant for tab.
    pub const tab = InputKeyExtern{ .value = @intFromEnum(InputKey.tab) };
    /// Key constant for backspace.
    pub const backspace = InputKeyExtern{ .value = @intFromEnum(InputKey.backspace) };
    /// Key constant for shift.
    pub const shift = InputKeyExtern{ .value = @intFromEnum(InputKey.shift) };
    /// Key constant for ctrl.
    pub const ctrl = InputKeyExtern{ .value = @intFromEnum(InputKey.ctrl) };
    /// Key constant for alt.
    pub const alt = InputKeyExtern{ .value = @intFromEnum(InputKey.alt) };
    /// Key constant for delete.
    pub const delete = InputKeyExtern{ .value = @intFromEnum(InputKey.delete) };

    /// Key constant for left mouse button.
    pub const mouse_left = InputKeyExtern{ .value = @intFromEnum(InputKey.mouse_left) };
    /// Key constant for right mouse button.
    pub const mouse_right = InputKeyExtern{ .value = @intFromEnum(InputKey.mouse_right) };
    /// Key constant for middle mouse button.
    pub const mouse_middle = InputKeyExtern{ .value = @intFromEnum(InputKey.mouse_middle) };
    /// Key constant for extra mouse button 1.
    pub const mouse_x1 = InputKeyExtern{ .value = @intFromEnum(InputKey.mouse_x1) };
    /// Key constant for extra mouse button 2.
    pub const mouse_x2 = InputKeyExtern{ .value = @intFromEnum(InputKey.mouse_x2) };

    /// Key constant for gamepad A.
    pub const pad_a = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_a) };
    /// Key constant for gamepad B.
    pub const pad_b = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_b) };
    /// Key constant for gamepad X.
    pub const pad_x = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_x) };
    /// Key constant for gamepad Y.
    pub const pad_y = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_y) };
    /// Key constant for left bumper.
    pub const pad_lb = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_lb) };
    /// Key constant for right bumper.
    pub const pad_rb = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_rb) };
    /// Key constant for back/select.
    pub const pad_back = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_back) };
    /// Key constant for start/menu.
    pub const pad_start = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_start) };
    /// Key constant for left stick click.
    pub const pad_ls = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_ls) };
    /// Key constant for right stick click.
    pub const pad_rs = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_rs) };
    /// Key constant for d-pad up.
    pub const pad_up = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_up) };
    /// Key constant for d-pad down.
    pub const pad_down = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_down) };
    /// Key constant for d-pad left.
    pub const pad_left = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_left) };
    /// Key constant for d-pad right.
    pub const pad_right = InputKeyExtern{ .value = @intFromEnum(InputKey.pad_right) };

    /// Converts the ABI-safe wrapper back into an `InputKey`.
    pub fn toKey(self: InputKeyExtern) InputKey {
        return @enumFromInt(self.value);
    }
};

/// Core entity and transform functions exposed by the engine.
pub const GameAPI = extern struct {
    /// User-defined opaque pointer owned by the host.
    user_data: ?*anyopaque,

    /// Creates a new entity and returns its ID.
    add_entity: *const fn () callconv(.c) u32,

    /// Removes an entity and its associated components.
    remove_enity: *const fn (u32) callconv(.c) void,

    /// Returns the engine allocator as an opaque pointer.
    get_allocator: *const fn () callconv(.c) *anyopaque,

    /// Adds or replaces a 2D transform for an entity.
    add_transform_2D: *const fn (u32, Transform2D) callconv(.c) void,
};

/// Sprite-related API exposed by the engine.
///
/// Note: this uses `Position`, but only `Position2D` exists above. You likely
/// want `Position2D` here unless `Position` is defined elsewhere.
pub const SpriteAPI = extern struct {

    /// Sets the world position of a sprite owned by an entity.
    set_entity_sprites_world_pos: *const fn (u32, Position2D) callconv(.c) void,

    get_entity_sprites_world_pos: *const fn (u32, Position2D) callconv(.c) void,

    /// Sets the world position of a sprite owned by an entity.
    set_sprite_world_pos: *const fn (u32, u32, Position2D) callconv(.c) void,

    /// Returns the current sprite world position.
    get_sprite_world_pos: *const fn (u32, u32) callconv(.c) Position2D,

    /// Sets the active sprite color tint.
    set_sprite_color: *const fn (u32, u32, Color) callconv(.c) void,

    /// Returns the active sprite color tint.
    get_sprite_color: *const fn (u32, u32) callconv(.c) Color,

    set_entity_sprites_color: *const fn (u32, Color) callconv(.c) void, 
    
    get_entity_sprites_color: *const fn (u32) callconv(.c) Color,
    /// Spawns a sprite for the given entity using a sprite descriptor.
    spawn_sprite: *const fn (*const SpriteDesc, u32) callconv(.c) void,
};

/// Physics-related functions exposed by the engine.
pub const PhysicsAPI = extern struct {
    /// Enables gravity for an entity.
    enable_gravity: *const fn (u32) callconv(.c) void,

    /// Applies a 2D force to an entity.
    add_force: *const fn (u32, f32, f32) callconv(.c) void,

    /// Applies force on the X axis only.
    add_force_x: *const fn (u32, f32) callconv(.c) void,

    /// Applies force on the Y axis only.
    add_force_y: *const fn (u32, f32) callconv(.c) void,

    /// Adds a physics component to an entity.
    add_physics: *const fn (u32) callconv(.c) void,

    /// Removes a physics component from an entity.
    remove_physics: *const fn (u32) callconv(.c) void,
};

/// Camera controls exposed by the engine.
///
pub const Camera2DAPI = extern struct {
    /// Sets the camera position and zoom immediately.
    set_camera_world_pos: *const fn (Position2D, f32) callconv(.c) void,

    /// Smoothly moves the camera toward a target position and zoom.
    move_camera_to_world_pos: *const fn (Position2D, f32) callconv(.c) void,

    /// Moves the camera vertically over time.
    move_camera_vertical: *const fn (f32, f32) callconv(.c) void,

    /// Moves the camera horizontally over time.
    move_camera_horizontal: *const fn (f32, f32) callconv(.c) void,
};

/// Mouse helpers exposed by the engine.
///
/// Note: this also uses `Position2D` in place of `Position`.
pub const MouseAPI = extern struct {
    /// Sets the mouse world-space position.
    set_mouse_world_pos: *const fn (Position2D) callconv(.c) void,

    /// Returns the current mouse world-space position.
    get_mouse_world_pos: *const fn () callconv(.c) Position2D,
};

/// Opaque shared memory region exposed to the game module.
pub const GameMemory = extern struct {
    /// Pointer to the memory block.
    ptr: ?*anyopaque,

    /// Size of the memory block in bytes.
    size: usize,
};

/// Exported game entry points.
///
/// If this is shared across a C ABI boundary, function pointers are usually
/// safer than bare function types inside an `extern struct`.
pub const GameExports = extern struct {
    /// Called once during startup to initialize the game.
    init: *const fn (*GameAPI) callconv(.c) void,

    /// Called every frame with delta time in seconds.
    update: *const fn (f32) callconv(.c) void,
};
