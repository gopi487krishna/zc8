const std = @import("std");
const Chip8Context = @import("chip8_context.zig").Chip8Context;
const KeyPad = @import("chip8_context.zig").KeyPad;

pub const Chip8Error = error{ RomTooLarge, InstructionNotSupported, PcOutOfBounds, StackEmpty };

pub const Chip8 = struct {
    ctx: *Chip8Context,

    const Opcode = enum {
        SYS_addr, // 0nnn
        CLS, // 00E0
        RET, // 00EE
        JP_addr, // 1nnn
        CALL_addr, // 2nnn
        SE_Vx_byte, // 3xkk
        SNE_Vx_byte, // 4xkk
        SE_Vx_Vy, // 5xy0
        LD_Vx_byte, // 6xkk
        ADD_Vx_byte, // 7xkk
        LD_Vx_Vy, // 8xy0
        OR_Vx_Vy, // 8xy1
        AND_Vx_Vy, // 8xy2
        XOR_Vx_Vy, // 8xy3
        ADD_Vx_Vy, // 8xy4
        SUB_Vx_Vy, // 8xy5
        SHR_Vx_Vy, // 8xy6
        SUBN_Vx_Vy, // 8xy7
        SHL_Vx_Vy, // 8xyE
        SNE_Vx_Vy, // 9xy0
        LD_I_addr, // Annn
        JP_V0_addr, // Bnnn
        RND_Vx_byte, // Cxkk
        DRW_Vx_Vy_n, // Dxyn
        SKP_Vx, // Ex9E
        SKNP_Vx, // ExA1
        LD_Vx_DT, // Fx07
        LD_Vx_K, // Fx0A
        LD_DT_Vx, // Fx15
        LD_ST_Vx, // Fx18
        ADD_I_Vx, // Fx1E
        LD_F_Vx, // Fx29
        LD_B_Vx, // Fx33
        LD_I_Vx, // Fx55
        LD_Vx_I, // Fx65
        UNIMPLEMENTED,
    };

    pub fn clear_display(self: *Chip8) void {
        @memset(self.ctx.frame_buffer[0..], 0);
        self.ctx.draw_flag = true;
    }
    pub fn decode(_: *Chip8, instruction: u16) !Opcode {
        // Last 4 bit value
        const n: u4 = @intCast(instruction & 0x000F);
        const opcode = switch ((instruction & 0xF000) >> 12) {
            0x0 => switch (instruction & 0x00FF) {
                0x00E0 => Opcode.CLS,
                0x00EE => Opcode.RET,
                else => Opcode.SYS_addr,
            },
            0x1 => Opcode.JP_addr,
            0x2 => Opcode.CALL_addr,
            0x3 => Opcode.SE_Vx_byte,
            0x4 => Opcode.SNE_Vx_byte,
            0x5 => Opcode.SE_Vx_Vy,
            0x6 => Opcode.LD_Vx_byte,
            0x7 => Opcode.ADD_Vx_byte,
            0x8 => switch (n) {
                0x0 => Opcode.LD_Vx_Vy,
                0x1 => Opcode.OR_Vx_Vy,
                0x2 => Opcode.AND_Vx_Vy,
                0x3 => Opcode.XOR_Vx_Vy,
                0x4 => Opcode.ADD_Vx_Vy,
                0x5 => Opcode.SUB_Vx_Vy,
                0x6 => Opcode.SHR_Vx_Vy,
                0x7 => Opcode.SUBN_Vx_Vy,
                0xE => Opcode.SHL_Vx_Vy,
                else => Opcode.UNIMPLEMENTED,
            },
            0x9 => Opcode.SNE_Vx_Vy,
            0xA => Opcode.LD_I_addr,
            0xB => Opcode.JP_V0_addr,
            0xC => Opcode.RND_Vx_byte,
            0xD => Opcode.DRW_Vx_Vy_n,
            0xE => switch (instruction & 0x00FF) {
                0x9E => Opcode.SKP_Vx,
                0xA1 => Opcode.SKNP_Vx,
                else => Opcode.UNIMPLEMENTED,
            },
            0xF => switch (instruction & 0x00FF) {
                0x07 => Opcode.LD_Vx_DT,
                0x0A => Opcode.LD_Vx_K,
                0x15 => Opcode.LD_DT_Vx,
                0x18 => Opcode.LD_ST_Vx,
                0x1E => Opcode.ADD_I_Vx,
                0x29 => Opcode.LD_F_Vx,
                0x33 => Opcode.LD_B_Vx,
                0x55 => Opcode.LD_I_Vx,
                0x65 => Opcode.LD_Vx_I,
                else => Opcode.UNIMPLEMENTED,
            },
            else => Opcode.UNIMPLEMENTED,
        };
        return opcode;
    }
    pub fn execute(self: *Chip8) !void {
        if (self.ctx.pc > self.ctx.memory.len - 2) return Chip8Error.PcOutOfBounds;
        const instruction = @as(u16, self.ctx.memory[self.ctx.pc]) << 8 | self.ctx.memory[self.ctx.pc + 1];
        const opcode = try self.decode(instruction);
        // Last 4 bit value
        const n: u4 = @intCast(instruction & 0x000F);
        // Lower 4 bits of high byte
        const Vx: u4 = @intCast(instruction >> 8 & 0x0F);
        // Upper 4 bits of low byte
        const Vy: u4 = @intCast(instruction >> 4 & 0x0F);
        // Lowest 8 bits
        const nn: u8 = @intCast(instruction & 0x00FF);
        // Bottom 12bits
        const nnn: u16 = instruction & 0x0FFF;

        self.ctx.pc += 2;

        switch (opcode) {
            .SYS_addr => {
                unreachable;
            },
            .CLS => {
                self.clear_display();
            },
            .RET => {
                if (self.ctx.stack.items.len == 0) {
                    return Chip8Error.StackEmpty;
                } else {
                    self.ctx.pc = self.ctx.stack.pop().?;
                }
            },
            .JP_addr => self.ctx.pc = nnn,
            .CALL_addr => {
                try self.ctx.stack.append(self.ctx.pc);
                self.ctx.pc = nnn;
            },
            .SE_Vx_byte => {
                const Vx_val = self.ctx.v[Vx];
                if (Vx_val == nn) {
                    self.ctx.pc += 2;
                }
            },
            .SNE_Vx_byte => {
                const Vx_val = self.ctx.v[Vx];
                if (Vx_val != nn) {
                    self.ctx.pc += 2;
                }
            },
            .SE_Vx_Vy => {
                const Vx_val = self.ctx.v[Vx];
                const Vy_val = self.ctx.v[Vy];
                if (Vx_val == Vy_val) {
                    self.ctx.pc += 2;
                }
            },
            .LD_Vx_byte => self.ctx.v[Vx] = nn,
            .ADD_Vx_byte => {
                const result = @addWithOverflow(self.ctx.v[Vx], nn);
                self.ctx.v[Vx] = result[0];
            },
            .LD_Vx_Vy => self.ctx.v[Vx] = self.ctx.v[Vy],
            .OR_Vx_Vy => self.ctx.v[Vx] |= self.ctx.v[Vy],
            .AND_Vx_Vy => self.ctx.v[Vx] &= self.ctx.v[Vy],
            .XOR_Vx_Vy => self.ctx.v[Vx] ^= self.ctx.v[Vy],
            .ADD_Vx_Vy => {
                const result = @addWithOverflow(self.ctx.v[Vx], self.ctx.v[Vy]);
                self.ctx.v[Vx] = result[0];
                self.ctx.v[0xF] = result[1];
            },
            .SUB_Vx_Vy => {
                const result = @subWithOverflow(self.ctx.v[Vx], self.ctx.v[Vy]);
                self.ctx.v[Vx] = result[0];
                const borrow: u8 = ~result[1];
                self.ctx.v[0xF] = borrow;
            },
            .SHR_Vx_Vy => {
                self.ctx.v[0xF] = self.ctx.v[Vy] & 1;
                self.ctx.v[Vx] = self.ctx.v[Vy] >> 1;
            },
            .SUBN_Vx_Vy => {
                const result = @subWithOverflow(self.ctx.v[Vy], self.ctx.v[Vx]);
                self.ctx.v[Vx] = result[0];
                const borrow: u8 = ~result[1];
                self.ctx.v[0xF] = borrow;
            },
            .SHL_Vx_Vy => {
                self.ctx.v[0xF] = (self.ctx.v[Vy] & 0x80) >> 7;
                self.ctx.v[Vx] = self.ctx.v[Vy] << 1;
            },
            .SNE_Vx_Vy => {
                if (self.ctx.v[Vx] != self.ctx.v[Vy])
                    self.ctx.pc += 2;
            },
            .LD_I_addr => {
                self.ctx.i = nnn;
            },
            .JP_V0_addr => {
                const V0_val = self.ctx.v[0];
                self.ctx.pc = nnn + V0_val;
            },
            .RND_Vx_byte => {
                const rand = self.ctx.random_source.random();
                const random_value = rand.intRangeAtMost(u8, 0, 255);
                self.ctx.v[Vx] = random_value & nn;
            },
            .DRW_Vx_Vy_n => {
                // x coordinate in FB
                const x = self.ctx.v[Vx] & 63;
                // y coordinate in FB
                const y = self.ctx.v[Vy] & 31;
                const Vf = 0xF;
                // Flag initially set to 0
                self.ctx.v[Vf] = 0;
                // n represents the total height of the sprite (num rows)
                for (0..n) |row| {
                    // Read the sprite width info
                    const data = self.ctx.memory[self.ctx.i + row];

                    // Each sprite data is 8 bit
                    for (0..8) |pix_usize| {
                        const pixel: u3 = @intCast(pix_usize);
                        const bitpos: u3 = 7 - pixel;
                        const mask = @as(u8, 1) << bitpos;
                        const sprite_pixel_set = data & mask;
                        const pos = ((y + row) * 64) + (x + pixel);
                        if (pos >= 64 * 32) {
                            continue;
                        }
                        if (sprite_pixel_set != 0) {
                            if (self.ctx.frame_buffer[pos] == 1) {
                                self.ctx.v[Vf] = 0x1; // Collision detected
                            }
                            self.ctx.frame_buffer[pos] ^= 1;
                            self.ctx.draw_flag = true;
                        }
                    }
                }
            },
            .SKP_Vx => {
                const Vx_val = self.ctx.v[Vx];
                const key: KeyPad.Key = @enumFromInt(Vx_val);
                if (self.ctx.keypad.isKeyPressed(key)) {
                    self.ctx.pc += 2;
                }
            },
            .SKNP_Vx => {
                const Vx_val = self.ctx.v[Vx];
                const key: KeyPad.Key = @enumFromInt(Vx_val);
                if (!self.ctx.keypad.isKeyPressed(key)) {
                    self.ctx.pc += 2;
                }
            },
            .LD_Vx_DT => {
                self.ctx.v[Vx] = self.ctx.delay_timer;
            },
            .LD_Vx_K => {
                if (self.ctx.keypad.keypad_state == 0)
                    self.ctx.pc -= 2;
            },
            .LD_DT_Vx => {
                self.ctx.delay_timer = self.ctx.v[Vx];
            },
            .LD_ST_Vx => {
                self.ctx.sound_timer = self.ctx.v[Vx];
            },
            .ADD_I_Vx => {
                self.ctx.i += self.ctx.v[Vx];
            },
            .LD_F_Vx => {
                const Vx_val = self.ctx.v[Vx];
                const Vx_nibble: u4 = @intCast(Vx_val & 0x0F);
                self.ctx.i = (0x0 + @as(u16, Vx_nibble) * 5);
            },
            .LD_B_Vx => {
                const Vx_val = self.ctx.v[Vx];
                const i = self.ctx.i;
                self.ctx.memory[i] = (Vx_val / 100) % 10;
                self.ctx.memory[i + 1] = (Vx_val / 10) % 10;
                self.ctx.memory[i + 2] = Vx_val % 10;
            },
            .LD_I_Vx => {
                @memcpy(self.ctx.memory[self.ctx.i .. self.ctx.i + Vx + 1], self.ctx.v[0 .. Vx + 1]);
                self.ctx.i = self.ctx.i + Vx + 1;
            },
            .LD_Vx_I => {
                @memcpy(self.ctx.v[0 .. Vx + 1], self.ctx.memory[self.ctx.i .. self.ctx.i + Vx + 1]);
                self.ctx.i = self.ctx.i + Vx + 1;
            },
            .UNIMPLEMENTED => return Chip8Error.InstructionNotSupported,
        }

        if (self.ctx.pc >= (self.ctx.rom_length + self.ctx.rom_location)) {
            self.ctx.halt = true;
        }
    }

    pub fn loadRomFromArray(self: *Chip8, rom: []const u8) !void {
        if (rom.len > self.ctx.memory[0x200..].len) return Chip8Error.RomTooLarge;
        @memcpy(self.ctx.memory[0x200 .. 0x200 + rom.len], rom);
        self.ctx.rom_length = rom.len;
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
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    try chip8.loadRomFromFile(std.testing.allocator, chip8_logo_rom_path);

    // Read the Entire Rom
    var file = try std.fs.openFileAbsolute(chip8_logo_rom_path, .{ .mode = .read_only });
    const rom = try file.readToEndAlloc(std.testing.allocator, std.math.maxInt(usize));
    defer std.testing.allocator.free(rom);
    try std.testing.expectEqualSlices(u8, ctx.memory[0x200 .. 0x200 + rom.len], rom);
}

test "Chip8.loadRomFromFile.errorRomTooLarge" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
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

    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    chip8.loadFont();
    try std.testing.expectEqualSlices(u8, font_sprites[0..], ctx.memory[0x00..0x50]);
}

