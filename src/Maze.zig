const std = @import("std");
const data = @import("data.zig");
const Stack = data.Stack;
const Queue = data.Queue;
const Allocator = std.mem.Allocator;
const Value = std.json.Value;
const Xoroshiro = std.Random.Xoroshiro128;
const Pos = data.Pos;
const Size = data.Size;
const Direction = data.Direction;
const StageTimeMap = data.StageTimeMap;
const StageTimeList = data.StageTimeList;
const Stage = data.Stage;
pub const Maze = @This();

pub const Room = struct {
    // x,      y     是奇数至少从1开始
    pos: Pos,
    // xSize , ySize 是奇数至少从3开始
    size: Size,

    pub fn genRoom(maze: *const Maze) ?Room {
        const x = data.genRandomOdd(1, @as(i32, @intCast(maze.totalXSize)), maze.random);
        const y = data.genRandomOdd(1, @as(i32, @intCast(maze.totalYSize)), maze.random);

        const xsize = data.genRandomOdd(maze.roomMinSize, maze.roomMaxSize, maze.random);
        const ysize = data.genRandomOdd(maze.roomMinSize, maze.roomMaxSize, maze.random);

        if (x + xsize > maze.totalXSize or y + ysize > maze.totalYSize or
            xsize > 2 * ysize or ysize > 2 * xsize) return null;

        return .{
            .pos = .{ .x = x, .y = y },
            .size = .{ .xSize = xsize, .ySize = ysize },
        };
    }
};
pub const Tag = union(enum) {
    room: u32,
    blank,
    path: u32,
    connPoint: [2]u32,
};

const IdConnPoints = std.AutoArrayHashMap(u32, std.ArrayList(Index));
const SelectedIds = std.AutoArrayHashMap(u32, void);
const SelectedConnPoints = std.AutoArrayHashMap(Index, void);
const RoomList = std.ArrayList(Room);

// TotalXSize, TotalYSize 是奇数
totalXSize: u32,
totalYSize: u32,
roomMaxSize: i32,
roomMinSize: i32,
genRoomMaxTestTimes: u32, // TotalXSize * TotalYSize / 2,
// The probability of redundant connection points being retained
probability: f32,
board: []Tag,
roomList: RoomList,
idConnPoints: IdConnPoints,
stageTimeMap: StageTimeMap,
globalCounter: u32,
xoroshiro: Xoroshiro,
random: std.Random,

const Self = @This();

pub fn init(
    allocator: Allocator,
    totalXSize: u32,
    totalYSize: u32,
    roomMinSize: i32,
    roomMaxSize: i32,
    probability: f32,
    seed: u64,
) !Maze {
    if (isEven(totalXSize)) return error.TotalXSize_Need_Odd;
    if (isEven(totalYSize)) return error.TotalYSize_Need_Odd;
    if (roomMinSize < 3) return error.RoomMinSize_Must_Greater_Than_2;
    if (roomMaxSize <= roomMinSize) return error.RoomMaxSize_Must_Greater_Than_RoomMinSize;
    const board = try allocator.alloc(Tag, totalXSize * totalYSize);
    const roomList = RoomList.init(allocator);
    const idcp = IdConnPoints.init(allocator);
    const xx = Xoroshiro.init(seed);
    var stru: Self = .{
        .totalXSize = totalXSize,
        .totalYSize = totalYSize,
        .roomMinSize = roomMinSize,
        .roomMaxSize = roomMaxSize,
        .probability = probability,
        .genRoomMaxTestTimes = totalXSize * totalYSize / 2,
        .board = board,
        .roomList = roomList,
        .idConnPoints = idcp,
        .stageTimeMap = undefined,
        .globalCounter = 0,
        .xoroshiro = xx,
        .random = undefined,
    };
    stru.random = stru.xoroshiro.random();
    return stru;
}

pub inline fn writeBoard(self: *Self, idx: Index, tag: Tag) void {
    self.board[idx.toPoint(self)] = tag;
}

pub inline fn readBoard(self: *const Self, idx: Index) Tag {
    return self.board[idx.toPoint(self)];
}
pub fn idConnPointsInsert(self: *Self, a: u32, b: Index, allocator: Allocator) !void {
    if (self.idConnPoints.getPtr(a)) |hmp| {
        try hmp.append(b);
    } else {
        var thmp = std.ArrayList(Index).init(allocator);
        try thmp.append(b);
        try self.idConnPoints.put(a, thmp);
    }
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    var iter2 = self.idConnPoints.iterator();
    while (iter2.next()) |v| {
        v.value_ptr.clearAndFree();
    }
    self.idConnPoints.deinit();
    self.stageTimeMap.clean();
    self.roomList.deinit();
    allocator.free(self.board);
}

