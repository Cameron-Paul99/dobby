const std = @import("std");
const engine = @import("engine");
const c = engine.c;

const Self = @This();

const OscType = enum {
    sine,
    triangle,
    saw,
    square,
    noise,
};

const Tone = struct {
    phase: f32 = 0,
    freq: f32 = 440,
};

const Tone = struct {
    phase: f32 = 0,
    freq: f32 = 0,
    amplitude: f32 = 0,
    target_amplitude: f32 = 0,
    osc_type: OscType = .sine,
    active: bool = false,
    seed: u32 = 0,
};

device: c.ma_device = undefined,
sample_rate: u32 = 48000,
tones: [64]Tone = [_]Tone{.{}} ** 64,



fn nextNoise(seed: *u32) f32 {
    seed.* = seed.* * 1664525 + 1013904223;
    const v: u16 = @truncate(seed.* >> 8);
    return (@as(f32, @floatFromInt(v)) / 65535.0) * 2.0 - 1.0;
}

fn oscillate(tone: *Tone, sample_rate: f32) f32 {
    const phase_norm = tone.phase / std.math.tau;

    const sample = switch (tone.osc_type) {
        .sine => @sin(tone.phase),
        .triangle => 2.0 * @abs(2.0 * phase_norm - 1.0) - 1.0,
        .saw => 2.0 * phase_norm - 1.0,
        .square => if (tone.phase < std.math.pi) 1.0 else -1.0,
        .noise => nextNoise(&tone.seed),
    };

    const increment = std.math.tau * tone.freq / sample_rate;
    tone.phase = @mod(tone.phase + increment, std.math.tau);

    return sample;
}

// Books
//
// The Audio Programming book (Boulanger and Lazzarini)
// Computer Music (Dodge and Jerse)
// Designing Sound Andy Farnell
// The Science of sound Rossing
//
