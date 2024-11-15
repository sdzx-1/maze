const std = @import("std");

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

        pub fn deinit(self: *@This()) void {
            self.list.deinit();
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

pub const Size = struct {
    xSize: i32,
    ySize: i32,
};

pub const Pos = struct {
    x: i32,
    y: i32,
};

pub const Direction = struct {
    dirX: i32,
    dirY: i32,

    const Self = @This();

    pub fn toIndex(dir: Direction) usize {
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

pub const Stage = enum {
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

pub const StageTimeList = [@typeInfo(Stage).@"enum".fields.len]i64;

pub const StageTimeMap = struct {
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
