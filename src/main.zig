const rl = @import("raylib");
const std = @import("std");
const mazes = @import("mazes.zig");
const Room = mazes.Room;

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 1000; // mazes.TotalXSize * mazes.Scale;
    const screenHeight = 1000; //mazes.TotalYSize * mazes.Scale;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    // init stat
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var buf = try allocator.alloc(u8, 2000);
    _ = &buf;
    var board = try mazes.Board.init(allocator, 1234);
    defer board.dinit(allocator);

    try board.testFF(allocator);

    var camera = rl.Camera3D{
        .position = rl.Vector3.init(4, 12, 4),
        .target = rl.Vector3.init(10, 1.8, 10),
        .up = rl.Vector3.init(0, 1, 0),
        .fovy = 60,
        .projection = rl.CameraProjection.camera_perspective,
    };

    rl.disableCursor();
    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        camera.update(rl.CameraMode.camera_first_person);
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------

        if (rl.isKeyPressed(rl.KeyboardKey.key_p)) {
            rl.takeScreenshot("result.png");
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_space)) {
            try board.testFF(allocator);
        }

        if (rl.isKeyDown(rl.KeyboardKey.key_q)) {
            camera.position.y -= 0.1;
        }

        if (rl.isKeyDown(rl.KeyboardKey.key_e)) {
            camera.position.y += 0.1;
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

            for (0..@min(mazes.TotalYSize, 100)) |y| {
                for (0..@min(mazes.TotalXSize, 100)) |x| {
                    const tag = board.board[y][x];
                    switch (tag) {
                        .blank => {},
                        else => {
                            const size: f32 = 1;
                            const nx: f32 = @as(f32, @floatFromInt(x)) * size;
                            const ny: f32 = @as(f32, @floatFromInt(y)) * size;
                            rl.drawCube(rl.Vector3.init(nx, 1, ny), size, size, size, rl.Color.black);
                            rl.drawCubeWires(rl.Vector3.init(nx, 1, ny), size, size, size, rl.Color.green);
                        },
                    }
                }
            }
        }

        //----------------------------------------------------------------------------------
    }
}
