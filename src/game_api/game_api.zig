const std = @import("std");

pub const SpriteDesc = struct {
    id: u32 = 0,
    sprite_pos: [2]f32, 
    sprite_scale: [2]f32, 
    sprite_rotation: [2]f32, 
    uv_min: [2]f32, 
    uv_max: [2]f32, 
    tint: [4]f32, 
    atlas_id: u32,
};

pub const GameAPI = extern struct {
    user_data: ?*anyopaque,
    spawn_sprite: *const fn (*const SpriteDesc) callconv(.c) u32,
    set_sprite_pos: *const fn (u32, f32, f32) callconv(.c) void,
    get_allocator: *const fn () callconv(.c) *anyopaque,
};

pub const GameExports = extern struct {
    init: fn (*GameAPI) callconv(.c) void,
    update: fn (f32) callconv(.c) void,
};
