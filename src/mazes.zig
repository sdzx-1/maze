const std = @import("std");
const data = @import("data.zig");
const Stack = data.Stack;
const Queue = data.Queue;
const Allocator = std.mem.Allocator;
const Value = std.json.Value;
const Xoroshiro = std.Random.Xoroshiro128;

pub const IsTestPerformance = false;
// TotalXSize, TotalYSize 是奇数
pub const TotalXSize = if (IsTestPerformance) 2041 else 241;
pub const TotalYSize = if (IsTestPerformance) 2041 else 241;
pub const Scale = 1;
const RoomMaxSize = 7;

const Size = struct {
    xSize: i32,
    ySize: i32,
};

const Pos = struct {
    x: i32,
    y: i32,

    pub fn addDirection(self: Pos, dir: Direction) Pos {
        return Pos{
            .x = self.x + dir.dirX,
            .y = self.y + dir.dirY,
        };
    }
};

pub fn dirToI(dir: Direction) usize {
    if (dir.dirX == 1 and dir.dirY == 0) {
        return 0;
    } else if (dir.dirX == 0 and dir.dirY == -1) {
        return 1;
    } else if (dir.dirX == -1 and dir.dirY == 0) {
        return 2;
    } else if (dir.dirX == 0 and dir.dirY == 1) {
        return 3;
    }
    unreachable;
}

const Direction = struct {
    dirX: i32,
    dirY: i32,

    const Self = @This();

    pub fn init(dx: i32, dy: i32) Direction {
        return .{ .dirX = dx, .dirY = dy };
    }
    pub fn multiply_by_a_scalar(self: Self, s: i32) Direction {
        return Direction.init(self.dirX * s, self.dirY.s);
    }

    pub const Direction_of_widening_and_thickening = [4][3]Direction{
        [_]Direction{
            Direction{ .dirX = 1, .dirY = 0 },
            Direction{ .dirX = 1, .dirY = -1 },
            Direction{ .dirX = 1, .dirY = 1 },
        },

        [_]Direction{
            Direction{ .dirX = 0, .dirY = -1 },
            Direction{ .dirX = 1, .dirY = -1 },
            Direction{ .dirX = -1, .dirY = -1 },
        },

        [_]Direction{
            Direction{ .dirX = -1, .dirY = 0 },
            Direction{ .dirX = -1, .dirY = -1 },
            Direction{ .dirX = -1, .dirY = 1 },
        },

        [_]Direction{
            Direction{ .dirX = 0, .dirY = 1 },
            Direction{ .dirX = 1, .dirY = 1 },
            Direction{ .dirX = -1, .dirY = 1 },
        },
    };

    pub const Four_directions = [_]Direction{
        Direction{ .dirX = 1, .dirY = 0 },
        Direction{ .dirX = 0, .dirY = -1 },
        Direction{ .dirX = -1, .dirY = 0 },
        Direction{ .dirX = 0, .dirY = 1 },
    };
    pub const Eight_directions = [_]Direction{
        Direction{ .dirX = 1, .dirY = 0 },
        Direction{ .dirX = 1, .dirY = -1 },
        Direction{ .dirX = 0, .dirY = -1 },
        Direction{ .dirX = -1, .dirY = -1 },
        Direction{ .dirX = -1, .dirY = 0 },
        Direction{ .dirX = -1, .dirY = 1 },
        Direction{ .dirX = 0, .dirY = 1 },
        Direction{ .dirX = 1, .dirY = 1 },
    };
};

pub fn genRandomOdd(min: i32, max: i32, random: std.Random) i32 {
    var v = random.intRangeAtMost(i32, min, max);
    while (@mod(v, 2) == 0) {
        v = random.intRangeAtMost(i32, min, max);
    }
    return v;
}

// x,      y     是奇数至少从1开始
// xSize , ySize 是奇数至少从3开始
pub const Room = struct {
    pos: Pos,
    size: Size,

    const Self = @This();

    pub fn init(self: Self, pos: Pos, size: Size) void {
        self.pos = pos;
        self.size = size;
    }

    pub fn genRoom(random: std.Random) ?Self {
        const x = genRandomOdd(1, TotalXSize, random);
        const y = genRandomOdd(1, TotalYSize, random);

        const xsize = genRandomOdd(3, RoomMaxSize, random);
        const ysize = genRandomOdd(3, RoomMaxSize, random);

        if (x + xsize > TotalXSize or y + ysize > TotalYSize or
            xsize > 2 * ysize or ysize > 2 * xsize or
            (xsize == 3 and ysize == 3)) return null;

        return .{
            .pos = .{ .x = x, .y = y },
            .size = .{ .xSize = xsize, .ySize = ysize },
        };
    }
};

pub const Tag = union(enum) {
    room: usize,
    blank,
    path: usize,
    connPoint: [2]usize,
};

