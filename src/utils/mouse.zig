const Self = @This();
const math = @import("math.zig");
const Camera = @import("camera.zig");
const Vec2 = math.Vec2;

    world_pos: Vec2 = Vec2.ZERO,
    sdl_pos: Vec2 = Vec2.ZERO,

    pub fn Update(
            self: *Self,
            mouse_pos: Vec2,
            cam: *const Camera,
            screen_w: f32,
            screen_h: f32,
        ) void {
        
        self.sdl_pos = mouse_pos;

        const half_w = (screen_w * 0.5) / cam.zoom;
        const half_h = (screen_h * 0.5) / cam.zoom;

        const left   = cam.pos.x - half_w;
        const bottom = cam.pos.y - half_h;

        self.world_pos = .{
            .x = left + (self.sdl_pos.x / cam.zoom),
            .y = bottom + (self.sdl_pos.y / cam.zoom),
        };
    }

