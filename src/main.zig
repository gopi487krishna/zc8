const std = @import("std");
const chip8_context = @import("chip8_context.zig");
const chip8 = @import("chip8.zig");
const Chip8 = chip8.Chip8;

const testing = std.testing;

pub fn main() !void {
    var ctx = chip8_context.initContext();
    try Chip8.loadRom(&ctx);
    try Chip8.run(&ctx);
}

test "simple test" {
    // var list = std.ArrayList(i32).init(std.testing.allocator);
    // defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    // try list.append(42);
    // try std.testing.expectEqual(@as(i32, 42), list.pop());
}
