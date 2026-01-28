const std = @import("std");
const zigimg = @import("zigimg");
const utils = @import("utils");
const notify = utils.notify;
const atlas_mod = utils.atlas;

//{
//  "version": 1,
//  "atlases": [
//    { "id": 0, "path": "atlases/opaque_0.ktx2", "rev": 12 },
//    { "id": 1, "path": "atlases/ui_0.ktx2",      "rev": 3 }
//  ]
//}
const DIR_MASK =
    std.linux.IN_CREATE |
    std.linux.IN_DELETE |
    std.linux.IN_MOVED_FROM |
    std.linux.IN_MOVED_TO |
    std.linux.IN_DELETE_SELF |
    std.linux.IN_CLOSE_WRITE;


const CookingPacket = struct {
    parent_dir : []u8,
    file_path: []u8,
};

pub fn sleepMs(ms: u64) void {
    const ns = ms * std.time.ns_per_ms;
    std.posix.nanosleep(ns, 0);
}

const FsEvent = enum {
    DirCreated,
    FileCreated,
    FileDeleted,
    FileWritten,
   // FileMovedIn,
    FileMovedOut,
    Ignore,
};


pub const Cooker = struct {

    pub fn CookShaders(self: *Cooker) void {
        _ = self;
    }

    // TODO: Make an Atlas from PNG files 
    pub fn CookTextures(
        self: *Cooker, 
        cooking_packet: CookingPacket,
        new_atlas: bool,
        allocator: std.mem.Allocator) !void {
        
        _ = self;
        var parsed = try atlas_mod.ReadManifest(allocator);
        defer parsed.deinit(allocator);

        var maybe_id: ?usize = null;

        for (parsed.parsed.value.atlases) |atl| {
            if (std.mem.eql(u8, atl.from_path, cooking_packet.parent_dir)) {
                maybe_id = atl.id;
                //break;
            }
        }

        var id = if (maybe_id) |found_id|
            found_id
        else
            parsed.parsed.value.atlases.len;

        if (new_atlas) {
            id = parsed.parsed.value.atlases.len; 
        }

       var atlas = atlas_mod.Atlas{
           .width = 2048,
           .height = 2048,
           .pixels = try allocator.alloc(u8, 2048 * 2048 * 4),
        };
       defer allocator.free(atlas.pixels.?);

       @memset(atlas.pixels.?, 0);

       var dir = try std.fs.cwd().openDir(cooking_packet.parent_dir, .{ .iterate = true });
       defer dir.close();

       var it = dir.iterate();
       while (try it.next()) |entry| {
            if (entry.kind != .file) continue;

            if (std.mem.endsWith(u8, entry.name, ".png")) {
               std.log.info("Found PNG: {s}/{s}", .{ cooking_packet.parent_dir, entry.name });

                const full_png_path = try std.fs.path.join(
                    allocator,
                    &.{ cooking_packet.parent_dir, entry.name },
                );
                defer allocator.free(full_png_path);

                try AddImageToAtlas(&atlas, allocator, full_png_path);

                std.log.info("{s} added to atlas", .{ entry.name });
            }
       }

       // Converting Atlas o PNG first

        const pixels = atlas.pixels orelse
            return error.NoPixels;

        var img = try zigimg.Image.create(
            allocator,
            atlas.width,
            atlas.height,
            .rgba32,
        );
        defer img.deinit(allocator);

       const dst = std.mem.sliceAsBytes(img.pixels.rgba32);
       @memcpy(dst, pixels);

       const write_buffer = try allocator.alloc(u8, 1024 * 1024); // 1 MB scratch (safe)
       defer allocator.free(write_buffer);
    
       // KTX2 conversion
        std.log.info("Starting the creation of ktx2 atlas file", .{});

        const png_path = try std.fmt.allocPrint(
            allocator,
            "zig-out/tmp/atlas_{d}.png",
            .{ id },
        );
        defer allocator.free(png_path);

       try img.writeToFilePath(allocator , png_path, write_buffer, .{ .png = .{} });

       const ktx_path = try std.fmt.allocPrint(
            allocator,
            "assets/cooked/atlases/atlas_{d}.ktx2",
            .{ id },
        );
        defer allocator.free(ktx_path);

        var argv = [_][]const u8{
            "toktx",
            "--assign_oetf", "srgb",
            "--bcmp",
            "--genmipmap",
            ktx_path,
            png_path,
        };

        var child = std.process.Child.init(&argv, allocator);
        child.stdin_behavior = .Inherit;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        const term = try child.spawnAndWait();

       switch (term) {
            .Exited => |code| if (code != 0) return error.ToktxFailed,
            else => return error.ToktxCrashed,
        } 
        std.log.info("Finished adding atlas to atlas file", .{});

        std.log.info("Updating texture manifest", .{});

        try atlas_mod.AddAtlasToManifest(
            allocator,
            &parsed.parsed.value,
            ktx_path,
            cooking_packet.parent_dir,
            id,
        );

         try atlas_mod.WriteManifest(parsed.parsed.value, allocator);

         std.log.info("Manifest is updated", .{});

    }
};


