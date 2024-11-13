const rl = @import("raylib");
const std = @import("std");
// room

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

// TotalXSize, TotalYSize 是奇数
pub const TotalXSize = 61;
pub const TotalYSize = 61;
pub const Scale = 30;
const RoomMaxSize = 7;

const C = rl.Color;
const allColor = [_]rl.Color{
    C.dark_gray,
    C.yellow,
    C.gold,
    C.orange,
    C.pink,
    C.red,
    C.maroon,
    C.lime,
    C.sky_blue,
    C.dark_blue,
    C.purple,
    C.violet,
    C.dark_purple,
    C.beige,
    C.brown,
    C.dark_brown,
    C.magenta,
};

pub fn genRandomColor() C {
    const ci: usize = @intCast(rl.getRandomValue(0, allColor.len - 1));
    return allColor[ci];
}

pub fn genRandomOdd(min: i32, max: i32) i32 {
    var v = rl.getRandomValue(min, max);
    while (@mod(v, 2) == 0) {
        v = rl.getRandomValue(min, max);
    }
    return v;
}

// x,      y     是奇数至少从1开始
// xSize , ySize 是奇数至少从3开始
pub const Room = struct {
    pos: Pos,
    size: Size,
    color: rl.Color,

    const Self = @This();

    pub fn init(self: Self, pos: Pos, size: Size) void {
        self.pos = pos;
        self.size = size;
    }

    pub fn draw(self: Self, buf: []u8) !void {
        rl.drawRectangle(
            self.pos.x * Scale,
            self.pos.y * Scale,
            self.size.xSize * Scale,
            self.size.ySize * Scale,
            rl.Color.gray,
        );
        const st = try std.fmt.bufPrintZ(
            buf,
            "{d} {d}",
            .{ self.size.xSize, self.size.ySize },
        );

        rl.drawText(
            st,
            self.pos.x * Scale,
            self.pos.y * Scale,
            20,
            rl.Color.black,
        );
    }

    pub fn genRoom() ?Self {
        const x = genRandomOdd(1, TotalXSize);
        const y = genRandomOdd(1, TotalYSize);

        const xsize = genRandomOdd(3, RoomMaxSize);
        const ysize = genRandomOdd(3, RoomMaxSize);

        if (x + xsize > TotalXSize or y + ysize > TotalYSize or
            xsize > 2 * ysize or ysize > 2 * xsize or
            (xsize == 3 and ysize == 3)) return null;

        return .{
            .pos = .{ .x = x, .y = y },
            .size = .{ .xSize = xsize, .ySize = ysize },
            .color = genRandomColor(),
        };
    }

    pub fn room_intersection_test(self: Self, other: Room) bool {
        const vx = line_intersection_test(self.pos.x, self.size.xSize, other.pos.x, other.size.xSize);
        const vy = line_intersection_test(self.pos.y, self.size.ySize, other.pos.y, other.size.ySize);

        if (vx and vy) {
            return true;
        } else {
            return false;
        }
    }
};

fn line_intersection_test(x0: i32, x0size: i32, x1: i32, x1size: i32) bool {
    if (x0 + x0size < x1) {
        return false;
    } else if (x0 > x1 + x1size) {
        return false;
    } else {
        return true;
    }
}

pub const RoomList = std.ArrayList(Room);
pub const GenRoomMaxTestTimes = 13040;

pub fn genRoomList(roomList: *RoomList) !void {
    roomList.clearAndFree();
    for (0..GenRoomMaxTestTimes) |_| {
        const tmp1 = Room.genRoom();
        if (tmp1) |tmp| {
            var isIntersection = false;
            blk: for (roomList.items) |value| {
                if (value.room_intersection_test(tmp)) {
                    isIntersection = true;
                    break :blk;
                } else {
                    continue;
                }
            }

            if (!isIntersection) try roomList.append(tmp);
        }
    }
}

