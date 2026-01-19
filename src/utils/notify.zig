const std = @import("std");
const log = std.log;

pub const Inotify = struct {

    fd: i32 = 0,

    pub fn init(path: [:0]const u8) !Inotify {

        const fd = std.os.linux.inotify_init1(
            std.os.linux.IN.NONBLOCK,
        );
        if (fd < 0) return error.InotifyInitFailed;

        const wd = std.os.linux.inotify_add_watch(
            @intCast(fd),
            path,
            std.os.linux.IN.CLOSE_WRITE |
            std.os.linux.IN.MODIFY |
            std.os.linux.IN.MOVED_TO |
            std.os.linux.IN.MOVED_FROM |
            std.os.linux.IN.DELETE |
            std.os.linux.IN.CREATE |
            std.os.linux.IN.ONLYDIR,
        );
        if (wd < 0) return error.InotifyWatchFailed;

        log.info("Initing Notifier", .{});

        return .{ .fd = @intCast(fd) };

    }

    pub fn poll(self: *Inotify, flag: *bool) void {
        var buf: [4096]u8 = undefined;
       // log.info("Notifing", .{});
        while (true) {
            const bytes = std.posix.read(self.fd, &buf) catch |err| switch (err) {
                error.WouldBlock => return,
                else => return,
            };

            if (bytes == 0) return;

            flag.* = true;
        }
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

    pub fn deinit(self: *Inotify) void {
        _ = std.posix.close(self.fd);
    }

};