pub fn AddImageToAtlas(
    atlas: *atlas_mod.Atlas,
    allocator: std.mem.Allocator,
    path: []const u8,
) !void {

    //_ = atlas;
   // _ = allocator;
    //_ = path;

    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();

    const read_buf = try allocator.alloc(u8, file_size);
    defer allocator.free(read_buf);

    _ = try file.readAll(read_buf);

    //// ---- load image ----
    var img = try zigimg.Image.fromFilePath(
        allocator,
        path,
        read_buf,
    );
    defer img.deinit(allocator);

    //// Force RGBA8 (4 × u8 = 32 bits)
    try img.convert(allocator, .rgba32);

    const img_w: u32 = @intCast(img.width);
    const img_h: u32 = @intCast(img.height);

    //_ = img_w;
    //_ = img_h;

    std.log.info("atlas cursor + imh_w = {d} and atlas width = {d}", .{atlas.cursor_x + img_w, atlas.width});
    //// Simple row-based packing
    if (atlas.cursor_x + img_w > atlas.width) {
        std.log.info("Row packing", .{});
        atlas.cursor_x = 0;
        atlas.cursor_y += atlas.row_h;
        atlas.row_h = 0;
    }

    std.log.info("atlas cursor + imh_h = {d} and atlas height = {d}", .{atlas.cursor_y + img_h, atlas.height});
    if (atlas.cursor_y + img_h > atlas.height){
    //   std.log.info("atlas cursor + imh_h = {d} and atlas height = {d}", .{atlas.cursor_y + img_h, atlas.height});
         return error.AtlasFull;
    }

    const src_pixels = img.pixels.rgba32;
    const src_bytes = std.mem.sliceAsBytes(src_pixels);

   // //// Copy rows
    for (0..img_h) |row| {
        const dst = ((atlas.cursor_y + row) * atlas.width + atlas.cursor_x) * 4;
        const src = row * img_w * 4;

        @memcpy(
            atlas.pixels.?[dst .. dst + img_w * 4],
            src_bytes[src .. src + img_w * 4],
        );
    }

    atlas.row_h = @max(atlas.row_h, img_h);
    atlas.cursor_x += img_w;
}

// ********************************* TEXTURES ****************************************
// GOAL #1: Traverse PNG files in textures (Update if a newly added PNG file is there)
// GOAL #2: Place PNG files into a atlas (if there is one)
// GOAL #3: Convert Atlas to KTX2
// GOAL #4: Replace or add Atlas into the cooked textures folder.
//
//
// ********************************* SHADERS *****************************************