fn createInstruction(opcode_prefix: u8, x: u8, y: u8, opcode_suffix: u8) [2]u8 {
    const top_byte = (opcode_prefix << 4) | x;
    const bottom_byte = (y << 4) | opcode_suffix;
    return [_]u8{ top_byte, bottom_byte };
}

// 0nnn
test "Opcode.SYS_addr" {}
// 00E0
test "Opcode.CLS" {}
// 00EE
test "Opcode.RET" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    try ctx.stack.append(0x238);

    const rom_data = createInstruction(0x0, 0x0, 0xE, 0xE);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(ctx.pc, 0x238);
}
// 1nnn
test "Opcode.JP_addr" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };

    const rom_data = createInstruction(0x1, 0x2, 0x3, 0x8);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x238, ctx.pc);
}
// 2nnn
test "Opcode.CALL_addr" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };

    const rom_data = createInstruction(0x2, 0x2, 0x3, 0x8);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x238, ctx.pc);

    const return_address = ctx.stack.pop().?;
    try std.testing.expectEqual(0x202, return_address);
}
// 3xkk
test "Opcode.SE_Vx_byte_ne" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };

    const Vx = 0;

    const rom_data = createInstruction(0x3, Vx, 0x1, 0x2);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x202, ctx.pc);
}

test "Opcode.SE_Vx_byte_eq" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };

    const Vx = 0;
    ctx.v[Vx] = 0x12;

    const rom_data = createInstruction(0x3, Vx, 0x1, 0x2);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x204, ctx.pc);
}
// 4xkk
test "Opcode.SNE_Vx_byte_ne" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };

    const Vx = 0;

    const rom_data = createInstruction(0x4, Vx, 0x1, 0x2);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x204, ctx.pc);
}

