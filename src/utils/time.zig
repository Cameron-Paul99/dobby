const std = @import("std");
const Self = @This();

start_time: i128,
paused_ns_time: i128,
paused_start_ns: i128,
paused_ns_total: i128 = 0,
pause: bool = true,
time_sec: f64 = 0,

pub fn Start() Self{
    return .{
        .start_time = std.time.nanoTimestamp(),
        .paused_ns_time = 0,
        .paused_start_ns = 0,
        .pause = false,
    };
}

pub fn PauseCal(self: *Self) void {
    if (self.pause){
        self.paused_ns_total += std.time.nanoTimestamp() - self.paused_start_ns;
        self.pause = false;
    }else{ 
        self.paused_start_ns = std.time.nanoTimestamp();
        self.pause = true;
    }
}

pub fn Runnin(self: *Self) void {
    if (!self.pause){
        const now = std.time.nanoTimestamp();
        const effective_ns = now - self.start_time - self.paused_ns_total;
        self.time_sec = @as(f64, @floatFromInt(effective_ns)) / 1_000_000_000.0;
    }
}

pub fn Restart(self: *Self) void {
    const now = std.time.nanoTimestamp();
    self.start_time = now;
    self.paused_start_ns = now;
    self.paused_ns_total = 0;
    self.pause = false;
}

pub fn HardRestart(self: *Self) void {
    const now = std.time.nanoTimestamp();
    self.start_time = now;
    self.paused_start_ns = now;
    self.paused_ns_total = 0;
    self.pause = true;
}
