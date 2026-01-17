const std = @import("std");
const utils = @import("utils");
const engine = @import("engine");
const core_mod = engine.core;
const swapchain_mod = engine.swapchain;
const render = engine.renderer;
const helper = engine.helper;
const text = engine.textures;
const c = engine.c;
const print = std.debug.print;
const sdl = engine.sdl;
const math = utils.math;


pub const Sprite = struct {
    image: helper.AllocatedImage = .{},
    uv_min: math.Vec2 = .{.x = 0.0, .y = 0.0},
    uv_max: math.Vec2 = .{.x = 1.1, .y = 1.1},
    size: math.Vec2,
};

pub const Atlas = struct {
    width: u32,
    height: u32,
    pixels: []u8,
    cursor_x: u32 = 0,
    cursor_y: u32 = 0,
    row_h: u32 = 0,
};

pub fn main() !void {
    
    // Window Creation
    var game_window = try sdl.Window.init(800, 600);
    defer game_window.deinit();
    
    // Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Core Creation
    var core = try core_mod.Core.init(true, allocator, &game_window);
    defer core.deinit(allocator);
    
    // Swapchain creation
    var sc = try swapchain_mod.Swapchain.init(allocator, &core , &game_window, .{.vsync = false}, null);
    defer sc.deinit(&core, allocator, core.alloc_cb);
    
    // Renderer creation
    var renderer = try render.Renderer.init(allocator, &core, &sc);
    defer renderer.deinit(allocator, &core);

    var sprite_draws =  try std.ArrayList(helper.SpriteDraw).initCapacity(allocator, 0);
    defer sprite_draws.deinit(allocator);

    while (!game_window.should_close){
        try renderer.DrawFrame(&core, &sc, &game_window, allocator, sprite_draws.items);
        game_window.pollEvents(&renderer);
    }

}

pub fn PushSprite(sprites: *std.ArrayList(helper.SpriteDraw), sprite: helper.SpriteDraw) !void{
    try sprites.append(sprite);
}