test "Opcode.SNE_Vx_byte_eq" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };

    const Vx = 0;

    ctx.v[Vx] = 0x12;

    const rom_data = createInstruction(0x4, Vx, 0x1, 0x2);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x202, ctx.pc);
}
// 5xy0
test "Opcode.SE_Vx_Vy_eq" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };

    const Vx = 0;
    const Vy = 1;

    ctx.v[Vx] = 0x12;
    ctx.v[Vy] = 0x12;

    const rom_data = createInstruction(0x5, Vx, Vy, 0x0);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x204, ctx.pc);
}

test "Opcode.SE_Vx_Vy_ne" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };

    const Vx = 0;
    const Vy = 1;

    ctx.v[Vx] = 0x12;

    const rom_data = createInstruction(0x5, Vx, Vy, 0x0);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x202, ctx.pc);
}
// 6xkk
test "Opcode.LD_Vx_byte" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 8;
    const rom_data = createInstruction(0x6, Vx, 0x3, 0x4);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0x34, ctx.v[8]);
}
// 7xkk
test "Opcode.ADD_Vx_byte" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;

    ctx.v[Vx] = 0x5;
    const rom_data = createInstruction(0x7, Vx, 0x3, 0x4);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0x39, ctx.v[0]);
}
// 8xy0
test "Opcode.LD_Vx_Vy" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    const Vy = 3;
    ctx.v[Vy] = 0x5;
    const rom_data = createInstruction(0x8, Vx, Vy, 0x0);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0x5, ctx.v[Vx]);
}
// 8xy1
test "Opcode.OR_Vx_Vy" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    const Vy = 1;
    ctx.v[Vx] = 0x4;
    ctx.v[Vy] = 0x3;

    const rom_data = createInstruction(0x8, Vx, Vy, 0x1);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0x7, ctx.v[Vx]);
}
// 8xy2
test "Opcode.AND_Vx_Vy" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    const Vy = 1;
    ctx.v[Vx] = 0x4;
    ctx.v[Vy] = 0x3;

    const rom_data = createInstruction(0x8, Vx, Vy, 0x2);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0x0, ctx.v[Vx]);
}
// 8xy3
test "Opcode.XOR_Vx_Vy" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    const Vy = 1;
    ctx.v[Vx] = 0x7;
    ctx.v[Vy] = 0x7;

    const rom_data = createInstruction(0x8, Vx, Vy, 0x3);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0x0, ctx.v[Vx]);
}
// 8xy4
test "Opcode.ADD_Vx_Vy_nocarry" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    const Vy = 1;
    ctx.v[Vx] = 0x7;
    ctx.v[Vy] = 0x7;

    const rom_data = createInstruction(0x8, Vx, Vy, 0x4);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0xE, ctx.v[Vx]);
}
test "Opcode.ADD_Vx_Vy_carry" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    const Vy = 1;
    const Vf = 0xF;
    ctx.v[Vx] = 0xFF;
    ctx.v[Vy] = 0x1;

    const rom_data = createInstruction(0x8, Vx, Vy, 0x4);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0x0, ctx.v[Vx]);
    try std.testing.expectEqual(0x1, ctx.v[Vf]);
}
// 8xy5
test "Opcode.SUB_Vx_Vy_nooverflow" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    const Vy = 1;
    const Vf = 0xF;
    ctx.v[Vx] = 0x5;
    ctx.v[Vy] = 0x4;

    const rom_data = createInstruction(0x8, Vx, Vy, 0x5);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0x1, ctx.v[Vx]);
    try std.testing.expectEqual(0x1, ctx.v[Vf]);
}

