pub const math = @import("math.zig");
pub const algo = @import("algo.zig");
pub const notify = @import("notify.zig");
pub const atlas = @import("atlas.zig");
pub const two_bit = @import("two_bit.zig");
const std = @import("std");

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

pub fn LoadProject(allocator: std.mem.Allocator) !ParsedProject{

    const file = try std.fs.cwd().openFile(".active_project.json", .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const bytes = try allocator.alloc(u8, file_size);

    _ = try file.readAll(bytes);

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
