const std = @import("std");
const math = @import("math.zig");
const two_bit = @import("two_bit.zig");
const g_api = @import("game_api");
const Transform2D = g_api.Transform2D;
const Self = @This();

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Mat4 = math.Mat4;

gravity_bits: two_bit,
velocities: []Vec2,
weights: []f32,
const GRAVITY = 0.8;
const TERMINAL: f32 = 20.0;

pub fn Step(self: *Self, entity: u32, transform: *Transform2D) void {
    
    self.Gravity(entity, transform);
    const vel = self.velocities[entity];
    transform.pos_x += vel.x;
    transform.pos_y += vel.y;

}

pub fn AddForce(self: *Self, entity: u32, x: f32, y: f32) void {

    var vel = &self.velocities[entity];
    vel.x += x;
    vel.y += y;
}

pub fn AddForceX(self: *Self, entity: u32, x: f32) void {
     var vel = &self.velocities[entity];
     vel.x += x;
}

pub fn AddForceY(self: *Self, entity: u32, y: f32)  void {
    var vel = &self.velocities[entity];
    vel.y += y;
}

pub fn init(max: u32, allocator: std.mem.Allocator) !Self {
    const physics = Self{
        .gravity_bits = try two_bit.init(max, allocator),
        .velocities = try allocator.alloc(Vec2, max),
        .weights = try allocator.alloc(f32, max),
    };

    for (physics.velocities) |*v| {
        v.* = Vec2.ZERO;
    }

    @memset(physics.weights, 1.0);

    return physics;

}
pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.gravity_bits.deinit();
    allocator.free(self.velocities);
    allocator.free(self.weights);
}

pub fn EnableGravity(self: *Self, entity: u32) void {
    self.gravity_bits.Set(entity);
}

pub fn Gravity(self: *Self, entity: u32, transform: *Transform2D) void {

   if (!self.gravity_bits.testBit(entity)) return; 
   var vel = &self.velocities[entity];
   const weight = &self.weights[entity];

   vel.y += GRAVITY * weight.*;

   if (vel.y > TERMINAL){
        vel.y = TERMINAL;
   }

   transform.pos_y += vel.y;
}

