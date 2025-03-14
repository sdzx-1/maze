const rl = @import("raylib");
const std = @import("std");
const Maze = @import("maze").Maze;
const data = @import("maze").data;
const Room = data.Room;
const Allocator = std.mem.Allocator;

const Color = rl.Color;

const colorList = [_]rl.Color{
    Color.blank,
    Color.gray,
    Color.dark_gray,
    Color.yellow,
    Color.gold,
    Color.orange,
    Color.pink,
    Color.red,
    Color.maroon,
    Color.green,
    Color.lime,
    Color.dark_green,
    Color.sky_blue,
    Color.blue,
    Color.dark_blue,
    Color.purple,
    Color.violet,
    Color.dark_purple,
    Color.beige,
    Color.brown,
    Color.dark_brown,
    Color.magenta,
    Color.ray_white,
};

pub fn tagToColor(tag: Maze.Tag) Color {
    return switch (tag) {
        .room => |i| colorList[@mod(i, colorList.len)],
        .blank => Color.white,
        .path => |i| colorList[@mod(i, colorList.len)],
        .connPoint => Color.black,
    };
}

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 1000; // mazes.TotalXSize * mazes.Scale;
    const screenHeight = 1000; //mazes.TotalYSize * mazes.Scale;

    rl.initWindow(screenWidth, screenHeight, "mazes");
    defer rl.closeWindow(); // Close window and OpenGL context

    // init stat
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var board = try Maze.init(
        allocator,
        81,
        81,
        3,
        7,
        0.03,
        1234,
    );
    defer board.deinit(allocator);

    try board.genMaze(allocator);

    var camera = rl.Camera3D{
        .position = rl.Vector3.init(0, 10, 5),
        .target = rl.Vector3.init(0, 0, 0),
        .up = rl.Vector3.init(0, 1, 0),
        .fovy = 60,
        .projection = rl.CameraProjection.perspective,
    };

    rl.disableCursor();
    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        camera.update(rl.CameraMode.first_person);
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------

        if (rl.isKeyPressed(rl.KeyboardKey.p)) {
            rl.takeScreenshot("result.png");
        }

        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            try board.genMaze(allocator);
        }

        if (rl.isKeyDown(rl.KeyboardKey.q)) {
            camera.position.y -= 0.5;
        }

        if (rl.isKeyDown(rl.KeyboardKey.e)) {
            camera.position.y += 0.5;
        }
        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);
        {
            camera.begin();
            defer camera.end();
            // Draw ground
            rl.drawPlane(rl.Vector3.init(0, 0, 0), rl.Vector2.init(6400, 6400), rl.Color.light_gray);

            for (0..241) |dy| {
                for (0..241) |dx| {
                    const x = @as(i32, @intCast(dx));
                    const y = @as(i32, @intCast(dy));
                    const idx = Maze.Index{ .x = x, .y = y };
                    if (!idx.inBoard(&board)) continue;
                    const tag = board.readBoard(idx);
                    switch (tag) {
                        .blank => {},
                        else => {
                            const size: f32 = 0.3;
                            const nx: f32 = @as(f32, @floatFromInt(x)) * size;
                            const ny: f32 = @as(f32, @floatFromInt(y)) * size;
                            rl.drawCube(
                                rl.Vector3.init(nx, 1, ny),
                                size,
                                size,
                                size,
                                tagToColor(tag),
                            );
                            rl.drawCubeWires(
                                rl.Vector3.init(nx, 1, ny),
                                size,
                                size,
                                size,
                                rl.Color.black,
                            );
                        },
                    }
                }
            }
        }

        //----------------------------------------------------------------------------------
    }
}