pub fn genMaze(self: *Self, allocator: Allocator) !void {
    {
        self.cleanBoard();
        self.globalCounter = 0;

        var iter2 = self.idConnPoints.iterator();
        while (iter2.next()) |v| {
            v.value_ptr.clearAndFree();
        }
        self.idConnPoints.clearAndFree();
        self.stageTimeMap.clean();
        self.roomList.clearAndFree();
    }

    const t2 = std.time.milliTimestamp();
    try self.genRoomList();
    const t3 = std.time.milliTimestamp();
    self.stageTimeMap.put(.generateRoom, t3 - t2);
    const tmpRooms = self.globalCounter;
    std.debug.print("rooms: {d}\n", .{tmpRooms});

    const t4 = std.time.milliTimestamp();
    var stack = Stack(IndexAndDirection).init(allocator);
    defer stack.clean();
    for (1..self.totalYSize) |y| {
        for (1..self.totalXSize) |x| {
            const index = Index.from_uszie_xy(x, y);
            if (checkSurrEight(self, index)) {
                stack.clean();
                try stack.push(.{
                    .index = index,
                    .direction = .{ .dirX = 1, .dirY = 0 },
                });
                self.globalCounter += 1;
                try self.floodFilling(&stack);
            }
        }
    }
    const t5 = std.time.milliTimestamp();
    self.stageTimeMap.put(.floodFill, t5 - t4);
    std.debug.print("path: {d}\n", .{self.globalCounter - tmpRooms});

    const t6 = std.time.milliTimestamp();
    try findConnPoint(self, allocator);
    const t7 = std.time.milliTimestamp();
    self.stageTimeMap.put(.findConnPoint, t7 - t6);

    const t8 = std.time.milliTimestamp();
    var selecIds = SelectedIds.init(allocator);
    defer selecIds.deinit();
    var selecConnPoints = SelectedConnPoints.init(allocator);
    defer selecConnPoints.deinit();

    const rsize: i32 = @intCast(self.roomList.items.len);
    const v: usize = @intCast(self.random.intRangeAtMost(i32, 0, rsize - 1));
    const troom = self.roomList.items[v];
    const kx: usize = @intCast(troom.pos.x);
    const ky: usize = @intCast(troom.pos.y);
    const rid = self.readBoard(Index.from_uszie_xy(kx, ky)).room;

    try selecIds.put(rid, {});
    for (self.idConnPoints.get(rid).?.items) |value| {
        try selecConnPoints.put(value, {});
    }
    try self.genTree(
        &selecIds,
        &selecConnPoints,
    );
    const t9 = std.time.milliTimestamp();
    self.stageTimeMap.put(.generateTree, t9 - t8);

    const t10 = std.time.milliTimestamp();
    for (1..self.totalYSize) |y| {
        for (1..self.totalXSize) |x| {
            var idx = Index.from_uszie_xy(x, y);
            while (self.surrSum(idx)) |nIdx| {
                idx = nIdx;
            }
        }
    }
    const t11 = std.time.milliTimestamp();
    self.stageTimeMap.put(.removeSingle, t11 - t10);

    self.stageTimeMap.put(.totalTime, t11 - t2);

    const totalTime: f32 = @floatFromInt(self.stageTimeMap.get(.totalTime));

    std.debug.print("=============\n", .{});
    for (0..self.stageTimeMap.list.len) |i| {
        const t: Stage = @enumFromInt(i);
        switch (t) {
            .totalTime => {},
            else => {
                const vv: f64 = @floatFromInt(self.stageTimeMap.list[i]);
                std.debug.print(
                    "p: {d:.2}, val: {d}ms, key: {s}\n",
                    .{ vv / totalTime, vv, t.show() },
                );
            },
        }
    }
    std.debug.print("total time: {d}ms\n", .{totalTime});
}

const Record = struct {
    time: i64,
    stageTimeList: StageTimeList,
};