pub const Tag = union(enum) {
    room: struct {
        id: usize,
        color: rl.Color,
    },
    blank,
    path: struct {
        id: usize,
        color: rl.Color,
    },
    connPoint: [2]usize,

    const DV = Scale / 2;

    pub fn getId(tag: Tag) ?usize {
        return switch (tag) {
            .room => |r| r.id,
            .blank => null,
            .path => |r| r.id,
            .connPoint => null,
        };
    }

    pub fn toDpos(tag: Tag) i32 {
        return switch (tag) {
            .room => 0,
            .blank => 0,
            .path => DV / 2,
            .connPoint => DV / 2,
        };
    }

    pub fn toDw(tag: Tag) i32 {
        return switch (tag) {
            .room => Scale,
            .blank => Scale,
            .path => Scale - DV,
            .connPoint => Scale - DV,
        };
    }

    pub fn toColor(tag: Tag) rl.Color {
        switch (tag) {
            .room => |c| return c.color,
            .blank => return rl.Color.gray,
            .path => |c| return c.color,
            .connPoint => return C.black,
        }
    }
};

pub const Index = struct {
    x: usize,
    y: usize,

    pub fn addDirection(self: Index, di: Direction) Index {
        return .{
            .x = @intCast(di.dirX + @as(i32, @intCast(self.x))),
            .y = @intCast(di.dirY + @as(i32, @intCast(self.y))),
        };
    }
};

pub const IndexAndDirection = struct {
    index: Index,
    direction: Direction,
};

const TwoPartMap = std.AutoHashMap([2]usize, std.ArrayList(Index));
const IdPeers = std.AutoHashMap(usize, std.AutoHashMap(usize, void));
const IdConnPoints = std.AutoHashMap(usize, std.ArrayList(Index));
const SelectedIds = std.AutoHashMap(usize, void);
const SelectedConnPoints = std.AutoHashMap(Index, void);

