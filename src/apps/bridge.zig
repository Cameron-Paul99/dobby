const std = @import("std");
const g_api = @import("game_api");
const utils = @import("utils");
const editor = @import("editor_sdl_main.zig");
const engine = @import("engine");
const ProjectContext = editor.ProjectContext;

const Physics = utils.physics;
const Camera = utils.camera;
const Mouse = utils.mouse;
const atlas_mod = utils.atlas;
const Transform2D = g_api.Transform2D;
const Position2D = g_api.Position2D;
const Scale2D = g_api.Scale2D;
const Rotation2D = g_api.Rotation2D;
const Color = g_api.Color;
const helper = engine.helper;

const Self = @This();

pub var g_active_ctx: *ProjectContext = undefined;
pub var physics_ctx: *Physics = undefined;
pub var cam_ctx: *Camera = undefined;
pub var mouse_ctx: *Mouse = undefined;

const MAX_SPRITES_PER_ENTITY = 50;

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

pub export fn RemoveEntity(entity: u32) callconv(.c) void {
    const ctx = g_active_ctx;

    if (!ctx.alive.testBit(entity)) return;
    ctx.alive.Clear(entity);
    std.log.info("removing chips", .{});
    ctx.has_sprite.Clear(entity);
    ctx.physics.Clear(entity);
   
    ctx.static_sprite_draws.clearRetainingCapacity();
}

pub export fn AddEntity() callconv(.c) u32 {
    const ctx = g_active_ctx;
    const id = ctx.alive.Create() orelse unreachable;

    const entity_transform = Transform2D {};
    
    ctx.entity_transforms[id] = entity_transform;
   // std.log.info("Entity {d} is alive", .{id});
    return id;
}

pub export fn SetMouseWorldPosition(pos: Position2D) callconv(.c) void {
   const ctx = mouse_ctx;
   ctx.world_pos.x = pos.x;
   ctx.world_pos.y = pos.y;
}

pub export fn GetMouseWorldPosition() callconv(.c) Position2D {
    const ctx = mouse_ctx;
    return .{
        .x = ctx.world_pos.x,
        .y = ctx.world_pos.y
    };
}

pub export fn SetCameraWorldPosition(pos: Position2D, zoom: f32) callconv(.c) void {
    const ctx = cam_ctx;
    ctx.pos.x = pos.x;
    ctx.pos.y = pos.y;
    ctx.zoom = zoom;
}
pub export fn SetTransform(id: u32, transform: Transform2D) callconv(.c) void {
    const ctx = g_active_ctx;
    ctx.entity_transforms[id] = transform;

    if (ctx.has_sprite.testBit(id)) {
        const sprites = GetEntitySprites(ctx, id);

        for (sprites) |*sprite| {
            sprite.sprite_pos = .{
                transform.position.x,
                transform.position.y,
            };
            sprite.sprite_scale = .{
                transform.scale.x,
                transform.scale.y,
            };
            sprite.sprite_rotation = .{
                transform.rotation.x,
                transform.rotation.y,
            };
        }
    }
}

pub export fn AddTransform2D(id: u32, delta: Transform2D) callconv(.c) void {
    const ctx = g_active_ctx;
    var t = &ctx.entity_transforms[id];

    t.position.x += delta.position.x;
    t.position.y += delta.position.y;

    t.scale.x += delta.scale.x;
    t.scale.y += delta.scale.y;

    t.rotation.x += delta.rotation.x;
    t.rotation.y += delta.rotation.y;

    if (ctx.has_sprite.testBit(id)) {
        const sprites = GetEntitySprites(ctx, id);

        for (sprites) |*sprite| {
            sprite.sprite_pos = .{ t.position.x, t.position.y };
            sprite.sprite_scale = .{ t.scale.x, t.scale.y };
            sprite.sprite_rotation = .{ t.rotation.x, t.rotation.y };
        }
    }
}

pub export fn AddTransform2DPos(id: u32, dx: f32, dy: f32) callconv(.c) void {
    const ctx = g_active_ctx;

    ctx.entity_transforms[id].position.x += dx;
    ctx.entity_transforms[id].position.y += dy;

    if (ctx.has_sprite.testBit(id)) {
        const t = ctx.entity_transforms[id];
        const sprites = GetEntitySprites(ctx, id);

        for (sprites) |*sprite| {
            sprite.sprite_pos = .{ t.position.x, t.position.y };
        }
    }
}

pub export fn AddPhysics(id: u32) callconv(.c) void {

    const ctx = g_active_ctx;
    ctx.static_dirty = true;
    ctx.physics.Set(id);
    ctx.static_sprite_draws.clearRetainingCapacity();

}