pub const Index = struct {
    x: i32,
    y: i32,

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

    pub inline fn inBoard(self: Index) bool {
        if (self.x < 0 or self.x >= TotalXSize or self.y < 0 or self.y >= TotalYSize) {
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

pub const IndexAndDirection = struct {
    index: Index,
    direction: Direction,
};

const Stage = enum {
    generateRoom,
    floodFill,
    findConnPoint,
    generateTree,
    removeSingle,
    totalTime,

    const Self = @This();

    pub fn show(self: Self) [:0]const u8 {
        switch (self) {
            .generateRoom => return "generateRoom",
            .floodFill => return "floodFill",
            .findConnPoint => return "findConnPoint",
            .generateTree => return "generateTree",
            .removeSingle => return "removeSing",
            .totalTime => return "totalTime",
        }
    }

    pub inline fn to_usize(self: Self) usize {
        return @intFromEnum(self);
    }
};

const StageTimeList = [@typeInfo(Stage).@"enum".fields.len]i64;

const StageTimeMap = struct {
    list: StageTimeList,

    const Self = @This();

    pub fn clean(self: *Self) void {
        for (0..self.list.len) |i| {
            self.list[i] = 0;
        }
    }

    pub fn put(self: *Self, key: Stage, val: i64) void {
        self.list[key.to_usize()] = val;
    }

    pub fn get(self: *const Self, key: Stage) i64 {
        return self.list[key.to_usize()];
    }
};

const IdConnPoints = std.AutoHashMap(usize, std.ArrayList(Index));
const SelectedIds = std.AutoHashMap(usize, void);
const SelectedConnPoints = std.AutoHashMap(Index, void);
const RoomList = std.ArrayList(Room);
const GenRoomMaxTestTimes = TotalXSize * TotalYSize / 2;

pub const Board = struct {
    board: *[TotalYSize][TotalXSize]Tag,
    roomList: RoomList,
    idConnPoints: IdConnPoints,
    stageTimeMap: StageTimeMap,
    globalCounter: usize,
    xoroshiro: Xoroshiro,

    const Self = @This();

    pub fn init(allocator: Allocator, seed: u64) !Board {
        const board = try allocator.create([TotalYSize][TotalXSize]Tag);
        const roomList = RoomList.init(allocator);
        const idcp = IdConnPoints.init(allocator);
        const xx = Xoroshiro.init(seed);
        return Board{
            .board = board,
            .roomList = roomList,
            .idConnPoints = idcp,
            .stageTimeMap = undefined,
            .globalCounter = 0,
            .xoroshiro = xx,
        };
    }

    pub inline fn writeBoard(self: *Self, idx: Index, tag: Tag) void {
        self.board[@as(usize, @intCast(idx.y))][@as(usize, @intCast(idx.x))] = tag;
    }

    pub inline fn readBoard(self: *const Self, idx: Index) Tag {
        return self.board[@as(usize, @intCast(idx.y))][@as(usize, @intCast(idx.x))];
    }
    pub fn idConnPointsInsert(self: *Self, a: usize, b: Index, allocator: Allocator) !void {
        if (self.idConnPoints.getPtr(a)) |hmp| {
            try hmp.append(b);
        } else {
            var thmp = std.ArrayList(Index).init(allocator);
            try thmp.append(b);
            try self.idConnPoints.put(a, thmp);
        }
    }

    pub fn dinit(self: *Self, allocator: Allocator) void {
        var iter2 = self.idConnPoints.valueIterator();
        while (iter2.next()) |v| {
            v.clearAndFree();
        }
        self.idConnPoints.deinit();
        self.stageTimeMap.clean();
        self.roomList.deinit();
        allocator.destroy(self.board);
    }

    pub fn genMazes(self: *Self, allocator: Allocator) !void {
        {
            self.cleanBoard();
            self.globalCounter = 0;

            var iter2 = self.idConnPoints.valueIterator();
            while (iter2.next()) |v| {
                v.clearAndFree();
            }
            self.idConnPoints.clearAndFree();
            self.stageTimeMap.clean();
            self.roomList.clearAndFree();
        }

        if (IsTestPerformance) self.xoroshiro.seed(1234);
        const random = self.xoroshiro.random();

        const t2 = std.time.milliTimestamp();
        try self.genRoomList(random);
        const t3 = std.time.milliTimestamp();
        self.stageTimeMap.put(.generateRoom, t3 - t2);

        const t4 = std.time.milliTimestamp();
        var stack = Stack(IndexAndDirection).init(allocator);
        defer stack.clean();
        for (1..TotalYSize) |y| {
            for (1..TotalXSize) |x| {
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
        const v: usize = @intCast(random.intRangeAtMost(i32, 0, rsize - 1));
        const troom = self.roomList.items[v];
        const kx: usize = @intCast(troom.pos.x);
        const ky: usize = @intCast(troom.pos.y);
        const rid = self.board[ky][kx].room;

        try selecIds.put(rid, {});
        for (self.idConnPoints.get(rid).?.items) |value| {
            try selecConnPoints.put(value, {});
        }
        try self.genTree(
            &selecIds,
            &selecConnPoints,
            random,
        );
        const t9 = std.time.milliTimestamp();
        self.stageTimeMap.put(.generateTree, t9 - t8);

        const t10 = std.time.milliTimestamp();
        for (1..TotalYSize) |y| {
            for (1..TotalXSize) |x| {
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

        if (IsTestPerformance) {
            try recordPerformance(self, allocator);
        }
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

    pub fn genRoomList(self: *Self, random: std.Random) !void {
        blk: for (0..GenRoomMaxTestTimes) |_| {
            if (Room.genRoom(random)) |room| {
                const ty: usize = @intCast(room.pos.y);
                const tx: usize = @intCast(room.pos.x);
                for (0..@intCast(room.size.ySize)) |dy| {
                    for (0..@intCast(room.size.xSize)) |dx| {
                        if (self.board[ty + dy][tx + dx] != .blank) continue :blk;
                    }
                }
                try self.roomList.append(room);
                self.globalCounter += 1;

                for (0..@intCast(room.size.ySize)) |dy| {
                    for (0..@intCast(room.size.xSize)) |dx| {
                        self.board[ty + dy][tx + dx] =
                            .{ .room = self.globalCounter };
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
                    if (!nIdx.inBoard()) continue;
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
        random: std.Random,
    ) !void {
        while (sConnPointSet.count() != 0) {
            var iter = sConnPointSet.keyIterator();
            const sedConnIndex = iter.next().?.*;
            const tmpv = self.readBoard(sedConnIndex).connPoint;
            var newId: usize = undefined;
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
                    _ = sConnPointSet.remove(cp);
                    if (cp.eq(sedConnIndex)) {} else {
                        const tmpk = random.intRangeAtMost(i32, 1, 100);
                        if (tmpk > 97) {} else {
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
        for (1..TotalYSize) |y| {
            for (1..TotalXSize) |x| {
                const idx = Index.from_uszie_xy(x, y);
                if (self.readBoard(idx) != .blank) continue;
                var result: i32 = 0;
                var idArr: [4]usize = undefined;
                var idIndex: usize = 0;
                for (Direction.Four_directions) |dir| {
                    const nIdx = idx.addDirection(dir);
                    if (!nIdx.inBoard()) continue;
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
                        else => result += 0,
                    }
                }

                if (result >= 101) {
                    const v0 = idArr[0];
                    const v1 = idArr[1];

                    const tArr = [2]usize{
                        @min(v0, v1),
                        @max(v0, v1),
                    };
                    try self.idConnPointsInsert(v0, idx, allocator);
                    try self.idConnPointsInsert(v1, idx, allocator);

                    self.board[y][x] = .{ .connPoint = tArr };
                }
            }
        }
    }

    pub fn floodFilling(self: *Self, stack: *Stack(IndexAndDirection)) !void {
        const K = Direction.Direction_of_widening_and_thickening;
        blk0: while (stack.pop()) |start| {
            if (self.readBoard(start.index) != .blank) continue;
            const ti = dirToI(start.direction);
            const tdirs = K[ti];

            for (tdirs) |dir| {
                const nIndex = start.index.addDirection(dir);
                if (!nIndex.inBoard()) continue :blk0;
                if (self.readBoard(nIndex) != .blank) continue :blk0;
            }

            self.writeBoard(start.index, .{ .path = self.globalCounter });

            for (0..4) |i| {
                const dirs = K[@mod(ti + i + 1, 4)];
                const dir = dirs[0];
                const nIndex = start.index.addDirection(dir);
                if (!nIndex.inBoard()) continue;
                if (self.readBoard(nIndex) != .blank) continue;
                const np = start.index.addDirection(dir);
                try stack.push(.{ .index = np, .direction = dir });
            }
        }
    }

    // Check if the surrounding eight positions are blank
    pub fn checkSurrEight(self: *const Self, index: Index) bool {
        if (self.readBoard(index) != .blank) return false;
        for (Direction.Eight_directions) |dir| {
            const nIndex = index.addDirection(dir);
            if (!nIndex.inBoard()) return false;
            if (self.readBoard(nIndex) != .blank) return false;
        }
        return true;
    }

    fn cleanBoard(self: *Self) void {
        for (0..TotalYSize) |y| {
            for (0..TotalXSize) |x| {
                self.board[y][x] = .blank;
            }
        }
    }
};

pub fn mosPosToIndex(x: i32, y: i32) Index {
    const vx: usize = @intCast(@divTrunc(x, Scale));
    const vy: usize = @intCast(@divTrunc(y, Scale));
    return .{ .x = vx, .y = vy };
}

test "boadr" {
    const allocator = std.testing.allocator;
    var board = try Board.init(allocator);
    defer board.dinit(allocator);
    try board.genMazes(allocator);
}
