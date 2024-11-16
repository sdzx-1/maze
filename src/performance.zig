const std = @import("std");
const mazes = @import("Maze.zig");
const Maze = mazes.Maze;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    try Maze.testPerformance(allocator);
}
