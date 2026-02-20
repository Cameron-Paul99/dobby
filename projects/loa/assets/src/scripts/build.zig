const std = @import("std");

pub fn build(b: *std.Build) void {
    //const project_bin_dir =
      //  b.path("zig-out/bin");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const game = b.addLibrary(.{
        .name = "loa_game",
        .linkage = .dynamic,
        .root_module = b.addModule(
            "loa_game",
            .{
            .root_source_file = b.path("game.zig"),
            .target = target,
            .optimize = optimize,
        }), 
    });

    const game_api_mod = b.createModule(.{
        .root_source_file = b.path("../../../../../src/game_api/game_api.zig"),
        .target = target,
        .optimize = optimize,
    });

    game.root_module.addImport("game_api", game_api_mod);

    b.installArtifact(game);
    
}
