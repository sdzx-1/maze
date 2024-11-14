const std = @import("std");
const mazes = @import("mazes.zig");
const Room = mazes.Room;
const zigimg = @import("zigimg");
const rl = @import("raylib");

const colorList = [_]rl.Color{
    rl.Color.yellow,
    rl.Color.gold,
    rl.Color.orange,
    rl.Color.pink,
    rl.Color.red,
    rl.Color.green,
    rl.Color.lime,
    rl.Color.blue,
    rl.Color.dark_blue,
    rl.Color.purple,
    rl.Color.violet,
    rl.Color.beige,
};

fn colorToRgba32(color: rl.Color) zigimg.color.Rgba32 {
    return .{
        .r = color.r,
        .g = color.g,
        .b = color.b,
        .a = color.a,
    };
}

pub fn tagToColor(tag: mazes.Tag) rl.Color {
    return switch (tag) {
        .room => |i| colorList[@mod(i, colorList.len)],
        .blank => rl.Color.white,
        .path => |i| colorList[@mod(i, colorList.len)],
        .connPoint => rl.Color.black,
    };
}

pub fn main() anyerror!void {
    // Initialization
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var board = try mazes.Board.init(allocator, 1234);
    defer board.dinit(allocator);
    try board.genMazes(allocator);

    const image = try zigimg.Image.create(
        allocator,
        mazes.TotalXSize,
        mazes.TotalYSize,
        .rgba32,
    );
    var arr = image.pixels.rgba32;
    for (0..mazes.TotalYSize) |y| {
        for (0..mazes.TotalXSize) |x| {
            arr[x + y * mazes.TotalXSize] =
                colorToRgba32(tagToColor(board.board[y][x]));
        }
    }

    try image.writeToFilePath("my_new_image.png", .{
        .png = .{},
    });
}
