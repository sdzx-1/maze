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