test "Opcode.SUB_Vx_Vy_overflow" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    const Vy = 1;
    const Vf = 0xF;
    ctx.v[Vx] = 0x4;
    ctx.v[Vy] = 0x5;

    const rom_data = createInstruction(0x8, Vx, Vy, 0x5);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0xFF, ctx.v[Vx]);
    try std.testing.expectEqual(0x0, ctx.v[Vf]);
}

// 8xy6
test "Opcode.SHR_Vx_Vy" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    const Vy = 1;
    const Vf = 0xF;
    ctx.v[Vy] = 0x4;

    const rom_data = createInstruction(0x8, Vx, Vy, 0x6);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0x2, ctx.v[Vx]);
    try std.testing.expectEqual(0x0, ctx.v[Vf]);
}
// 8xy7
test "Opcode.SUBN_Vx_Vy_borrow" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    const Vy = 1;
    const Vf = 0xF;
    ctx.v[Vx] = 0x5;
    ctx.v[Vy] = 0x4;

    const rom_data = createInstruction(0x8, Vx, Vy, 0x7);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0xFF, ctx.v[Vx]);
    try std.testing.expectEqual(0x0, ctx.v[Vf]);
}
// 8xyE
test "Opcode.SHL_Vx_Vy" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    const Vy = 1;
    const Vf = 0xF;
    ctx.v[Vy] = 0x4;

    const rom_data = createInstruction(0x8, Vx, Vy, 0xE);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0x8, ctx.v[Vx]);
    try std.testing.expectEqual(0x0, ctx.v[Vf]);
}
// 9xy0
test "Opcode.SNE_Vx_Vy_true" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    const Vy = 1;

    ctx.v[Vx] = 2;
    ctx.v[Vy] = 2;

    const @"9xy0_instruction" = createInstruction(0x9, Vx, Vy, 0x0);
    const add_instruction = createInstruction(0x8, Vx, Vy, 0x4);

    const rom_data = @"9xy0_instruction" ++ add_instruction ++ add_instruction;

    try chip8.loadRomFromArray(rom_data[0..]);
    while (!ctx.halt) {
        try chip8.execute();
    }

    try std.testing.expectEqual(0x6, ctx.v[Vx]);
}

