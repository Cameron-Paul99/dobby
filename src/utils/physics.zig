const std = @import("std");
const math = @import("math.zig");
const two_bit = @import("two_bit.zig");
const g_api = @import("game_api");
const Transform2D = g_api.Transform2D;
const Self = @This();

gravity_bits: two_bit,
velocities: two_bit,

const GRAVITY = 9.81;


pub fn init(max: u32, allocator: std.mem.Allocator) *Self {
    return.{
        .gravity_bits = try two_bit.init(max, allocator),
        .velocities = try two_bit.init(max, allocator),
    }

}
pub fn deinit(*Self) void {
    self.gravity_bits.deinit();
    self.velocities.deinit();
}

pub fn EnableGravity(entity: u32) void {
    gravity_bits.Set(entity);
}

pub fn Gravity(transform: *Transform2D) void {

    _ = transform;

}
