const std = @import("std");
const print = std.debug.print;
const sdl = @import("sdl.zig");
const core_mod = @import("core.zig");
const swapchain_mod = @import("swapchain.zig");
const render = @import("render.zig");
const helper = @import("helper.zig");

pub fn main() !void {
    
    // Window Creation
    var window = try sdl.Window.init(800, 600);
    defer window.deinit();
    
    // Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Core Creation
    var core = try core_mod.Core.init(true, allocator, &window);
    defer core.deinit(allocator);
    
    // Swapchain creation
    var sc = try swapchain_mod.Swapchain.init(
        allocator, 
        core.alloc_cb,
        800,
        600,
        .{
            .device = core.device.handle, 
            .physical_device = core.physical_device.handle, 
            .surface = core.physical_device.surface,
            .graphics_qfi = core.physical_device.graphics_queue_family,
            .present_qfi = core.physical_device.present_queue_family,
        },
        .{.vsync = false, .triple_buffer = false},
        null
    );
    defer sc.deinit(allocator, core.device.handle ,core.alloc_cb);

    // Render pass creation
    var render_pass = try swapchain_mod.CreateRenderPass(&sc, core.device.handle, core.alloc_cb);
    defer helper.deinitRenderPass(core.device.handle, &render_pass, core.alloc_cb);
    
    // Pipeline Material Creation
    var material_system = try helper.MaterialSystem.init(allocator);
    defer material_system.deinit();
    defer material_system.deinitGpu(core.device.handle, core.alloc_cb);
    
    // Pipeline Creation
    try render.CreatePipelines(core.device.handle, &sc , &material_system, render_pass, core.alloc_cb);


    while (!window.should_close){
        window.pollEvents();
        std.Thread.sleep(16 * std.time.ns_per_ms);
    }

}