pub export fn RemovePhysics(id: u32) callconv(.c) void {
    const ctx = g_active_ctx;
    ctx.static_dirty = true;
    ctx.physics.Clear(id);
    ctx.static_sprite_draws.clearRetainingCapacity();
}
pub export fn SpawnSprite(desc: *const g_api.SpriteDesc, id: u32, atlas_id: u32) callconv(.c) void {

    const ctx = g_active_ctx;
    const slot_uv = atlas_mod.GetImageFromAtlas(@intCast(atlas_id), std.mem.span(desc.name), ctx.proj, ctx.allocator) catch |err| {
        std.log.err("GetImageFromAtlas failed: {}", .{err});
        return;
    };
    if (slot_uv != null) {
        ctx.allocator.free(slot_uv.?.name);
    }
    const transform = &ctx.entity_transforms[id];
    const sprite = helper.SpriteDraw{
        .entity = id,
        .sprite_pos = .{
            transform.position.x + desc.position.x, 
            transform.position.y + desc.position.y},
        .sprite_scale = .{
            transform.scale.x + desc.scale.x, 
            transform.scale.y + desc.scale.x},
        .sprite_rotation = .{transform.rotation.x, transform.rotation.y},
        .uv_min = slot_uv.?.uv_min,
        .uv_max = slot_uv.?.uv_max,
        .tint = .{desc.color.r, desc.color.g, desc.color.b, desc.color.a},
        .atlas_id = desc.atlas_id,
    };

    std.log.info("Spawning sprite for entity: {d}", .{id});

    if (!ctx.has_sprite.testBit(id)){
        ctx.has_sprite.Set(id);
    }

    const set = &ctx.sprite_components[id];

    if (set.count >= MAX_SPRITES_PER_ENTITY) {
        std.log.err("Too many sprites for entity {d}", .{id});
        return;
    }

    // First sprite for this entity: reserve a full block of MAX_SPRITES_PER_ENTITY slots
    if (set.count == 0) {
        set.start = @intCast(ctx.sprite_storage.items.len);
        const new_len = ctx.sprite_storage.items.len + MAX_SPRITES_PER_ENTITY;
        ctx.sprite_storage.resize(ctx.allocator, new_len) catch |err| {
            std.log.err("Failed to reserve sprite storage block for entity {d}: {}", .{id, err});
            return;
        };
        // Zero-init the reserved block so unoccupied slots are clean
        for (ctx.sprite_storage.items[set.start..new_len]) |*s| {
            s.* = std.mem.zeroes(helper.SpriteDraw);
        }
    }else{

        std.log.info("Offset at y: {d} \n \n", .{desc.position.y});
        std.log.info("Spawning Lock at y: {d} \n \n", .{sprite.sprite_pos[1]});
    }

    // Write directly into the pre-reserved slot
    ctx.sprite_storage.items[set.start + set.count] = sprite;
    set.count += 1;

    std.log.info("entity={d} start={d} count={d}", .{
        id, set.start, set.count,
    });
    std.log.info("sprite_storage len={d} cap={d}", .{
        ctx.sprite_storage.items.len,
        ctx.sprite_storage.capacity,
    });
}

pub export fn GetAllocator() callconv(.c) *anyopaque {
    return &g_active_ctx.allocator;
}

pub export fn SetSpriteWorldPos(entity: u32, index:u32, pos: Position2D) callconv(.c) void {
    _ = entity;
    _ = pos;
    _ = index;
}
pub export fn GetSpriteWorldPos(entity: u32, index:u32) Position2D{
    _ = entity;
    _ = index;
    return .{
        .x =0,
        .y = 0,
    };
}

pub export fn SetEntitySpritesWorldPos(entity: u32, pos: Position2D) callconv(.c) void {
    const ctx = g_active_ctx;

    if (!ctx.has_sprite.testBit(entity)) return;

    const set = ctx.sprite_components[entity];

    const start: usize = @intCast(set.start);
    const end: usize = start + @as(usize, @intCast(set.count));

    const sprites = ctx.sprite_storage.items[start..end];

    for (sprites) |*sprite| {
        sprite.sprite_pos = .{ pos.x, pos.y };
    }
}

pub export fn GetEntitySpritesWorldPos(entity: u32) callconv(.c) Position2D {
    const ctx = g_active_ctx;

    if (!ctx.has_sprite.testBit(entity)) {
        return .{ .x = 0, .y = 0 };
    }

    const set = ctx.sprite_components[entity];

    if (set.count == 0) {
        return .{ .x = 0, .y = 0 };
    }

    const sprite = ctx.sprite_storage.items[@intCast(set.start)];

    return .{
        .x = sprite.sprite_pos[0],
        .y = sprite.sprite_pos[1],
    };
}

pub export fn SetSpriteColor(entity: u32, id:u32 ,color: Color) void{
    _ = entity;
    _ = color;
    _ = id;
}

pub export fn GetSpriteColor(entity: u32,id: u32) Color {
    _ = entity;
    _ = id;
    return .{};

}

pub export fn SetEntitySpritesColor(entity: u32, color: Color) void{
    _ = entity;
    _ = color;
}

pub export fn GetEntitySpritesColor(entity: u32) Color {
    _ = entity;
    return .{};
}

pub export fn MoveCameraToWorldPosition(pos: Position2D, speed: f32) void {
    _ = pos;
    _ = speed;

}

pub export fn MoveCameraVertical(y: f32, speed: f32) void {
    _ = y;
    _ = speed;
}

pub export fn MoveCameraHorizontal(x: f32, speed: f32) void {
    _ = x;
    _ = speed;
}

pub export fn RemoveSprite(id: u32, placement: u32) callconv(.c) void {
    const ctx = g_active_ctx;

    if (!ctx.has_sprite.testBit(id)) return;

    const set = &ctx.sprite_components[id];

    if (placement >= set.count) return;

    const start: usize = @intCast(set.start);
    const idx: usize = start + @as(usize, placement);
    const end: usize = start + @as(usize, set.count);

    var storage = ctx.sprite_storage.items;

    // shift left
    var i = idx;
    while (i + 1 < end) : (i += 1) {
        storage[i] = storage[i + 1];
        storage[i].placement = @intCast(i - start);
    }

    set.count -= 1;

    // remove last element of the contiguous range
    _ = ctx.sprite_storage.orderedRemove(end - 1);

    if (set.count == 0) {
        ctx.has_sprite.Clear(id);
    }
}

pub fn GetEntitySprites(ctx: *ProjectContext, id: u32) []helper.SpriteDraw {
    const set = ctx.sprite_components[id];
    const start: usize = @intCast(set.start);
    const end: usize = start + @as(usize, @intCast(set.count));
    return ctx.sprite_storage.items[start..end];
}
