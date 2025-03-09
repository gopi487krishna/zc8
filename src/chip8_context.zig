const std = @import("std");
const testing = std.testing;

// Keys supported
pub const KeyPad = struct {
    pub const Key = enum(u4) {
        Key0 = 0x0,
        Key1,
        Key2,
        Key3,
        Key4,
        Key5,
        Key6,
        Key7,
        Key8,
        Key9,
        KeyA,
        KeyB,
        KeyC,
        KeyD,
        KeyE,
        KeyF,
    };

    keypad_state : u16 = 0,

    pub fn isKeyPressed(self: *KeyPad, key: Key) bool {
        const key_value = @intFromEnum(key);
        const mask:u16 = (@as(u16,1) << key_value);
        return (mask & self.keypad_state) == mask;
    }

    pub fn pressKey(self: *KeyPad, key: Key) void {
        const key_value = @intFromEnum(key);
        const mask:u16 = (@as(u16,1) << key_value);
        self.keypad_state |= mask;
    }

    pub fn releaseKey(self: *KeyPad, key: Key) void {
        const key_value = @intFromEnum(key);
        const mask:u16 = ~(@as(u16,1) << key_value);
        self.keypad_state &= mask;
    }
};

// Holds the entire state of the emulator
pub const Chip8Context = struct {
    // Ram
    memory: [4096]u8 = [_]u8{0} ** 4096,
    // Register set for Chip8
    v: [16]u8 = [_]u8{0} ** 16,
    // Index Register
    i: u16 = 0,
    // Rom Location
    rom_location: u16 = 0x200,
    // Program starts from 0x200
    pc: u16 = 0x200,
    // Stack implemented as ArrayList for dynamic sizing
    stack: std.ArrayList(u16),
    // Display
    frame_buffer: [64 * 32]u8 = [_]u8{0} ** (64 * 32),
    delay_timer: u8 = 0,
    sound_timer: u8 = 0,
    rom_length: usize = 0,
    halt: bool = false,
    random_source: std.Random.Xoshiro256,
    keypad: KeyPad = KeyPad{},

    pub fn initContext() !Chip8Context {
        return Chip8Context{
            .stack = std.ArrayList(u16).init(std.heap.page_allocator),
            .random_source = std.Random.DefaultPrng.init(blk: {
                var seed : u64 = undefined;
                try std.posix.getrandom(std.mem.asBytes(&seed));
                break :blk seed;
            }),
        };
    }

    pub fn deinit(self: *Chip8Context) void {
        self.stack.deinit();
    }
};

test "Chip 8 Context Initialization" {
    const ctx = try Chip8Context.initContext();

    // Memory must be zero initialized
    for (ctx.memory) |byte| {
        try testing.expectEqual(@as(u8, 0), byte);
    }

    // Registers must be zero initialized
    for (ctx.v) |register| {
        try testing.expectEqual(@as(u8, 0), register);
    }

    // Index register must be zero
    try testing.expectEqual(@as(u16, 0), ctx.i);

    // Pc must be 512 bytes from start
    try testing.expectEqual(@as(u16, 0x200), ctx.pc);

    // Stack must be initialized as empty
    try testing.expectEqual(@as(usize, 0), ctx.stack.items.len);

    // Framebuffer must be zero initialized
    for (ctx.frame_buffer) |addr| {
        try testing.expectEqual(@as(u8, 0), addr);
    }

    // Delay timer must be zero initialized
    try testing.expectEqual(@as(u8, 0x0), ctx.delay_timer);

    // Sound timer must be zero initialized
    try testing.expectEqual(@as(u8, 0x0), ctx.sound_timer);

    // Rom location must be set to 0x200.
    try testing.expectEqual(@as(u16,0x200), ctx.rom_location);

    // Rom length must be set to zero initially
    try testing.expectEqual(@as(usize,0x0), ctx.rom_length);

    // Halt must be set to false
    try testing.expectEqual(false, ctx.halt);
}

test "KeyPad.isKeyPressed"  {
    var ctx = try Chip8Context.initContext();

    ctx.keypad.pressKey(KeyPad.Key.KeyA);

    try std.testing.expectEqual(true, ctx.keypad.isKeyPressed(KeyPad.Key.KeyA));

    ctx.keypad.releaseKey(KeyPad.Key.KeyA);

    try std.testing.expectEqual(false, ctx.keypad.isKeyPressed(KeyPad.Key.KeyA));
}