pub fn recordPerformance(self: *const Self, allocator: Allocator) !void {
    const newRecord: Record = .{
        .time = std.time.timestamp(),
        .stageTimeList = self.stageTimeMap.list,
    };

    const path = "performance";
    const currDir = std.fs.cwd();
    var file: std.fs.File = undefined;
    defer file.close();
    currDir.access(path, .{}) catch {
        file = try currDir.createFile(
            path,
            .{},
        );
    };
    file = try currDir.openFile(path, .{ .mode = .read_write });
    var jReader = std.json.reader(allocator, file.reader());
    const pResult: ?std.json.Parsed([]Record) = std.json.parseFromTokenSource(
        []Record,
        allocator,
        &jReader,
        .{},
    ) catch |err| blk: {
        std.debug.print("err: {any}\n", .{err});
        break :blk null;
    };

    if (pResult) |res| {
        defer res.deinit();
        const v0 = res.value;
        // defer allocator.free(v0);
        var arr1 = try allocator.alloc(Record, v0.len + 1);
        defer allocator.free(arr1);
        arr1[v0.len] = newRecord;
        for (0..v0.len) |i| {
            arr1[i] = v0[i];
        }

        try file.seekTo(0);
        try std.json.stringify(
            arr1,
            .{},
            file.writer(),
        );

        const lastSL = v0[v0.len - 1].stageTimeList;
        const currSL = self.stageTimeMap.list;

        for (0..currSL.len) |i| {
            const tag: Stage = @enumFromInt(i);
            const diff: i64 = currSL[i] - lastSL[i];
            const p: f64 = @as(f64, @floatFromInt(diff)) / @as(f64, @floatFromInt(lastSL[i]));
            std.debug.print("p: {d:.0}%, diff: {d}ms, {s}\n", .{ p * 100, diff, tag.show() });
        }
    } else {
        try file.seekTo(0);
        try std.json.stringify(
            [1]Record{newRecord},
            .{},
            file.writer(),
        );
    }
}

pub fn genRoomList(self: *Self) !void {
    blk: for (0..self.genRoomMaxTestTimes) |_| {
        if (Room.genRoom(self)) |room| {
            const ty: usize = @intCast(room.pos.y);
            const tx: usize = @intCast(room.pos.x);
            for (0..@intCast(room.size.ySize)) |dy| {
                for (0..@intCast(room.size.xSize)) |dx| {
                    const idx = Index.from_uszie_xy(tx + dx, ty + dy);
                    if (self.readBoard(idx) != .blank) continue :blk;
                }
            }
            try self.roomList.append(room);
            self.globalCounter += 1;

            for (0..@intCast(room.size.ySize)) |dy| {
                for (0..@intCast(room.size.xSize)) |dx| {
                    const idx = Index.from_uszie_xy(tx + dx, ty + dy);
                    self.writeBoard(idx, .{ .room = self.globalCounter });
                }
            }
        }
    }
}

pub fn surrSum(self: *Self, idx: Index) ?Index {
    switch (self.readBoard(idx)) {
        .blank, .room => return null,
        .path, .connPoint => {
            var total: i32 = 0;
            var tmp: Index = undefined;
            for (Direction.Four_directions) |dir| {
                const nIdx = idx.addDirection(dir);
                if (!nIdx.inBoard(self)) continue;
                switch (self.readBoard(nIdx)) {
                    .room, .path, .connPoint => {
                        tmp = nIdx;
                        total += 1;
                    },
                    .blank => {},
                }
            }
            if (total == 1) {
                self.writeBoard(idx, .blank);
                return tmp;
            }
            return null;
        },
    }
}

pub fn genTree(
    self: *Self,
    sIdSet: *SelectedIds,
    sConnPointSet: *SelectedConnPoints,
) !void {
    while (sConnPointSet.count() != 0) {
        const keys = sConnPointSet.keys();
        const ti = self.random.intRangeAtMost(usize, 0, keys.len - 1);
        const sedConnIndex = keys[ti];
        const tmpv = self.readBoard(sedConnIndex).connPoint;
        var newId: u32 = undefined;
        if (sIdSet.get(tmpv[0])) |_| {
            newId = tmpv[1];
        } else if (sIdSet.get(tmpv[1])) |_| {
            newId = tmpv[0];
        } else {
            unreachable;
        }

        const connPs = self.idConnPoints.get(newId).?;
        for (connPs.items) |cp| {
            if (sConnPointSet.get(cp)) |_| {
                _ = sConnPointSet.swapRemove(cp);
                if (cp.eq(sedConnIndex)) {} else {
                    const t1 = self.random.float(f32);
                    if (t1 < self.probability) {} else {
                        self.writeBoard(cp, .blank);
                    }
                }
            } else {
                try sConnPointSet.put(cp, {});
            }
        }
        try sIdSet.put(newId, {});
    }
}

pub fn findConnPoint(self: *Self, allocator: Allocator) !void {
    for (1..self.totalYSize) |y| {
        for (1..self.totalXSize) |x| {
            const idx = Index.from_uszie_xy(x, y);
            if (self.readBoard(idx) != .blank) continue;
            var result: i32 = 0;
            var idArr: [4]usize = undefined;
            var idIndex: usize = 0;
            for (Direction.Four_directions) |dir| {
                const nIdx = idx.addDirection(dir);
                if (!nIdx.inBoard(self)) continue;
                switch (self.readBoard(nIdx)) {
                    .room => |r| {
                        idArr[idIndex] = r;
                        idIndex += 1;
                        result += 100;
                    },
                    .path => |r| {
                        idArr[idIndex] = r;
                        idIndex += 1;
                        result += 1;
                    },
                    .connPoint => |_| {
                        result += 3;
                    },
                    else => result += 0,
                }
            }

            if (result == 101 or result == 200) {
                const v0: u32 = @intCast(idArr[0]);
                const v1: u32 = @intCast(idArr[1]);

                const tArr = [2]u32{
                    @min(v0, v1),
                    @max(v0, v1),
                };
                try self.idConnPointsInsert(v0, idx, allocator);
                try self.idConnPointsInsert(v1, idx, allocator);

                self.writeBoard(Index.from_uszie_xy(x, y), .{ .connPoint = tArr });
            }
        }
    }
}

