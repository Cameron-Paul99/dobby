const std = @import("std");
const editor_sdl = @import("editor_sdl_main.zig");
const utils = @import("utils");
const g_api = @import("game_api");
const two_bit = utils.two_bit;
const Transform2D = g_api.Transform2D;
const Physics = utils.physics;
var child: ?std.process.Child = undefined;

fn writeLine(
    writer: anytype,
    key: []const u8,
    comptime fmt: []const u8,
    args: anytype,
) !void {
    try writer.print("{s:<18}: ", .{key});
    try writer.print(fmt, args);
    try writer.writeByte('\n');
}

var ui_buffer: [8192]u8 = undefined;
var ui_stream = std.io.fixedBufferStream(&ui_buffer);

pub fn BeginUI() void {
    ui_stream.reset();
}

pub fn main() !void {
    var file = std.fs.cwd().openFile("debug.txt", .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => blk: {
            var new_file = try std.fs.cwd().createFile("debug.txt", .{
                .read = true,
                .truncate = true,
            });
            try new_file.writeAll("Editor\n");
            break :blk new_file;
        },
        else => return err,
    };
    defer file.close();

    child = std.process.Child.init(
        &[_][]const u8{
            "ghostty",
            "-e",
            "watch",
            "-n",
            "0.1",
            "cat",
            "debug.txt",
        },
        std.heap.page_allocator,
    ); 

    child.?.stdin_behavior = .Inherit;
    child.?.stdout_behavior = .Inherit;
    child.?.stderr_behavior = .Inherit;

    try child.?.spawn();
    try file.setEndPos(0);
    try file.seekTo(0);

}

pub fn UpdateMouseUI(x: f32, y: f32) !void {
    const writer = ui_stream.writer();
    try writer.writeAll("=== MOUSE =================================================\n");
    try writeLine(writer, "world_pos", "(x: {d:.2}, y: {d:.2})", .{ x, y });
    try writer.writeByte('\n');
}

pub fn UpdateCameraUI(x: f32, y: f32, zoom: f32) !void {
    const writer = ui_stream.writer();
    try writer.writeAll("=== CAMERA ================================================\n");
    try writeLine(writer, "camera_loc", "(x: {d:.2}, y: {d:.2}, zoom: {d:.2})", .{ x, y, zoom });
    try writer.writeByte('\n');
}

pub fn FlushUI() !void {
    var file = try std.fs.cwd().openFile("debug.txt", .{ .mode = .read_write });
    defer file.close();

    try file.setEndPos(0);
    try file.seekTo(0);
    try file.writeAll(ui_stream.getWritten());
    try file.sync();
}

pub fn UpdateEngineUI(
    fps: f64, 
    editor_time: f64,
    game_time: f64, 
    game_mode: bool) !void {
    
    // FPS
    const writer = ui_stream.writer();
    try writer.writeAll("=== Engine ================================================\n");
    try writeLine(writer, "FPS", "({d:.2})", .{ fps });
    try writeLine(writer, "Frame", "({d:.2} ms)", .{1000.0 / fps});
    try writeLine(writer, "Editor Time", "({d:.2})", .{ editor_time });
    try writeLine(writer, "Game Time", "({d:.2})", .{ game_time });
    try writeLine(writer, "Mode", "({s})", .{
        if (game_mode) "GAME" else "EDITOR"
    }); 
    try writer.writeByte('\n');
}

pub fn Selected(
    entity: u32,
    physics: *Physics,
    has_physics: *two_bit,
    sprite: *two_bit,
    transform: Transform2D,
    ) !void{
    const writer = ui_stream.writer();
    try writer.writeAll("=== Selected Entity ================================================\n");
    try writeLine(writer, "Entity", "({d})", .{ entity });
    try writeLine(writer, "Position", "(x: {d:.2}, y: {d:.2})", .{transform.position.x, transform.position.y});
    try writeLine(writer, "Scale", "(x: {d:.2}, y: {d:.2})", .{transform.scale.x, transform.scale.y});
    try writeLine(writer, "Rotation", "(x: {d:.2}, y: {d:.2})", .{transform.rotation.x, transform.rotation.y});
    try writeLine(writer, "Physics", "({s})", .{ 
        if (has_physics.testBit(entity)) "ENABLED" else "DISABLED" 
    });  
    
    try writeLine(writer, "Gravity", "({s})", .{ 
        if (physics.gravity_bits.testBit(entity)) "ENABLED" else "DISABLED" 
    }); 

    try writeLine(writer, "Has Sprite", "({s})", .{ 
        if (sprite.testBit(entity)) "Yes" else "No" 
    }); 

    try writer.writeByte('\n');

}

  




pub fn GameMetricsUI() void {
    // Time
    // Arrays
    // Memory

}

pub fn EditorMetricsUI() void {
    // Time
    // Selection
    // Memory

}




//pub fn UpdateCameraUI() !void {
//    if (child == null) return;
//
//    var buf: [4096]u8 = undefined;
//    var stream = std.io.fixedBufferStream(&buf);
//    const writer = stream.writer();
//
//    var file = try std.fs.cwd().openFile("debug.txt", .{ .mode = .read_write });
//    defer file.close();
//
//    try file.seekFromEnd(0);
//
//    try writer.writeAll("\n=== CAMERA ================================================\n\n");
//    try writeLine(writer, "testing", "{d:.2}", .{16.67});
//    try writeLine(writer, "test", "[{}, {}]", .{ 1920, 1080 });
//
//    try file.writeAll(stream.getWritten());
//    try file.sync();
//}