test "Opcode.SNE_Vx_Vy_false" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    const Vy = 1;

    ctx.v[Vx] = 2;
    ctx.v[Vy] = 3;

    const @"9xy0_instruction" = createInstruction(0x9, Vx, Vy, 0x0);
    const add_instruction = createInstruction(0x8, Vx, Vy, 0x4);

    const rom_data = @"9xy0_instruction" ++ add_instruction ++ add_instruction;

    try chip8.loadRomFromArray(rom_data[0..]);
    while (!ctx.halt) {
        try chip8.execute();
    }

    try std.testing.expectEqual(0x5, ctx.v[Vx]);
}
// Annn
test "Opcode.LD_I_addr" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };

    const rom_data = createInstruction(0xA, 0x2, 0x3, 0x8);

    try chip8.loadRomFromArray(rom_data[0..]);
    while (!ctx.halt) {
        try chip8.execute();
    }

    try std.testing.expectEqual(0x238, ctx.i);
}
// Bnnn
test "Opcode.JP_V0_addr" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };

    ctx.v[0] = 0x1;

    const rom_data = createInstruction(0xB, 0x2, 0x3, 0x8);

    try chip8.loadRomFromArray(rom_data[0..]);
    while (!ctx.halt) {
        try chip8.execute();
    }

    try std.testing.expectEqual(0x239, ctx.pc);
}
// Cxkk
test "Opcode.RND_Vx_byte" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    var chip8 = Chip8{ .ctx = &ctx };

    const Vx = 0;

    ctx.random_source = std.Random.DefaultPrng.init(42);

    const rom_data = createInstruction(0xC, Vx, 0xF, 0xF);

    try chip8.loadRomFromArray(rom_data[0..]);

    try chip8.execute();

    const random_value = ctx.v[Vx];

    // Reset
    ctx.pc = 0x200;
    ctx.random_source = std.Random.DefaultPrng.init(42);

    // Since same seed Vx and random value must be same
    try chip8.execute();

    try std.testing.expectEqual(random_value, ctx.v[Vx]);
}
// Dxyn
test "Opcode.DRW_Vx_Vy_n" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    defer ctx.deinit();
    var chip8 = Chip8{ .ctx = &ctx };

    const Vx = 0;
    const Vy = 1;
    const n = 5; // Height of sprite

    ctx.v[Vx] = 10;
    ctx.v[Vy] = 10;

    ctx.i = 0x300;

    // Draw a vertical line
    ctx.memory[0x300] = 0x80;
    ctx.memory[0x301] = 0x80;
    ctx.memory[0x302] = 0x80;
    ctx.memory[0x303] = 0x80;
    ctx.memory[0x304] = 0x80;

    const rom_data = createInstruction(0xD, Vx, Vy, n);

    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x1, ctx.frame_buffer[10 * 64 + 10]);
    try std.testing.expectEqual(0x1, ctx.frame_buffer[11 * 64 + 10]);
    try std.testing.expectEqual(0x1, ctx.frame_buffer[12 * 64 + 10]);
    try std.testing.expectEqual(0x1, ctx.frame_buffer[13 * 64 + 10]);
    try std.testing.expectEqual(0x1, ctx.frame_buffer[14 * 64 + 10]);
}

