const std = @import("std");

pub export fn AddPhysics(id: u32) callconv(.c) void {

    const ctx = g_active_ctx;
    ctx.static_dirty = true;
    ctx.physics.Set(id);

}

pub export fn RemovePhysics(id: u32) callconv(.c) void {
    const ctx = g_active_ctx;
    ctx.static_dirty = true;
    ctx.physics.Clear(id);
}

pub export fn EnableGravity(id: u32) callconv(.c) void {
    const ctx = physics_ctx;
    ctx.EnableGravity(id);
}

pub export fn AddForce(id: u32, x: f32, y: f32) callconv(.c) void {
    const ctx = physics_ctx;
    ctx.AddForce(id, x, y);
}

pub export fn AddForceX(id: u32, x:f32) callconv(.c) void {
    const ctx = physics_ctx;
    ctx.AddForceX(id, x);
}

pub export fn AddForceY(id: u32, y:f32) callconv(.c) void {
    const ctx = physics_ctx;
    ctx.AddForceY(id, y);
}