pub fn main() !void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.log.info("asset cooker has started", .{});

    var texture_notifier = try notify.Inotify.init("assets/src/textures", allocator);
    ////var shader_notifier = try notify.Inotify.init("assets/src/shaders", allocator);
    defer texture_notifier.deinit(allocator);
    //defer shader_notifier.deinit(allocator);

    var cooker = Cooker{};
    var file: std.fs.File = undefined;

     file = std.fs.cwd().openFile("assets/cooked/atlases/manifest.json", .{}) catch |err| switch (err){
        error.FileNotFound => blk: {
            try std.fs.cwd().makePath(
                std.fs.path.dirname("assets/cooked/atlases/manifest.json").?
            );

            var new_file = try std.fs.cwd().createFile(
                "assets/cooked/atlases/manifest.json",
                .{ .truncate = true },
            );

            const json_text =
                \\{
                \\  "version": 1,
                \\  "atlases": []
                \\}
            ;

            try new_file.writeAll(json_text);
            break :blk new_file; // 🔑 return fs.File
        },
        else => return err,

    };


    defer file.close();

    var dir = try std.fs.cwd().openDir("assets/src/textures", .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();

    while(try it.next()) |entry| {

        if (entry.kind != .directory) continue;

        if (std.mem.eql(u8, entry.name, ".") or
            std.mem.eql(u8, entry.name, ".."))
            continue;

        const full_path = try std.fs.path.join(
            allocator,
            &.{ "assets/src/textures", entry.name },
        );

        const full_path_z = try allocator.dupeZ(u8, full_path);
        defer allocator.free(full_path_z);

        _ = try texture_notifier.AddWatcher(full_path_z);

        try texture_notifier.wd_paths.append(allocator, full_path);

    }
   
    while(true) {

        try texture_notifier.wait(300);

        const text_alert_bytes = try texture_notifier.poll();
        if (text_alert_bytes > 0) {

            var offset: usize = 0;
            while (offset < text_alert_bytes) {

                const ev: *std.os.linux.inotify_event = @ptrCast(@alignCast(&texture_notifier.buf[offset]));

                const is_dir = (ev.mask & std.os.linux.IN.ISDIR) != 0;

                switch (ClassifyEvent(ev, is_dir)) {

                    .DirCreated => {
                        if (ev.wd < 0) break;

                        const parent = texture_notifier.wd_paths.items[@intCast(ev.wd)] orelse break;

                        const name_ptr = @as([*]const u8, @ptrCast(ev)) + @sizeOf(std.os.linux.inotify_event);

                        const dir_name = std.mem.sliceTo(name_ptr[0..ev.len], 0);

                        const full_path = try std.fs.path.join(allocator, &.{ parent, dir_name });
                        defer allocator.free(full_path);

                        const full_path_z = try allocator.dupeZ(u8, full_path);
                        defer allocator.free(full_path_z);

                        const wd = try texture_notifier.AddWatcher(full_path_z);

                        const old_len = texture_notifier.wd_paths.items.len;
                        if (wd >= old_len) {

                            try texture_notifier.wd_paths.resize(
                                allocator,
                                @as(u32, @intCast(wd)) + 1,
                            );

                            for (old_len..texture_notifier.wd_paths.items.len) |i|
                                texture_notifier.wd_paths.items[i] = null;
                        }

                        const wd_index: u32 = @intCast(wd);
                        if (texture_notifier.wd_paths.items[wd_index]) |old|
                            allocator.free(old);

                        texture_notifier.wd_paths.items[wd_index] = try allocator.dupe(u8, full_path);

                        std.log.info("Directory added: {s}", .{full_path});
                    },

                    .FileCreated, .FileWritten => {

                        const cooking_packet = try FileUpdated( allocator, &texture_notifier, ev, );
                        defer allocator.free(cooking_packet.file_path);

                        std.log.info("File written: {s}", .{cooking_packet.file_path});
                        try cooker.CookTextures(cooking_packet, false ,allocator);
                    },

                    .FileDeleted => {

                        const cooking_packet = try FileUpdated(allocator, &texture_notifier, ev,);
                        defer allocator.free(cooking_packet.file_path);

                        std.log.info("File deleted: {s}", .{cooking_packet.file_path});
                    },

                    .FileMovedOut => {

                        const cooking_packet = try FileUpdated( allocator, &texture_notifier, ev,);
                        defer allocator.free(cooking_packet.file_path);

                        std.log.info("File moved out: {s}", .{cooking_packet.file_path});
                    },

                    .Ignore => {},

                }

                offset += @sizeOf(std.os.linux.inotify_event) + ev.len;
            }

        }
    }

}


fn FileUpdated(
    allocator: std.mem.Allocator,
    texture_notifier: *notify.Inotify,
    ev: *const std.os.linux.inotify_event,
) !CookingPacket {
    const wd_index: usize = @intCast(ev.wd);

    const parent = texture_notifier.wd_paths.items[wd_index] orelse {
        // Should never happen if watcher graph is correct
        return error.InvalidWatchDescriptor;
    };

    const name_ptr =
        @as([*]const u8, @ptrCast(ev)) +
        @sizeOf(std.os.linux.inotify_event);

    const file_name =
        std.mem.sliceTo(name_ptr[0..ev.len], 0);

    const file_path = try std.fs.path.join(allocator, &.{ parent, file_name });

    return .{.parent_dir = parent, .file_path = file_path }; 
}




fn ClassifyEvent(ev: *const std.os.linux.inotify_event, is_dir: bool) FsEvent {
    if (is_dir and (ev.mask & std.os.linux.IN.CREATE) != 0)
        return .DirCreated;

   // if (!is_dir and (ev.mask & std.os.linux.IN.CREATE) != 0)
       // return .FileCreated;

    if (!is_dir and (ev.mask & std.os.linux.IN.DELETE) != 0)
        return .FileDeleted;

    if (!is_dir and (ev.mask & std.os.linux.IN.CLOSE_WRITE) != 0)
        return .FileWritten;

    //if (!is_dir and (ev.mask & std.os.linux.IN.MOVED_TO) != 0)
       // return .FileMovedIn;

    if (!is_dir and (ev.mask & std.os.linux.IN.MOVED_FROM) != 0)
        return .FileMovedOut;

    return .Ignore;
}




