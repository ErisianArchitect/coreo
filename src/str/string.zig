
const std = @import("std");
const CFG = @import("CFG");

const Alloc = std.mem.Allocator;

comptime {
    const checking = @import("debug").checking;
    checking.checkInterface(CFG.CHECK, StringUnmanaged, StringManaged);
}

pub const StringUnmanaged = struct {
    const Self = @This();
    
    raw: []u8,
    len: usize,

    pub const empty: Self = .{.raw = &[0]u8{}, .len = 0};

    pub fn initCapacity(alloc: Alloc, capacity: usize) Self {
        return .{
            .raw = alloc.alloc(u8, capacity),
            .len = 0,
        };
    }

    pub fn deinit(self: Self, alloc: Alloc) void {
        alloc.free(self.raw);
    }

    pub fn format(
        self: Self,
        writer: *std.Io.Writer,
    ) !void {
        try writer.writeAll(self.slice());
    }

    pub inline fn slice(self: Self) []const u8 {
        return self.raw[0..self.len];
    }

    pub inline fn sliceMut(self: Self) []u8 {
        return self.raw[0..self.len];
    }

    pub inline fn getCapacity(self: Self) usize {
        return self.raw.len;
    }

    pub inline fn getLen(self: Self) usize {
        return self.len;
    }

    pub fn ensureCapacity(self: *Self, alloc: Alloc, new_capacity: usize) (error{OutOfMemory}!void) {
        if (new_capacity <= self.raw.len) return;
        const new_cap = std.math.ceilPowerOfTwo(usize, @max(new_capacity, 4)) catch @panic("New capacity causes overflow.");
        self.raw = try alloc.realloc(self.raw, new_cap);
    }

    pub fn reserve(self: *Self, alloc: Alloc, size: usize) (error{OutOfMemory}!void) {
        try self.ensureCapacity(alloc, self.len + size);
    }

    pub fn push(self: *Self, alloc: Alloc, chr: u8) (error{OutOfMemory}!void) {
        try self.reserve(alloc, 1);
        self.raw[self.len] = chr;
        self.len += 1;
    }

    pub fn pushStr(self: *Self, alloc: Alloc, s: []const u8) (error{OutOfMemory}!void) {
        try self.reserve(alloc, s.len);
        @memcpy(self.raw[self.len..][0..s.len], s);
        self.len += s.len;
    }

    pub inline fn clear(self: *Self) void {
        self.len = 0;
    }
};

pub const StringManaged = struct {
    const Self = @This();

    inner: StringUnmanaged,
    alloc: Alloc,

    pub fn init(alloc: Alloc) Self {
        return .{.inner = .empty, .alloc = alloc};
    }

    pub fn initCapacity(alloc: Alloc, capacity: usize) Self {
        return .{.inner = .initCapacity(alloc, capacity), .alloc = alloc};
    }

    pub fn deinit(self: Self) void {
        self.inner.deinit(self.alloc);
    }

    pub fn format(
        self: Self,
        writer: *std.Io.Writer,
    ) !void {
        try self.inner.format(writer);
    }

    pub inline fn slice(self: Self) []const u8 {
        return self.inner.slice();
    }

    pub inline fn sliceMut(self: Self) []u8 {
        return self.inner.sliceMut();
    }

    pub inline fn getLen(self: Self) usize {
        return self.inner.getLen();
    }

    pub inline fn getCapacity(self: Self) usize {
        return self.inner.getCapacity();
    }

    pub fn ensureCapacity(self: *Self, new_capacity: usize) (error{OutOfMemory}!void) {
        try self.inner.ensureCapacity(self.alloc, new_capacity);
    }

    pub fn reserve(self: *Self, size: usize) (error{OutOfMemory}!void) {
        try self.inner.reserve(self.alloc, size);
    }

    pub fn push(self: *Self, chr: u8) (error{OutOfMemory}!void) {
        try self.inner.push(self.alloc, chr);
    }

    pub fn pushStr(self: *Self, s: []const u8) (error{OutOfMemory}!void) {
        try self.inner.pushStr(self.alloc, s);
    }

    pub inline fn clear(self: *Self) void {
        self.inner.clear();
    }
};
