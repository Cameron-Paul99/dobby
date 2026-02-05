const std = @import("std");
const utils = @import("utils");



 pub fn main() !void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdin_buffer: [512]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    var stdout_buffer : [512]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;



    var file: std.fs.File = undefined;

     file = std.fs.cwd().openFile(".active_project.json", .{}) catch |err| switch (err){
        error.FileNotFound => blk: {

            const new_file = try std.fs.cwd().createFile(
                ".active_project.json",
                .{ .truncate = true },
            );

            break :blk new_file;
        },
        else => return err,

    };


    defer file.close();

    var proj_list = try std.ArrayList([]const u8).initCapacity(allocator, 0);
    defer proj_list.deinit(allocator);

    try stdout.print("\n", .{});
    const welcoming = 
        \\Hello
        \\Welcome to Dobby Engine
        \\Designed by Cameron Paul
    ;

    try stdout.print("{s}\n", .{welcoming});

    try stdout.print("\n", .{});
    var project_selected = false;

    var dir = try std.fs.cwd().openDir("projects", .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    var proj_count: u32 = 0;

    try stdout.print("Here are your projects\n", .{});

    try stdout.print("\n", .{});

    while(try it.next()) |entry| {

        if (entry.kind != .directory) continue;

        try stdout.print("{d}:{s} ", .{proj_count, entry.name});
        try proj_list.append(allocator, entry.name);
        proj_count += 1;

    }
    try stdout.print("\n", .{});
    try stdout.print("\n", .{});
    try stdout.print("Type in number associated with the project or create a new project by typing in 'new'. Type enter with your choice\n", .{});

    var project_id: u32 = 0;
    var existing_proj_name: ?[]const u8 = null;
   // _ = project_id;
    var new_proj = false;

    try stdout.flush();
    while(!project_selected){

        const line = try stdin.takeDelimiterExclusive('\n'); 
        _ = try stdin.discardDelimiterInclusive('\n');

        if (std.mem.eql(u8, line, "new")) {
            try stdout.print("Creating new project...\n", .{});
            project_selected = true;
            new_proj = true;
            try stdout.flush();
            break;
        }
        project_id = std.fmt.parseInt(u32, line, 10) catch {
            try stdout.print("Invalid input: '{s}'\n", .{line});
            try stdout.flush();
            continue;
        };
        if (project_id >= 0 and project_id <= proj_count){
            try stdout.print("Selected project #{d}\n", .{project_id});
            existing_proj_name = proj_list.items[project_id];
            try stdout.flush();
            break;
        }
    }

    try stdout.flush();



    if (new_proj){

        try stdout.print("Name the new project\n", .{});
        try stdout.flush();
        
        while(true){
            const line = try stdin.takeDelimiterExclusive('\n'); 
            _ = try stdin.discardDelimiterInclusive('\n');
            if (std.mem.eql(u8, line, "")) {
                try stdout.print("Invalid input\n", .{});
                try stdout.flush();
                continue;
            }
            const path = try std.fmt.allocPrint(
                allocator,
                "projects/{s}",
                .{line},
            );
            defer allocator.free(path);

            const asset_cooked_path = try std.fmt.allocPrint(
                allocator,
                "projects/{s}/assets/cooked/atlases",
                .{line},
            );
            defer allocator.free(asset_cooked_path);

            const asset_cooked_shaders_path = try std.fmt.allocPrint(
                allocator,
                "projects/{s}/assets/cooked/shaders",
                .{line},
            );
            defer allocator.free(asset_cooked_shaders_path);

            const asset_src_texture_path = try std.fmt.allocPrint(
                allocator,
                "projects/{s}/assets/src/textures",
                .{line},
            );
            defer allocator.free(asset_src_texture_path);

            const asset_src_shaders_path = try std.fmt.allocPrint(
                allocator,
                "projects/{s}/assets/src/shaders",
                .{line},
            );
            defer allocator.free(asset_src_shaders_path);

            try std.fs.cwd().makePath(path);
            try std.fs.cwd().makePath(asset_cooked_path);
            try std.fs.cwd().makePath(asset_cooked_shaders_path);
            try std.fs.cwd().makePath(asset_src_texture_path);
            try std.fs.cwd().makePath(asset_src_shaders_path);

            const name = try std.fmt.allocPrint(
                allocator,
                "{s}",
                .{line},
            );
            defer allocator.free(name);

            const proj = utils.Project {
                .name = try allocator.dupe(u8, name),
                .path = try allocator.dupe(u8, path),
            };
            defer allocator.free(proj.name);
            defer allocator.free(proj.path);

            try utils.WriteActiveProject(proj, allocator);

            break;
        }


    }else if (existing_proj_name) |name| {

            const path = try std.fmt.allocPrint(
                allocator,
                "projects/{s}",
                .{name},
            );
            defer allocator.free(path);

            const proj = utils.Project {
                .name = try allocator.dupe(u8, name),
                .path = try allocator.dupe(u8, path),
            };
            defer allocator.free(proj.name);
            defer allocator.free(proj.path);

            try utils.WriteActiveProject(proj, allocator);

    }

//    var child = std.process.Child.init(
//        &[_][]const u8{
//            "sh",
//            "-c",
//            "./scripts/run_all.sh",
//        },
//        allocator,
//    );
//
//    child.stdin_behavior = .Inherit;
//    child.stdout_behavior = .Inherit;
//    child.stderr_behavior = .Inherit;
//
//    const term = try child.spawnAndWait();
//    
//    switch (term) {
//        .Exited => |code| {
//            std.debug.print("Script exited with code {}\n", .{code});
//        },
//        else => {
//            std.debug.print("Script crashed\n", .{});
//        },
//    }

}
