const std = @import("std");

pub const SpriteDesc = extern struct {

};

pub const GameAPI = extern struct {
    spawn_sprite: *const fn (*const SpriteDesc) callconv(.c) u32,
    set_sprite_pos: *const fn (u32, f32, f32) callconv(.c) void, 
};

pub const GameExports = extern struct {
    init: fn (*GameAPI) callconv(.c) void,
    update: fn (f32) callconv(.c) void,
};