// Dxyn with collision
test "Opcode.DRW_Vx_Vy_n_collision" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    defer ctx.deinit();
    var chip8 = Chip8{ .ctx = &ctx };

    const Vx = 0;
    const Vy = 1;
    const n1 = 5; // Height of sprite

    ctx.v[Vx] = 10;
    ctx.v[Vy] = 10;

    ctx.i = 0x300;

    // Draw a vertical line
    ctx.memory[0x300] = 0x80;
    ctx.memory[0x301] = 0x80;
    ctx.memory[0x302] = 0x80;
    ctx.memory[0x303] = 0x80;
    ctx.memory[0x304] = 0x80;

    // Draw a horizontal line intersecting the vertical line
    const n2 = 1; // Height of sprite
    ctx.memory[0x305] = 0xFF;

    const inst1 = createInstruction(0xD, Vx, Vy, n1);
    const inst2 = createInstruction(0xD, Vx, Vy, n2);

    const rom_data = inst1 ++ inst2;

    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x0, ctx.v[0xF]);
    try chip8.execute();
    try std.testing.expectEqual(0x1, ctx.v[0xF]);
}
// Ex9E
test "Opcode.SKP_Vx_pressed" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    defer ctx.deinit();
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    ctx.v[Vx] = 0xA;
    ctx.keypad.pressKey(KeyPad.Key.KeyA);
    const rom_data = createInstruction(0xE, Vx, 0x9, 0xE);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0x204, ctx.pc);
}

