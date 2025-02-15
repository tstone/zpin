const std = @import("std");
const fast = @import("./fast/fast_message.zig");

pub fn main() void {
    std.debug.print("Hello, {s}!\n", .{"Zig Build"});
}
