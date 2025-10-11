const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dobby",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"), // or "src/main.zig"
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // Enable linking with libc so we can use @cImport and system headers
    exe.linkLibC();

    // Link the X11 library
    exe.linkSystemLibrary("X11");

    //vulkan library
    exe.linkSystemLibrary("vulkan");

    exe.linkSystemLibrary("SDL3");

//exe.addCSourceFile(.{ .file = b.path("src/vk_mem_alloc.cpp"), .flags = &.{ "" } });
 exe.addIncludePath(b.path("thirdparty/imgui/"));



    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

