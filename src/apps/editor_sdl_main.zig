const std = @import("std");
const print = std.debug.print;
const sdl = @import("sdl.zig");
const core_mod = @import("../renderer/core.zig");
const swapchain_mod = @import("../renderer/swapchain.zig");
const render = @import("../renderer/render.zig");
const helper = @import("../renderer/helper.zig");
const text = @import("../renderer/textures.zig");

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

    while (!game_window.should_close){
        try renderer.DrawFrame(&core, &sc, &game_window, allocator);
        game_window.pollEvents(&renderer);
    }

}