test "Opcode.SKP_Vx_not_pressed" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    defer ctx.deinit();
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    ctx.v[Vx] = 0xA;
    const rom_data = createInstruction(0xE, Vx, 0x9, 0xE);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0x202, ctx.pc);
}
// ExA1
test "Opcode.SKNP_Vx" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    defer ctx.deinit();
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;
    ctx.v[Vx] = 0xA;
    ctx.keypad.pressKey(KeyPad.Key.KeyB);
    const rom_data = createInstruction(0xE, Vx, 0xA, 0x1);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();
    try std.testing.expectEqual(0x204, ctx.pc);
}
// Fx07
test "Opcode.LD_Vx_DT" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    defer ctx.deinit();
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;

    const delay_timer_val = 12;
    ctx.delay_timer = delay_timer_val;

    const rom_data = createInstruction(0xF, Vx, 0x0, 0x7);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(delay_timer_val, ctx.v[Vx]);
}
// Fx0A
test "Opcode.LD_Vx_K" {}
// Fx15
test "Opcode.LD_DT_Vx" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    defer ctx.deinit();
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;

    const delay_timer_val = 12;
    ctx.v[Vx] = delay_timer_val;

    const rom_data = createInstruction(0xF, Vx, 0x1, 0x5);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(delay_timer_val, ctx.delay_timer);
}
// Fx18
test "Opcode.LD_ST_Vx" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    defer ctx.deinit();
    var chip8 = Chip8{ .ctx = &ctx };
    const Vx = 0;

    const sound_timer_val = 12;
    ctx.v[Vx] = sound_timer_val;

    const rom_data = createInstruction(0xF, Vx, 0x1, 0x8);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(sound_timer_val, ctx.sound_timer);
}
// Fx1E
test "Opcode.ADD_I_Vx" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    defer ctx.deinit();
    var chip8 = Chip8{ .ctx = &ctx };

    const Vx = 0;

    ctx.i = 0x2;
    ctx.v[Vx] = 0x2;

    const rom_data = createInstruction(0xF, Vx, 0x1, 0xE);
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x4, ctx.i);
}
// Fx29
test "Opcode.LD_F_Vx" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    defer ctx.deinit();
    var chip8 = Chip8{ .ctx = &ctx };

    const Vx = 0;
    ctx.v[Vx] = 0xD;

    const rom_data = createInstruction(0xF, Vx, 0x2, 0x9);
    chip8.loadFont();
    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x41, ctx.i);
}
// Fx33
test "Opcode.LD_B_Vx" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    defer ctx.deinit();
    var chip8 = Chip8{ .ctx = &ctx };

    const Vx = 0x0;
    ctx.v[Vx] = 254;

    const rom_data = createInstruction(0xF, Vx, 0x3, 0x3);
    ctx.i = 0x210;

    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x2, ctx.memory[0x210]);
    try std.testing.expectEqual(0x5, ctx.memory[0x211]);
    try std.testing.expectEqual(0x4, ctx.memory[0x212]);
}
// Fx55
test "Opcode.LD_I_Vx" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    defer ctx.deinit();
    var chip8 = Chip8{ .ctx = &ctx };

    const Vx = 0x5;

    ctx.v[0] = 0x0;
    ctx.v[1] = 0x1;
    ctx.v[2] = 0x2;
    ctx.v[3] = 0x3;
    ctx.v[4] = 0x4;
    ctx.v[5] = 0x5;

    ctx.i = 0x210;

    const rom_data = createInstruction(0xF, Vx, 0x5, 0x5);

    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x0, ctx.memory[0x210]);
    try std.testing.expectEqual(0x1, ctx.memory[0x211]);
    try std.testing.expectEqual(0x2, ctx.memory[0x212]);
    try std.testing.expectEqual(0x3, ctx.memory[0x213]);
    try std.testing.expectEqual(0x4, ctx.memory[0x214]);
    try std.testing.expectEqual(0x5, ctx.memory[0x215]);
}
// Fx65
test "Opcode.LD_Vx_I" {
    var ctx = try Chip8Context.initContext(std.testing.allocator);
    defer ctx.deinit();
    var chip8 = Chip8{ .ctx = &ctx };

    const Vx = 0x5;

    ctx.i = 0x210;
    ctx.memory[0x210] = 0x0;
    ctx.memory[0x211] = 0x1;
    ctx.memory[0x212] = 0x2;
    ctx.memory[0x213] = 0x3;
    ctx.memory[0x214] = 0x4;
    ctx.memory[0x215] = 0x5;

    const rom_data = createInstruction(0xF, Vx, 0x6, 0x5);

    try chip8.loadRomFromArray(rom_data[0..]);
    try chip8.execute();

    try std.testing.expectEqual(0x0, ctx.v[0x0]);
    try std.testing.expectEqual(0x1, ctx.v[0x1]);
    try std.testing.expectEqual(0x2, ctx.v[0x2]);
    try std.testing.expectEqual(0x3, ctx.v[0x3]);
    try std.testing.expectEqual(0x4, ctx.v[0x4]);
    try std.testing.expectEqual(0x5, ctx.v[0x5]);
}
// UNIMPLEMENTED
test "Opcode.UNIMPLEMENTED" {}
