const math = @import("math.zig");
const std = @import("std");
const Vec2 = math.Vec2;
const Mat4 = math.Mat4;
const Self = @This();

    pos: Vec2 = Vec2.ZERO,
    zoom: f32 = 1.0,
    view_proj: Mat4 = Mat4.IDENTITY,

    pub fn init(h: f32, w: f32) Self{
        var pos = Vec2.Make(w * 0.5, h * 0.5);
        pos = Vec2.Div(pos, 1.0);
        return .{  
            .pos = pos,
        };
    }

    pub fn UpdateViewProj(
        self: *Self, 
        screen_w: f32, 
        screen_h: f32) void { 

        const half_w = ( screen_w * 0.5 ) / self.zoom; 
        const half_h = ( screen_h * 0.5 ) / self.zoom; 

        const left = self.pos.x - half_w; 
        const right = self.pos.x + half_w; 

        const bottom = self.pos.y - half_h; 
        const top = self.pos.y + half_h; 
        self.view_proj = math.Ortho(left, right, bottom, top); 
    }

    pub fn UpdateCameraAttributes(
        self: *Self,
        zoom: f32,
        drag: Vec2,
    ) void{

        self.zoom = zoom;
        self.pos = Vec2.Add(
            self.pos, 
            Vec2.Div(drag, zoom)
        );

       // std.log.info("camera position {d:.3}, {d:.3}",.{self.pos.x, self.pos.y});

    }



