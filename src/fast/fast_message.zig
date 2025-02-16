const std = @import("std");
const Allocator = std.mem.Allocator;

/// A low level representation of a basic FAST Pinball serial
pub const FastMessage = struct {
    allocator: Allocator,
    command: []const u8,
    address: ?[]const u8,
    args: [][]const u8,

    pub fn init(allocator: Allocator, command: []const u8, address: ?[]const u8, args: [][]const u8) !FastMessage {
        const cmd = try allocator.alloc(u8, command.len);
        @memcpy(cmd, command);

        const arg_copy = try allocator.alloc([]const u8, args.len);
        for (args, 0..) |item, i| {
            const arg = try allocator.alloc(u8, item.len);
            @memcpy(arg, args[i]);
            arg_copy[i] = arg;
        }

        var addr: ?[]u8 = null;
        if (address != null) {
            const buffer = try allocator.alloc(u8, address.?.len);
            @memcpy(buffer, address.?);
            addr = buffer;
        }

        return FastMessage{
            .command = cmd,
            .address = addr,
            .args = arg_copy,
            .allocator = allocator,
        };
    }

    /// Parse an incoming message
    pub fn parse(allocator: Allocator, input: []const u8) !FastMessage {
        var cmd: []const u8 = undefined;
        var addr: ?[]const u8 = null;

        var root_iter = std.mem.splitScalar(u8, input, ':');
        if (root_iter.peek() != null) {
            var cmd_iter = std.mem.splitScalar(u8, root_iter.next().?, '@');
            cmd = cmd_iter.next().?;
            if (cmd_iter.peek() != null) {
                addr = cmd_iter.next().?;
            }
        }

        var arg_list = std.ArrayList([]const u8).init(allocator);
        defer arg_list.deinit();

        if (root_iter.peek() != null) {
            var args_iter = std.mem.splitScalar(u8, root_iter.next().?, ',');
            while (args_iter.next()) |arg| {
                if (arg.len > 0) {
                    try arg_list.append(arg);
                }
            }
        }

        return FastMessage.init(allocator, cmd, addr, arg_list.items);

        // const args = try allocator.alloc([]const u8, arg_list.items.len);
        // @memcpy(args, arg_list.items);

        // return FastMessage{
        //     .command = cmd,
        //     .address = addr,
        //     .args = args,
        //     .allocator = allocator,
        // };
    }

    fn deinit(message: FastMessage) void {
        message.allocator.free(message.command);

        for (message.args) |arg| {
            message.allocator.free(arg);
        }
        message.allocator.free(message.args);

        if (message.address != null) {
            message.allocator.free(message.address.?);
        }
    }
};

// ---

const test_allocator = std.testing.allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

test "it parses bare commands" {
    const msg = try FastMessage.parse(test_allocator, "ID:");
    defer msg.deinit();

    try expectEqualStrings("ID", msg.command);
    try expect(msg.address == null);
    try expectEqual(0, msg.args.len);
}

test "it parses addressed commands" {
    const msg = try FastMessage.parse(test_allocator, "ID@B4:");
    defer msg.deinit();

    try expectEqualStrings("ID", msg.command);
    try expectEqualStrings("B4", msg.address.?);
    try expectEqual(0, msg.args.len);
}

test "it parses a single arg" {
    const msg = try FastMessage.parse(test_allocator, "WD:P");
    defer msg.deinit();

    try expectEqualStrings("WD", msg.command);
    try expectEqual(1, msg.args.len);
    try expectEqualStrings("P", msg.args[0]);
}

test "it parses multiple args" {
    const msg = try FastMessage.parse(test_allocator, "DL:80,90,02,34");
    defer msg.deinit();

    try expectEqualStrings("DL", msg.command);
    try expectEqual(4, msg.args.len);
    try expectEqualStrings("80", msg.args[0]);
    try expectEqualStrings("90", msg.args[1]);
    try expectEqualStrings("02", msg.args[2]);
    try expectEqualStrings("34", msg.args[3]);
}

test "it allocates it's own copy" {
    var list = std.ArrayList(u8).init(test_allocator);
    try list.appendSlice("ID:X");

    const msg = try FastMessage.parse(test_allocator, list.items);
    defer msg.deinit();

    list.clearAndFree();
    try expectEqualStrings("ID", msg.command);
    try expectEqual(1, msg.args.len);
    try expectEqualStrings("X", msg.args[0]);
}
