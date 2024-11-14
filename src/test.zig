const std = @import("std");
const mazes = @import("mazes.zig");
const Room = mazes.Room;

pub fn main() anyerror!void {
    // Initialization
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var board = try mazes.Board.init(allocator, 1234);
    defer board.dinit(allocator);
    try board.testFF(allocator);
}
