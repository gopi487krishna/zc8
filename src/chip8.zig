const std = @import("std");
const Chip8Context = @import("chip8_context.zig").Chip8Context;

pub const Chip8Error = error{ RomTooLarge, InstructionNotSupported };

pub const Chip8 = struct {
    ctx: *Chip8Context,
    pub fn execute(self: *Chip8) !void {
        const instruction = @as(u16, self.ctx.memory[self.ctx.pc]) << 8 | self.ctx.memory[self.ctx.pc + 1];

        // Last 4 bit value
        const n: u4 = @intCast(instruction & 0x000F);
        // Lower 4 bits of high byte
        const Vx: u4 = @intCast(instruction >> 8 & 0x0F);
        // Upper 4 bits of low byte
        const Vy: u4 = @intCast(instruction >> 4 & 0x0F);
        // Lowest 8 bits
        const nn: u8 = @intCast(instruction & 0x00FF);

        switch ((instruction & 0xF000) >> 12) {
            0x6 => self.ctx.v[Vx] = nn,
            0x7 => self.ctx.v[Vx] += nn,
            0x8 => {
                switch (n) {
                    0x0 => self.ctx.v[Vx] = self.ctx.v[Vy],
                    0x1 => self.ctx.v[Vx] |= self.ctx.v[Vy],
                    0x2 => self.ctx.v[Vx] &= self.ctx.v[Vy],
                    0x3 => self.ctx.v[Vx] ^= self.ctx.v[Vy],
                    0x4 => {
                        const result = @addWithOverflow(self.ctx.v[Vx], self.ctx.v[Vy]);
                        self.ctx.v[Vx] = result[0];
                        self.ctx.v[0xF] = result[1];
                    },
                    0x5 => {
                        const result = @subWithOverflow(self.ctx.v[Vx], self.ctx.v[Vy]);
                        self.ctx.v[Vx] = result[0];
                        self.ctx.v[0xF] = ~result[1];
                    },
                    0x6 => {
                        self.ctx.v[0xF] = self.ctx.v[Vy] & 1;
                        self.ctx.v[Vx] = self.ctx.v[Vy] >> 1;
                    },
                    0x7 => {
                        const result = @subWithOverflow(self.ctx.v[Vy], self.ctx.v[Vx]);
                        self.ctx.v[Vx] = result[0];
                        self.ctx.v[0xF] = ~result[1];
                    },
                    0xE => {
                        self.ctx.v[0xF] = self.ctx.v[Vy] & 0x8000;
                        self.ctx.v[Vx] = self.ctx.v[Vy] << 1;
                    },
                    else => return Chip8Error.InstructionNotSupported,
                }
            },
            else => return Chip8Error.InstructionNotSupported,
        }
    }

    pub fn loadRomFromArray(self: *Chip8, rom: []const u8) !void {
        if (rom.len > self.ctx.memory[0x200..].len) return Chip8Error.RomTooLarge;
        @memcpy(self.ctx.memory[0x200 .. 0x200 + rom.len], rom);
    }

    pub fn loadRomFromFile(self: *Chip8, allocator: std.mem.Allocator, absolute_path: []const u8) !void {
        var file = try std.fs.openFileAbsolute(absolute_path, .{ .mode = .read_only });
        const rom = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(rom);
        try self.loadRomFromArray(rom[0..]);
    }

    pub fn loadFont(self: *Chip8) void {
        const sprites = [_]u8{
            0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
            0x20, 0x60, 0x20, 0x20, 0x70, // 1
            0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
            0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
            0x90, 0x90, 0xF0, 0x10, 0x10, // 4
            0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
            0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
            0xF0, 0x10, 0x20, 0x40, 0x40, // 7
            0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
            0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
            0xF0, 0x90, 0xF0, 0x90, 0x90, // A
            0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
            0xF0, 0x80, 0x80, 0x80, 0xF0, // C
            0xE0, 0x90, 0x90, 0x90, 0xE0, // D
            0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
            0xF0, 0x80, 0xF0, 0x80, 0x80, // F
        };
        @memcpy(self.ctx.memory[0x0..sprites.len], sprites[0..]);
    }
};

test "Chip8.loadRomFromFile" {
    const test_roms_dir: []const u8 = @import("build_options").test_roms_dir;
    const chip8_logo_rom_path = test_roms_dir ++ "/chip8-logo.ch8";
    var ctx = Chip8Context.initContext();
    var chip8 = Chip8{ .ctx = &ctx };
    try chip8.loadRomFromFile(std.testing.allocator, chip8_logo_rom_path);

    // Read the Entire Rom
    var file = try std.fs.openFileAbsolute(chip8_logo_rom_path, .{ .mode = .read_only });
    const rom = try file.readToEndAlloc(std.testing.allocator, std.math.maxInt(usize));
    defer std.testing.allocator.free(rom);
    try std.testing.expectEqualSlices(u8, ctx.memory[0x200 .. 0x200 + rom.len], rom);
}

test "Chip8.loadRomFromFile.errorRomTooLarge" {
    var ctx = Chip8Context.initContext();
    var chip8 = Chip8{ .ctx = &ctx };
    const memory_size = 4096;
    const reserved_area = 512;
    const rom_size = memory_size - reserved_area + 1;

    const rom = [_]u8{0} ** rom_size;

    const err = chip8.loadRomFromArray(rom[0..]);

    try std.testing.expectError(Chip8Error.RomTooLarge, err);
}

test "Chip8.loadFont" {
    const font_sprites = [_]u8{
        0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
        0x90, 0x90, 0xF0, 0x10, 0x10, // 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
        0xF0, 0x10, 0x20, 0x40, 0x40, // 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
        0xF0, 0x80, 0x80, 0x80, 0xF0, // C
        0xE0, 0x90, 0x90, 0x90, 0xE0, // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
        0xF0, 0x80, 0xF0, 0x80, 0x80, // F
    };

    var ctx = Chip8Context.initContext();
    var chip8 = Chip8{ .ctx = &ctx };
    chip8.loadFont();
    try std.testing.expectEqualSlices(u8, font_sprites[0..], ctx.memory[0x00..0x50]);
}

test "Chip8.execute_LD_loadByteIntoVx" {
    var ctx = Chip8Context.initContext();
    var chip8 = Chip8{ .ctx = &ctx };
    const @"6xkk" = [_]u8{ 0x68, 0x34 };
    try chip8.loadRomFromArray(@"6xkk"[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0x34, ctx.v[8]);
}
