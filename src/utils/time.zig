const std = @import("std");
const Self = @This();

start_time: i128,
paused_ns_time: i128,
paused_start_ns: i128,
paused_ns_total: i128 = 0,
pause: bool = true,
time_sec: f64 = 0,
frame_count: u32 = 0,
last_time_ns: u64 = 0,
fps: f64 = 0.0,

pub fn Start() Self{
    return .{
        .start_time = std.time.nanoTimestamp(),
        .paused_ns_time = 0,
        .paused_start_ns = 0,
        .pause = false,
        .frame_count = 0,
        .last_time_ns = @intCast(std.time.nanoTimestamp()),
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

pub fn FrameCounter(self: *Self) void {
  self.frame_count += 1;
  const now_f: u64 = @intCast(std.time.nanoTimestamp());
  const elapsed_ns = now_f - self.last_time_ns;

  const one_second_ns: u64 = 1_000_000_000;

  if (elapsed_ns >= one_second_ns) {

        const fps = @as(f64, @floatFromInt(self.frame_count)) /
                (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0);

        //std.debug.print("FPS: {d:.2}\n", .{fps});
        self.fps = fps;
        self.frame_count = 0;
        self.last_time_ns = now_f;
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
