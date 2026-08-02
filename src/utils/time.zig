const std = @import("std");
const Io = std.Io;
const Self = @This();

start_time: i128,
paused_ns_time: i128,
paused_start_ns: i128,
paused_ns_total: i128 = 0,
pause: bool = true,
time_sec: f64 = 0,
frame_count: u32 = 0,
last_time_ns: u64 = 0,
last_frame_ns: i128 = 0,
fps: f64 = 0.0,
delta_sec: f64 = 0.0,

fn nanoNow(io: std.Io) i128 {
    return @as(i128, std.Io.Timestamp.now(io, .real).toNanoseconds());
}

pub fn Start(io: Io) Self {
    return .{
        .start_time = nanoNow(io),
        .paused_ns_time = 0,
        .paused_start_ns = 0,
        .pause = false,
        .frame_count = 0,
        .last_frame_ns = 0,
        .last_time_ns = @intCast(nanoNow(io)),
        .delta_sec = 0,
    };
}

pub fn PauseCal(self: *Self, io: Io) void {
    if (self.pause) {
        self.paused_ns_total += nanoNow(io) - self.paused_start_ns;
        self.pause = false;
    } else {
        self.paused_start_ns = nanoNow(io);
        self.pause = true;
    }
}

pub fn Runnin(self: *Self, io: Io) void {
    if (!self.pause) {
        const now = nanoNow(io);
        const effective_ns = now - self.start_time - self.paused_ns_total;
        self.time_sec = @as(f64, @floatFromInt(effective_ns)) / 1_000_000_000.0;
        if (self.last_frame_ns != 0 ) {
            const delta_ns = now - self.last_frame_ns;
            self.delta_sec = @as(f64, @floatFromInt(delta_ns)) / 1_000_000_000.0;
        }
        self.last_frame_ns = now;
    }
}

pub fn FrameCounter(self: *Self, io: Io) void {
    self.frame_count += 1;
    const now_f: u64 = @intCast(nanoNow(io));
    const elapsed_ns = now_f - self.last_time_ns;
    const one_second_ns: u64 = 1_000_000_000;
    if (elapsed_ns >= one_second_ns) {
        const fps = @as(f64, @floatFromInt(self.frame_count)) /
            (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);
        self.fps = fps;
        self.frame_count = 0;
        self.last_time_ns = now_f;
    }
}

pub fn Restart(self: *Self, io: Io) void {
    const now = nanoNow(io);
    self.start_time = now;
    self.paused_start_ns = now;
    self.paused_ns_total = 0;
    self.pause = false;
}

pub fn HardRestart(self: *Self, io: Io) void {
    const now = nanoNow(io);
    self.start_time = now;
    self.paused_start_ns = now;
    self.paused_ns_total = 0;
    self.pause = true;
}
