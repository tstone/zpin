const std = @import("std");
const fast = @import("./fast/fast_message.zig");
const FastMessage = fast.FastMessage;
const serial = @import("serial");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var ioPort = try std.fs.cwd().openFile("\\\\.\\COM5", .{ .mode = .read_write });
    defer ioPort.close();

    // expansionBus
    // displayBus

    try serial.configureSerialPort(ioPort, serial.SerialConfig{
        .baud_rate = 921_600,
        .word_size = .eight,
        .parity = .none,
        .stop_bits = .one,
        .handshake = .none,
    });

    try ioPort.writer().writeAll("ID:\r");

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    while (true) {
        const b = ioPort.reader().readByte() catch {
            continue;
        };
        try buffer.append(b);
        if (b == 13) {
            const trimmed = buffer.items[0 .. buffer.items.len - 1];
            const msg = try FastMessage.parse(allocator, trimmed);
            // buffer.clearAndFree();
            std.debug.print("response: {}\n", .{msg});
            break;
        }
    }
}
