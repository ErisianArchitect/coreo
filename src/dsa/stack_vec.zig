
const std = @import("std");

const debug = @import("debug");

const outOfBounds = debug.assert.failure("Out of bounds");
const bufferOverflow = debug.assert.failure("Buffer overflow");

pub fn StackVec(comptime T: type, comptime size: comptime_int) type {
    return struct {
        const Self = @This();

        items: [size]T,
        len: usize,

        pub inline fn init() Self {
            return .{.items = undefined, .len = 0};
        }

        pub inline fn slice(self: *const Self) []const T {
            return self.items[0..self.len];
        }

        pub inline fn sliceMut(self: *Self) []T {
            return self.items[0..self.len];
        }

        pub fn push(self: *Self, value: T) void {
            if (self.len == self.items.len) bufferOverflow(.{.src = @src()});
            self.items[self.len] = value;
            self.len += 1;
        }

        pub fn popOut(self: *Self, out: *T) bool {
            if (self.len == 0) return false;
            self.len -= 1;
            out.* = self.items[self.len];
            return true;
        }

        pub fn pop(self: *Self) ?T {
            var out: T = undefined;
            if (self.popOut(&out)) {
                return out;
            }
            return null;
        }
    };
}
