const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dobby",
        .root_source_file = .{ .cwd_relative = "main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Enable linking with libc so we can use @cImport and system headers
    exe.linkLibC();

    // Link the X11 library
    exe.linkSystemLibrary("X11");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

