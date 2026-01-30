const std = @import("std");
const log = std.log;

const DIR_WATCH_MASK: u32 =
    std.os.linux.IN.CLOSE_WRITE |
    std.os.linux.IN.MODIFY |
    std.os.linux.IN.MOVED_TO |
    std.os.linux.IN.MOVED_FROM |
    std.os.linux.IN.DELETE |
    std.os.linux.IN.CREATE;
   // linux.IN.ONLYDIR;

pub const Inotify = struct {

    fd: i32 = 0,
    buf: [4096]u8 = undefined,
    wd_paths: std.ArrayList(?[]u8),

    pub fn init(path: [:0]const u8, allocator: std.mem.Allocator) !Inotify {
        const fd = std.os.linux.inotify_init1(
            std.os.linux.IN.NONBLOCK,
        );
        if (fd < 0) return error.InotifyInitFailed;

        const wd = std.os.linux.inotify_add_watch(
            @intCast(fd),
            path,
            DIR_WATCH_MASK,
        );
        if (wd < 0) return error.InotifyWatchFailed;

        var wd_paths = try std.ArrayList(?[]u8).initCapacity(allocator, 0);

        // Ensure index exists
        if (wd >= wd_paths.items.len) {
            const old_len = wd_paths.items.len;
            try wd_paths.resize(allocator , @as(u32 , @intCast(wd)) + 1);
            for (old_len..wd_paths.items.len) |i| {
                wd_paths.items[i] = null;
            }

        }

        // Store the root path
        wd_paths.items[@intCast(wd)] = try allocator.dupe(u8, path);

        log.info("Init notifier root watch: wd={d}, path={s}", .{ wd, path });

        return .{
            .fd = @intCast(fd),
            .wd_paths = wd_paths,
        };
    }
    

    pub fn poll(self: *Inotify) !usize {

        const bytes = std.posix.read(self.fd, &self.buf) catch |err| switch (err) {
            error.WouldBlock => return 0,
            else => return err,
        };

        return bytes;
    }

    pub fn AddWatcher(self: *Inotify, path: [:0]const u8,) !i32 {

        const wd = std.os.linux.inotify_add_watch(
            self.fd,
            path,
            DIR_WATCH_MASK,
        );
        if (wd < 0) return error.InotifyWatchFailed;
        log.info("Init notifier root watch: wd={d}, path={s}", .{ wd, path });
        return @intCast(wd);
        
    }


    pub fn wait(self: *Inotify, timeout_ms: i32) !void {
        var pfds = [_]std.posix.pollfd{
            .{
                .fd = self.fd,
                .events = std.posix.POLL.IN,
                .revents = 0,
            },
        };

        _ = try std.posix.poll(pfds[0..], timeout_ms);
    }

    pub fn deinit(self: *Inotify, allocator: std.mem.Allocator) void {
        for (self.wd_paths.items) |maybe_path| {
            if (maybe_path) |p| allocator.free(p);
        }
        self.wd_paths.deinit(allocator);
        _ = std.posix.close(self.fd);
    }

};
