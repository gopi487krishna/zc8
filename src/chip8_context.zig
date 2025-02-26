const std = @import("std");
const testing = std.testing;
// Holds the entire state of the emulator
pub const Chip8Context = struct {
    // Ram
    memory: [4096]u8 = [_]u8{0} ** 4096,
    // Register set for Chip8
    v: [16]u8 = [_]u8{0} ** 16,
    // Index Register
    i: u16 = 0,
    // Program starts from 0x200
    pc: u16 = 0x200,
    // Stack 16 entries for now
    stack: [16]u16 = [_]u16{0} ** 16,
    // Display
    frame_buffer: [64 * 32]u8 = [_]u8{0} ** (64 * 32),
    delay_timer: u8 = 0,
    sound_timer: u8 = 0,
};

pub fn initContext() Chip8Context {
    return Chip8Context{};
}

test "Chip 8 Context Initialization" {
    const ctx = initContext();

    // Memory must be zero initialized
    for (ctx.memory) |byte| {
        try testing.expectEqual(@as(u8, 0), byte);
    }

    // Registers must be zero initialized
    for (ctx.v) |register| {
        try testing.expectEqual(@as(u16, 0), register);
    }

    // Index register must be zero
    try testing.expectEqual(@as(u16, 0), ctx.i);

    // Pc must be 512 bytes from start
    try testing.expectEqual(@as(u16, 0x200), ctx.pc);

    // Stack must be zero initialized
    for (ctx.stack) |addr| {
        try testing.expectEqual(@as(u16, 0), addr);
    }

    // Framebuffer must be zero initialized
    for (ctx.stack) |addr| {
        try testing.expectEqual(@as(u16, 0), addr);
    }

    // Delay timer must be zero initialized
    try testing.expectEqual(@as(u8, 0x0), ctx.delay_timer);

    // Sound timer must be zero initialized
    try testing.expectEqual(@as(u8, 0x0), ctx.sound_timer);
}
