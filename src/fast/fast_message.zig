const std = @import("std");
const Allocator = std.mem.Allocator;

/// A low level representation of a basic FAST Pinball serial
pub const FastMessage = struct {
    allocator: Allocator,
    command: []const u8,
    address: ?[]const u8,
    args: [][]const u8,

    /// Parse an incoming message
    pub fn parse(allocator: Allocator, input: []const u8) !FastMessage {
        var cmd: []const u8 = undefined;
        var addr: ?[]const u8 = null;

        var rootIter = std.mem.splitScalar(u8, input, ':');
        if (rootIter.peek() != null) {
            var cmdIter = std.mem.splitScalar(u8, rootIter.next().?, '@');
            cmd = cmdIter.next().?;
            if (cmdIter.peek() != null) {
                addr = cmdIter.next().?;
            }
        }

        var argList = std.ArrayList([]const u8).init(allocator);
        defer argList.deinit();

        if (rootIter.peek() != null) {
            var argsIter = std.mem.splitScalar(u8, rootIter.next().?, ',');
            while (argsIter.next()) |arg| {
                if (arg.len > 0) {
                    try argList.append(arg);
                }
            }
        }

        const args = try allocator.alloc([]const u8, argList.items.len);
        @memcpy(args, argList.items);

        return FastMessage{
            .command = cmd,
            .address = addr,
            .args = args,
            .allocator = allocator,
        };
    }

    fn deinit(message: FastMessage) void {
        message.allocator.free(message.args);
    }
};

// ---

const testingAllocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "it parses bare commands" {
    const msg = try FastMessage.parse(testingAllocator, "ID:");
    defer msg.deinit();

    try expectEqualStrings("ID", msg.command);
    try expect(msg.address == null);
    try expectEqual(0, msg.args.len);
}

test "it parses addressed commands" {
    const msg = try FastMessage.parse(testingAllocator, "ID@B4:");
    defer msg.deinit();

    try expectEqualStrings("ID", msg.command);
    try expectEqualStrings("B4", msg.address.?);
    try expectEqual(0, msg.args.len);
}

test "it parses a single arg" {
    const msg = try FastMessage.parse(testingAllocator, "WD:P");
    defer msg.deinit();

    try expectEqualStrings("WD", msg.command);
    try expectEqual(1, msg.args.len);
    try expectEqualStrings("P", msg.args[0]);
}

test "it parses multiple args" {
    const msg = try FastMessage.parse(testingAllocator, "DL:80,90,02,34");
    defer msg.deinit();

    try expectEqualStrings("DL", msg.command);
    try expectEqual(4, msg.args.len);
    try expectEqualStrings("80", msg.args[0]);
    try expectEqualStrings("90", msg.args[1]);
    try expectEqualStrings("02", msg.args[2]);
    try expectEqualStrings("34", msg.args[3]);
}
