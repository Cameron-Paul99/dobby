const std = @import("std");

pub const SpriteDesc = struct {
    id: u32 = 0,
    name: []const u8,
    sprite_pos: [2]f32, 
    sprite_scale: [2]f32, 
    sprite_rotation: [2]f32, 
    tint: [4]f32, 
    atlas_id: u32,
};


pub const Transform2D = extern struct {
    pos_x: f32 = 0.0,
    pos_y: f32 = 0.0,
    scale_x: f32 = 0.0,
    scale_y: f32 = 0.0,
    rot_x: f32 = 0.0,
    rot_y: f32 = 0.0,
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
    set_transform_2D: *const fn (u32, Transform2D) callconv(.c) void,
};

pub const GameMemory = extern struct {
    ptr: ?*anyopaque,
    size: usize,
};

pub const GameExports = extern struct {
    init: fn (*GameAPI) callconv(.c) void,
    update: fn (f32) callconv(.c) void,
};