pub fn floodFilling(self: *Self, stack: *Stack(IndexAndDirection)) !void {
    blk0: while (stack.pop()) |start| {
        const ti = start.direction.toIndex();
        const tdirs = Direction.Direction_of_widening_and_thickening[ti];

        for (tdirs) |dir| {
            const nIndex = start.index.addDirection(dir);
            if (!nIndex.inBoard(self)) continue :blk0;
            if (self.readBoard(nIndex) != .blank) continue :blk0;
        }

        self.writeBoard(start.index, .{ .path = self.globalCounter });

        for (0..2) |i| {
            const dirs = Direction.Direction_of_widening_and_thickening[@mod(ti + i * 2 + 1, 4)];
            const dir = dirs[0];
            const nIndex = start.index.addDirection(dir);
            if (!nIndex.inBoard(self)) continue;
            if (self.readBoard(nIndex) != .blank) continue;
            const np = start.index.addDirection(dir);
            try stack.push(.{ .index = np, .direction = dir });
        }
        try stack.push(.{
            .index = start.index.addDirection(start.direction),
            .direction = start.direction,
        });
    }
}

// Check if the surrounding eight positions are blank
pub fn checkSurrEight(self: *const Self, index: Index) bool {
    if (self.readBoard(index) != .blank) return false;
    for (Direction.Eight_directions) |dir| {
        const nIndex = index.addDirection(dir);
        if (!nIndex.inBoard(self)) return false;
        if (self.readBoard(nIndex) != .blank) return false;
    }
    return true;
}

fn cleanBoard(self: *Self) void {
    for (0..self.totalYSize) |y| {
        for (0..self.totalXSize) |x| {
            const idx = Index.from_uszie_xy(x, y);
            self.writeBoard(idx, .blank);
        }
    }
}

pub const Index = struct {
    x: i32,
    y: i32,

    pub inline fn init(x: i32, y: i32) Index {
        return .{ .x = x, .y = y };
    }

    pub inline fn toPoint(self: Index, maze: *const Maze) usize {
        return @intCast(self.x + self.y * @as(i32, @intCast(maze.totalXSize)));
    }

    pub inline fn eq(self: Index, other: Index) bool {
        if (self.x == other.x and self.y == other.y) {
            return true;
        } else {
            return false;
        }
    }

    pub inline fn from_uszie_xy(x: usize, y: usize) Index {
        return .{ .x = @intCast(x), .y = @intCast(y) };
    }

    pub inline fn inBoard(self: Index, maze: *const Maze) bool {
        if (self.x < 0 or self.x >= maze.totalXSize or self.y < 0 or self.y >= maze.totalYSize) {
            return false;
        } else {
            return true;
        }
    }

    pub inline fn addDirection(self: Index, di: Direction) Index {
        return .{
            .x = di.dirX + self.x,
            .y = di.dirY + self.y,
        };
    }
};

fn isEven(v: u32) bool {
    return if (@mod(v, 2) == 0) true else false;
}

pub const IndexAndDirection = struct {
    index: Index,
    direction: Direction,
};

test "boadr" {
    const allocator = std.testing.allocator;
    var b1 = try Maze.init(allocator, 51, 41, 3, 8, 0.31, 12345);
    defer b1.deinit(allocator);
    try b1.genMazes(allocator);
    printMaze(&b1);
}

fn printMaze(self: *const Maze) void {
    for (0..self.totalYSize) |y| {
        for (0..self.totalXSize) |x| {
            const idx = Index.from_uszie_xy(x, y);
            const val = self.readBoard(idx);
            const st = switch (val) {
                .room => "x",
                .path => "+",
                .connPoint => "?",
                else => " ",
            };
            std.debug.print("{s} ", .{st});
        }
        std.debug.print("\n", .{});
    }
}

pub fn testPerformance(allocator: Allocator) !void {
    var maze = try Maze.init(allocator, 2041, 2041, 3, 7, 0.03, 234);
    defer maze.deinit(allocator);
    try maze.genMaze(allocator);
    try maze.recordPerformance(allocator);
}
