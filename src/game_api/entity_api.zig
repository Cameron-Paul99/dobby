const std = @import("std");

pub export fn RemoveEntity(id: u32) callconv(.c) void {
    const ctx = g_active_ctx;
    ctx.alive.Clear(id);
}

pub export fn AddEntity() callconv(.c) u32 {
    const ctx = g_active_ctx;
    const id = ctx.alive.Create() orelse unreachable;

    const entity_transform = Transform2D {};
    
    ctx.entity_transforms[id] = entity_transform;
   // std.log.info("Entity {d} is alive", .{id});
    return id;
}

pub export fn SetTransform(id: u32, transform: Transform2D) callconv(.c) void {
     const ctx = g_active_ctx;
     ctx.entity_transforms[id] = transform;
    

}
pub export fn AddTransform2D(id: u32, delta: Transform2D) callconv(.c) void {
    const ctx = g_active_ctx;
    var t = &ctx.entity_transforms[id];

    t.pos_x += delta.pos_x;
    t.pos_y += delta.pos_y;

    t.scale_x += delta.scale_x;
    t.scale_y += delta.scale_y;

    t.rot_x += delta.rot_x;
    t.rot_y += delta.rot_y;

    if (ctx.has_sprite.testBit(id)) {
        var sprite = &ctx.sprite_components[id];
        sprite.sprite_pos = .{ t.pos_x, t.pos_y };
        sprite.sprite_scale = .{ t.scale_x, t.scale_y };
        sprite.sprite_rotation = .{ t.rot_x, t.rot_y }; 
    }
}

pub export fn AddTransform2DPos(id: u32, dx: f32, dy: f32) callconv(.c) void {
    const ctx = g_active_ctx;
    ctx.entity_transforms[id].pos_x += dx;
    ctx.entity_transforms[id].pos_y += dy;
      if (ctx.has_sprite.testBit(id)) {
        const t = ctx.entity_transforms[id];
        var s = &ctx.sprite_components[id];
        s.sprite_pos = .{ t.pos_x, t.pos_y };
    }
}


