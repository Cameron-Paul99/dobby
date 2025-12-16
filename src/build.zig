const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dobby",
        .root_module = b.addModule(
            "dobby", 
            .{
                .root_source_file = b.path("main.zig"),
                .target = target,
                .optimize = optimize,
        }),
    });


    const vk_lib_name = if (target.result.os.tag == .windows) "vulkan-1" else "vulkan";
    
    exe.linkSystemLibrary("SDL3");

    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary(vk_lib_name);
    exe.addIncludePath(.{ .cwd_relative = "thirdparty/sdl3/include" });

    exe.linkLibC();

    exe.addIncludePath(.{ .cwd_relative = "/usr/include/vulkan/vulkan.h" });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