pub const Board = struct {
    board: *[TotalYSize][TotalXSize]Tag,
    twoPartMap: TwoPartMap = undefined,
    idPeers: IdPeers = undefined,
    idConnPoints: IdConnPoints = undefined,

    const Self = @This();

    pub fn init(allocator: Allocator) !Board {
        const board = try allocator.create([TotalYSize][TotalXSize]Tag);
        const tpm = TwoPartMap.init(allocator);
        const idp = IdPeers.init(allocator);
        const idcp = IdConnPoints.init(allocator);
        return Board{
            .board = board,
            .twoPartMap = tpm,
            .idPeers = idp,
            .idConnPoints = idcp,
        };
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

    pub fn idPeersInsert(self: *Self, a: usize, b: usize, allocator: Allocator) !void {
        if (self.idPeers.getPtr(a)) |hmp| {
            try hmp.put(b, {});
        } else {
            var thmp = std.AutoHashMap(usize, void).init(allocator);
            try thmp.put(b, {});
            try self.idPeers.put(a, thmp);
        }
    }

    pub fn dinit(self: *Self, allocator: Allocator) void {
        var iter = self.twoPartMap.valueIterator();
        while (iter.next()) |v| {
            v.clearAndFree();
        }

        var iter1 = self.idPeers.valueIterator();
        while (iter1.next()) |v| {
            v.clearAndFree();
        }

        var iter2 = self.idConnPoints.valueIterator();
        while (iter2.next()) |v| {
            v.clearAndFree();
        }
        self.twoPartMap.clearAndFree();
        self.idPeers.deinit();
        self.idConnPoints.deinit();
        allocator.destroy(self.board);
    }

    pub fn testFF(self: *Self, allocator: Allocator) !void {
        {
            self.cleanBoard();
            var iter = self.twoPartMap.valueIterator();
            while (iter.next()) |v| {
                v.clearAndFree();
            }

            var iter1 = self.idPeers.valueIterator();
            while (iter1.next()) |v| {
                v.clearAndFree();
            }

            var iter2 = self.idConnPoints.valueIterator();
            while (iter2.next()) |v| {
                v.clearAndFree();
            }
            self.twoPartMap.clearAndFree();
            self.idPeers.clearAndFree();
            self.idConnPoints.clearAndFree();
        }

        var globalVal: usize = 0;
        var roomList = RoomList.init(allocator);
        defer roomList.deinit();

        try genRoomList(&roomList);
        self.applayRoomList(&roomList, &globalVal);

        var stack = Stack(IndexAndDirection).init(allocator);
        defer stack.clean();
        for (1..TotalYSize) |y| {
            for (1..TotalXSize) |x| {
                const index: Index = .{ .x = x, .y = y };
                if (checkSurrEight(self, index)) {
                    stack.clean();
                    try stack.push(.{
                        .index = index,
                        .direction = .{ .dirX = 1, .dirY = 0 },
                    });
                    globalVal += 1;
                    try self.floodFilling(&stack, genRandomColor(), globalVal);
                }
            }
        }

        try findConnPoint(self, allocator);

        var selecIds = SelectedIds.init(allocator);
        defer selecIds.deinit();
        var selecConnPoints = SelectedConnPoints.init(allocator);
        defer selecConnPoints.deinit();

        const rsize: i32 = @intCast(roomList.items.len);
        const v: usize = @intCast(rl.getRandomValue(0, rsize - 1));
        const troom = roomList.items[v];
        const kx: usize = @intCast(troom.pos.x);
        const ky: usize = @intCast(troom.pos.y);
        const rid = self.board[ky][kx].room.id;

        try selecIds.put(rid, {});
        for (self.idConnPoints.get(rid).?.items) |value| {
            try selecConnPoints.put(value, {});
        }
        try self.genTree(
            &selecIds,
            &selecConnPoints,
            globalVal,
            allocator,
        );

        for (1..TotalYSize) |y| {
            for (1..TotalXSize) |x| {
                var idx: Index = .{ .x = x, .y = y };
                while (self.surrSum(idx)) |nIdx| {
                    idx = nIdx;
                }
            }
        }
    }

    pub fn surrSum(self: *Self, idx: Index) ?Index {
        switch (self.board[idx.y][idx.x]) {
            .blank, .room => return null,
            .path, .connPoint => {
                var total: i32 = 0;
                var tmp: Index = undefined;
                for (Direction.Four_directions) |dir| {
                    const nx = @as(i32, @intCast(idx.x)) + dir.dirX;
                    const ny = @as(i32, @intCast(idx.y)) + dir.dirY;
                    if (nx < 0 or nx >= TotalXSize or ny < 0 or ny >= TotalYSize) continue;
                    const x: usize = @intCast(nx);
                    const y: usize = @intCast(ny);
                    const nIdx: Index = .{ .x = x, .y = y };
                    const tag = self.board[y][x];
                    switch (tag) {
                        .room, .path, .connPoint => {
                            tmp = nIdx;
                            total += 1;
                        },
                        .blank => {},
                    }
                }
                if (total == 1) {
                    self.board[idx.y][idx.x] = .blank;
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
        globalVal: usize,
        allocator: Allocator,
    ) !void {
        while (sIdSet.count() < globalVal) {
            var iter = sConnPointSet.keyIterator();
            const sedConnIndex = iter.next().?.*;
            const tmpv = self.board[sedConnIndex.y][sedConnIndex.x].connPoint;
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
                try sConnPointSet.put(cp, {});
            }

            const peersPtr = self.idPeers.getPtr(newId).?;
            const intersectionList = try intersection(
                allocator,
                newId,
                peersPtr,
                sIdSet,
            );
            defer intersectionList.deinit();

            try sIdSet.put(newId, {});

            for (intersectionList.items) |arr2| {
                const tap = self.twoPartMap.getPtr(arr2).?;
                for (tap.*.items) |idx| {
                    _ = sConnPointSet.remove(idx);

                    if (sedConnIndex.y == idx.y and sedConnIndex.x == idx.x) {} else {
                        const tmpk = rl.getRandomValue(1, 100);
                        if (tmpk > 97) {} else {
                            self.board[idx.y][idx.x] = .blank;
                        }
                    }
                }
            }
        }
    }

    fn intersection(
        allocaotr: Allocator,
        newId: usize,
        peersPtr: *std.AutoHashMap(usize, void),
        sIdSet: *SelectedIds,
    ) !std.ArrayList([2]usize) {
        var cpList = std.ArrayList([2]usize).init(allocaotr);
        var pn = peersPtr.keyIterator();
        while (pn.next()) |p| {
            if (sIdSet.get(p.*)) |_| {
                try cpList.append([2]usize{ @min(newId, p.*), @max(newId, p.*) });
            }
        }
        return cpList;
    }

    pub fn findConnPoint(self: *Self, allocator: Allocator) !void {
        for (1..TotalYSize) |y| {
            for (1..TotalXSize) |x| {
                if (self.board[y][x] != .blank) continue;
                var result: i32 = 0;
                var idArr: [4]usize = undefined;
                var idIndex: usize = 0;
                for (Direction.Four_directions) |dir| {
                    const nx = @as(i32, @intCast(x)) + dir.dirX;
                    const ny = @as(i32, @intCast(y)) + dir.dirY;
                    if (nx < 0 or nx >= TotalXSize or ny < 0 or ny >= TotalYSize) continue;
                    switch (self.board[@as(usize, @intCast(ny))][@as(usize, @intCast(nx))]) {
                        .room => |r| {
                            idArr[idIndex] = r.id;
                            idIndex += 1;
                            result += 100;
                        },
                        .path => |r| {
                            idArr[idIndex] = r.id;
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
                    const tIndex = Index{ .x = x, .y = y };
                    if (self.twoPartMap.getPtr(tArr)) |arr| {
                        try arr.append(.{ .x = x, .y = y });
                    } else {
                        var barr = std.ArrayList(Index).init(allocator);
                        try barr.append(.{ .x = x, .y = y });
                        try self.twoPartMap.put(tArr, barr);
                    }
                    try self.idPeersInsert(v0, v1, allocator);
                    try self.idPeersInsert(v1, v0, allocator);
                    try self.idConnPointsInsert(v0, tIndex, allocator);
                    try self.idConnPointsInsert(v1, tIndex, allocator);

                    self.board[y][x] = .{ .connPoint = tArr };
                }
            }
        }
    }

    pub fn floodFilling(self: *Self, stack: *Stack(IndexAndDirection), col: rl.Color, globalVal: usize) !void {
        const K = Direction.Direction_of_widening_and_thickening;
        blk0: while (stack.pop()) |start| {
            if (self.board[start.index.y][start.index.x] != .blank) continue;
            const ti = dirToI(start.direction);
            const tdirs = K[ti];

            for (tdirs) |dir| {
                const nx = @as(i32, @intCast(start.index.x)) + dir.dirX;
                const ny = @as(i32, @intCast(start.index.y)) + dir.dirY;
                if (nx < 0 or nx >= TotalXSize or ny < 0 or ny >= TotalYSize) continue :blk0;
                if (self.board[@as(usize, @intCast(ny))][@as(usize, @intCast(nx))] != .blank) continue :blk0;
            }

            self.board[start.index.y][start.index.x] = .{ .path = .{
                .id = globalVal,
                .color = col,
            } };

            for (0..4) |i| {
                const dirs = K[@mod(ti + i + 1, 4)];
                const dir = dirs[0];
                const nx = @as(i32, @intCast(start.index.x)) + dir.dirX;
                const ny = @as(i32, @intCast(start.index.y)) + dir.dirY;
                if (nx < 0 or nx >= TotalXSize or ny < 0 or ny >= TotalYSize) continue;
                if (self.board[@as(usize, @intCast(ny))][@as(usize, @intCast(nx))] != .blank) continue;
                const np = start.index.addDirection(dir);
                try stack.push(.{ .index = np, .direction = dir });
            }
        }
    }

    // Check if the surrounding eight positions are blank
    pub fn checkSurrEight(self: *const Self, index: Index) bool {
        const x = index.x;
        const y = index.y;
        if (self.board[y][x] != .blank) return false;
        for (Direction.Eight_directions) |dir| {
            const nx = @as(i32, @intCast(x)) + dir.dirX;
            const ny = @as(i32, @intCast(y)) + dir.dirY;
            if (nx < 0 or nx >= TotalXSize or ny < 0 or ny >= TotalYSize) return false;
            if (self.board[@as(usize, @intCast(ny))][@as(usize, @intCast(nx))] != .blank) return false;
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

    pub fn applayRoomList(self: *Self, roomList: *RoomList, globalVal: *usize) void {
        for (roomList.items) |room| {
            globalVal.* += 1;
            const ty: usize = @intCast(room.pos.y);
            const tx: usize = @intCast(room.pos.x);
            for (0..@intCast(room.size.ySize)) |dy| {
                for (0..@intCast(room.size.xSize)) |dx| {
                    self.board[ty + dy][tx + dx] = .{ .room = .{
                        .id = globalVal.*,
                        .color = room.color,
                    } };
                }
            }
        }
    }

    pub fn draw(self: Self, buf: []u8) !void {
        for (0..TotalYSize) |y| {
            for (0..TotalXSize) |x| {
                const tag = self.board[y][x];
                rl.drawRectangle(
                    @as(i32, @intCast(x)) * Scale + tag.toDpos(),
                    @as(i32, @intCast(y)) * Scale + tag.toDpos(),
                    tag.toDw(), //- 3,
                    tag.toDw(), // - 3,
                    tag.toColor(),
                );
                _ = buf;

                // if (tag.getId()) |id| {
                //     const v = try std.fmt.bufPrintZ(
                //         buf,
                //         "{d}",
                //         .{id},
                //     );

                //     rl.drawText(
                //         v,
                //         @as(i32, @intCast(x)) * Scale + tag.toDpos(),
                //         @as(i32, @intCast(y)) * Scale + tag.toDpos(),
                //         13,
                //         C.black,
                //     );
                // }
            }
        }
    }
};

const Allocator = std.mem.Allocator;

pub fn Stack(T: type) type {
    return struct {
        list: std.ArrayList(T),
        readIndex: i32 = -1,

        pub fn init(allocator: Allocator) Stack(T) {
            return .{
                .list = std.ArrayList(T).init(allocator),
            };
        }

        pub fn clean(self: *@This()) void {
            self.list.clearAndFree();
            self.readIndex = -1;
        }

        pub fn push(self: *@This(), v: T) !void {
            self.readIndex += 1;
            if (self.readIndex >= self.list.items.len) {
                try self.list.append(v);
            } else {
                self.list.items[@as(usize, @intCast(self.readIndex))] = v;
            }
        }
        pub fn pop(self: *@This()) ?T {
            if (self.readIndex < 0) return null;
            const v = self.list.items[@as(usize, @intCast(self.readIndex))];
            self.readIndex -= 1;
            return v;
        }
    };
}

pub fn mosPosToIndex(x: i32, y: i32) Index {
    const vx: usize = @intCast(@divTrunc(x, Scale));
    const vy: usize = @intCast(@divTrunc(y, Scale));
    return .{ .x = vx, .y = vy };
}

const testing = std.testing;

test "stack" {
    const allocator = testing.allocator;
    var stack = Stack(i32).init(allocator);
    defer stack.clean();

    try stack.push(1);
    try testing.expect(stack.pop().? == 1);
    try testing.expect(stack.pop() == null);

    try stack.push(1);
    try stack.push(2);
    try testing.expect(stack.pop().? == 2);
    try testing.expect(stack.pop().? == 1);
    try testing.expect(stack.pop() == null);

    try stack.push(1);
    try stack.push(2);
    stack.clean();

    try stack.push(1);
    try stack.push(2);
    try stack.push(3);
    try testing.expect(stack.pop().? == 3);
    try testing.expect(stack.pop().? == 2);
    try testing.expect(stack.pop().? == 1);
    try testing.expect(stack.pop() == null);
}

pub fn Queue(T: type) type {
    return struct {
        list: std.ArrayList(T),
        readIndex: usize = 0,

        pub fn init(allocator: Allocator) Queue(T) {
            return .{
                .list = std.ArrayList(T).init(allocator),
            };
        }
        pub fn empty(self: @This()) bool {
            if (self.readIndex >= self.list.items.len) {
                return true;
            } else {
                return false;
            }
        }
        pub fn clean(self: *@This()) void {
            self.list.clearAndFree();
            self.readIndex = 0;
        }
        pub fn deinit(self: *@This()) void {
            self.list.deinit();
        }
        pub fn writeQueue(self: *@This(), v: T) !void {
            try self.list.append(v);
        }

        pub fn readQueue(self: *@This()) ?T {
            if (self.readIndex >= self.list.items.len) return null else {
                const v = self.list.items[self.readIndex];
                self.readIndex += 1;
                return v;
            }
        }
    };
}
