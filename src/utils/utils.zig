pub const math = @import("math.zig");
pub const algo = @import("algo.zig");
pub const notify = @import("notify.zig");
pub const atlas = @import("atlas.zig");
pub const two_bit = @import("two_bit.zig");
pub const time = @import("time.zig");
pub const camera = @import("camera.zig");
pub const mouse = @import("mouse.zig");
pub const scene_manager = @import("scene.zig");
pub const physics = @import("physics.zig");
const std = @import("std");
const Io = std.Io;

pub const Project = struct {
    name: []const u8,
    path: []const u8,
};

pub const ParsedProject = struct {
    parsed: std.json.Parsed(Project),
    buffer: []u8,

    pub fn deinit(self: *ParsedProject, allocator: std.mem.Allocator) void {
        self.parsed.deinit();
        allocator.free(self.buffer);
    }
};

pub fn LoadProject(io: Io, allocator: std.mem.Allocator) !ParsedProject{

    const file = try std.Io.Dir.cwd().openFile(io ,".active_project.json", .{});
    defer file.close(io);

    const file_size = try file.length(io);
    const bytes = try allocator.alloc(u8, file_size);

    _ = file.reader(io, bytes);

    const parsed = try std.json.parseFromSlice(
        Project,
        allocator,
        bytes,
        .{ .ignore_unknown_fields = true },
    );

    return .{
        .parsed = parsed,
        .buffer = bytes,
    };

}

pub fn WriteActiveProject(project: Project, allocator: std.mem.Allocator) !void {
    
    var file = try std.fs.cwd().createFile(".active_project.json", .{ .truncate = true });
    defer file.close();

    const json_text = try std.fmt.allocPrint(
        allocator,
        "{f}",
        .{ std.json.fmt(project, .{ .whitespace = .indent_2 }) },
    );
    defer allocator.free(json_text);

    try file.writeAll(json_text);

}
