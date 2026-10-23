
const std = @import("std");

const builtin = @import("builtin");

fn isSafeBuild() bool {
    return switch (builtin.mode) {
        .debug => true,
        .safe => true,
        else => false,
    };
}

const SAFE_BUILD = isSafeBuild();

inline fn safeAssert(condition: bool, comptime msg: ?[]const u8) void {
    if (SAFE_BUILD) {
        if (!condition) {
            @panic(msg orelse "Assertion failed.");
        }
    }
}

const Allocator = std.mem.Allocator;

pub fn VecUnmanaged(comptime T: type) type {
    return extern struct {
        const Self = @This();
        
        ptr: [*]T,
        len: usize,
        cap: usize,

        pub fn initCapacity(alloc: Allocator, capacity: usize) Self {
            return .{
                .ptr = (alloc.alloc(T, capacity) catch @panic("Out of memory.")).ptr,
                .len = 0,
                .cap = capacity,
            };
        }

        pub fn init(alloc: Allocator) Self {
            return .initCapacity(alloc, 0);
        }

        pub fn deinit(self: Self, alloc: Allocator) void {
            alloc.free(self.ptr[0..self.cap]);
        }

        pub inline fn slice(self: *const Self) []const T {
            return self.ptr[0..self.len];
        }

        pub inline fn sliceMut(self: *Self) []T {
            return self.ptr[0..self.len];
        }

        pub inline fn getLen(self: Self) usize {
            return self.len;
        }

        pub inline fn setLen(self: *Self, new_len: usize) void {
            self.len = new_len;
        }

        pub inline fn getRawPtr(self: *const Self) [*]const T {
            return self.ptr;
        }

        pub inline fn getRawMut(self: *Self) [*]T {
            return self.ptr;
        }

        pub inline fn get(self: *const Self, index: usize) T {
            return self.ptr[index];
        }

        pub inline fn getPtr(self: *const Self, index: usize) *const T {
            return &self.ptr[index];
        }

        pub inline fn getMut(self: *Self, index: usize) *T {
            return &self.ptr[index];
        }

        pub fn ensureCapacity(self: *Self, alloc: Allocator, cap: usize) void {
            if (self.cap >= cap) return;
            const new_cap = std.math.ceilPowerOfTwo(usize, @max(cap, 4)) catch @panic("Capacity was too large.");
            const new_alloc = alloc.realloc(self.ptr[0..self.cap], new_cap) catch @panic("Out of memory.");
            self.ptr = new_alloc.ptr;
            self.cap = new_cap;
        }

        pub fn reserve(self: *Self, alloc: Allocator, count: usize) void {
            self.ensureCapacity(alloc, self.len + count);
        }

        pub fn pop(self: *Self) ?T {
            if (self.len == 0) return null;
            self.len -= 1;
            return self.ptr[self.len];
        }

        pub fn push(self: *Self, alloc: Allocator, value: T) void {
            self.reserve(alloc, 1);
            self.ptr[self.len] = value;
            self.len += 1;
        }

        pub fn pushMany(
            self: *Self,
            alloc: Allocator,
            many: []const T,
        ) void {
            self.reserve(alloc, many.len);
            @memcpy(self.ptr[self.len..][0..many.len], many);
            self.len += many.len;
        }

        pub fn pushManyWith(
            self: *Self,
            alloc: Allocator,
            ctx: anytype,
            count: usize,
            map: fn(ctx: @TypeOf(ctx), index: usize) T,
        ) void {
            if (count == 0) return;
            self.reserve(alloc, count);
            for (self.ptr[self.len..][0..count], self.len..) |*it, i| {
                it.* = map(ctx, i);
            }
            self.len += count;
        }

        pub fn insertUnchecked(
            self: *Self,
            alloc: Allocator,
            index: usize,
            value: T,
        ) void {
            self.reserve(alloc, 1);
            if (index != self.len) {
                @memmove(self.ptr[index + 1..self.len + 1], self.ptr[index..self.len]);
            }
            self.ptr[index] = value;
            self.len += 1;
        }

        pub fn insert(self: *Self, alloc: Allocator, index: usize, value: T) void {
            safeAssert(index <= self.len, "Index out of bounds.");
            self.insertUnchecked(alloc, index, value);
        }

        pub fn insertManyUnchecked(
            self: *Self,
            alloc: Allocator,
            index: usize,
            many: []const T,
        ) void {
            self.reserve(alloc, many.len);
            const src = self.ptr[index..self.len];
            if (src.len != 0) {
                @memmove(self.ptr[index + many.len..][0..src.len], src);
            }
            @memcpy(self.ptr[index..][0..many.len], many);
            self.len += many.len;
        }

        pub fn insertMany(
            self: *Self,
            alloc: Allocator,
            index: usize,
            many: []const T,
        ) void {
            safeAssert(index <= self.len, "Index out of bounds.");
            if (many.len == 0) return;
            self.insertManyUnchecked(alloc, index, many);
        }

        pub fn insertManyWithUnchecked(
            self: *Self,
            alloc: Allocator,
            start: usize,
            end: usize,
            ctx: anytype,
            map: fn(ctx: @TypeOf(ctx), index: usize) T,
        ) void {
            const insert_count = end - start;
            self.reserve(alloc, insert_count);
            if (start < self.len) {
                const move_len = self.len - start;
                const move_src = self.ptr[start..self.len];
                const move_dest = self.ptr[end..][0..move_len];
                @memmove(move_dest, move_src);
            }
            for (self.ptr[start..end], start..) |*it, i| {
                it.* = map(ctx, i);
            }
            self.len += insert_count;
        }

        pub fn insertManyWith(
            self: *Self,
            alloc: Allocator,
            start: usize,
            end: usize,
            ctx: anytype,
            map: fn(ctx: @TypeOf(ctx), index: usize) T,
        ) void {
            safeAssert(start <= self.len, "Start out of bounds.");
            safeAssert(start <= end, "Start is greater than end.");
            self.insertManyWithUnchecked(alloc, start, end, ctx, map);
        }

        pub fn removeUnchecked(self: *Self, index: usize) T {
            const result = self.ptr[index];
            if (index + 1 != self.len) {
                @memmove(self.ptr[index..self.len - 1], self.ptr[index+1..self.len]);
            }
            self.len -= 1;
            return result;
        }

        pub fn remove(self: *Self, index: usize) T {
            safeAssert(index < self.len, "Index out of bounds.");
            return self.removeUnchecked(index);
        }

        pub fn swapRemoveUnchecked(self: *Self, index: usize) T {
            const swap_with = self.len - 1;
            const removed = self.ptr[index];
            if (swap_with != index) {
                self.ptr[index] = self.ptr[swap_with];
            }
            self.len -= 1;
            return removed;
        }

        pub fn swapRemove(self: *Self, index: usize) T {
            safeAssert(index < self.len, "Index out of bounds.");
            return self.swapRemoveUnchecked(index);
        }

        pub fn swapRemoveManyUnchecked(
            self: *Self,
            index: usize,
            out: []T,
        ) void{
            const move_src = self.ptr[index..][0..out.len];
            @memcpy(out, move_src);
            const after_swap_index = index + out.len;
            const after_swap_len = self.len - after_swap_index;
            if (after_swap_len != 0) {
                const swap_src = self.ptr[after_swap_index..self.len];
                const swap_dest = self.ptr[index..][0..after_swap_len];
                @memmove(swap_dest, swap_src);
            }
            self.len -= out.len;
        }

        pub fn swapRemoveMany(self: *Self, index: usize, out: []T) void {
            safeAssert(index + out.len <= self.len, "Out of bounds.");
            if (out.len == 0) return;
            self.swapRemoveManyUnchecked(index, out);
        }

        pub fn swapUnchecked(self: *Self, a: usize, b: usize) void {
            std.mem.swap(T, &self.ptr[a], &self.ptr[b]);
        }

        pub fn swap(self: *Self, a: usize, b: usize) void {
            safeAssert(a < self.len, "Index `a` out of bounds.");
            safeAssert(b < self.len, "Index `b` out of bounds.");
            if(a == b) return;
            self.swapUnchecked(a, b);
        }

        pub fn removeManyUnchecked(
            self: *Self,
            index: usize,
            out: []T,
        ) void {
            @memcpy(out, self.ptr[index..][0..out.len]);
            const move_len = self.len - (index + out.len);
            if (move_len != 0) {
                @memmove(self.ptr[index..][0..move_len], self.ptr[index + out.len..self.len]);
            }
            self.len -= out.len;
        }

        pub fn removeMany(
            self: *Self,
            index: usize,
            out: []T,
        ) void {
            safeAssert(index + out.len <= self.len, "Out of bounds.");
            self.removeManyUnchecked(index, out);
        }

        pub fn transferFromUnchecked(
            self: *Self,
            alloc: Allocator,
            dest_index: usize,
            src: *Self,
            src_start: usize,
            src_end: usize,
        ) void {
            const move_src = src.ptr[src_start..src_end];
            self.insertManyUnchecked(alloc, dest_index, move_src);
            const move_len = src.len - src_end;
            if (move_len != 0) {
                @memmove(src.ptr[src_start..][0..move_len], src.ptr[src_end..src.getLen()]);
            }
            src.len -= move_src.len;
        }

        pub fn transferFrom(
            self: *Self,
            alloc: Allocator,
            dest_index: usize,
            src: *Self,
            src_start: usize,
            src_end: usize,
        ) void {
            safeAssert(dest_index <= self.len, "Destination index out of bounds");
            safeAssert(src_end <= src.len, "End index out of bounds.");
            safeAssert(src_start <= src_end, "Start greater than end.");
            self.transferFromUnchecked(alloc, dest_index, src, src_start, src_end);
        }

        pub fn drainUnchecked(
            self: *Self,
            ctx: anytype,
            start: usize,
            end: usize,
            takeItem: fn(ctx: @TypeOf(ctx), index: usize, item: T) bool,
        ) void {
            var read_head: usize = start;
            var write_head: usize = start;
            const Branch = enum {
                Sync,
                Async,
            };
            loop: switch (Branch.Sync) {
                .Sync => while (read_head < end) {
                    const item = self.ptr[read_head];
                    if (takeItem(ctx, read_head, item)) {
                        read_head += 1;
                        continue :loop .Async;
                    } else {
                        write_head += 1;
                        read_head += 1;
                    }
                },
                .Async => {
                    while (read_head < end) {
                        const item = self.ptr[read_head];
                        if (!takeItem(ctx, read_head, item)) {
                            self.ptr[write_head] = self.ptr[read_head];
                            write_head += 1;
                        }
                        read_head += 1;
                    }
                    self.len = blk: {
                        if (end != self.len) {
                            const move_len = self.len - end;
                            @memmove(self.ptr[write_head..][0..move_len], self.ptr[end..self.len]);
                            break :blk write_head + move_len;
                        } else {
                            break :blk write_head;
                        }
                    };
                }
            }
        }

        pub fn drain(
            self: *Self,
            ctx: anytype,
            start: usize,
            end: usize,
            takeItem: fn(ctx: @TypeOf(ctx), index: usize, item: T) bool,
        ) void {
            safeAssert(end <= self.len, "End out of bounds.");
            safeAssert(start <= end, "Start is greater than end.");
            self.drainUnchecked(ctx, start, end, takeItem);
        }

        pub fn contains(self: Self, item: T) bool {
            for (self.ptr[0..self.len]) |it| {
                if(std.meta.eql(item, it)) return true;
            }
            return false;
        }

        pub inline fn clear(self: *Self) void {
            self.len = 0;
        }

        pub fn clearRangeUnchecked(self: *Self, start: usize, end: usize) void {
            const move_len = self.len - end;
            const dest = self.ptr[start..][0..move_len];
            const src = self.ptr[end..self.len];
            @memmove(dest, src);
            self.len = start + move_len;
        }

        pub fn clearRange(self: *Self, start: usize, end: usize) void {
            safeAssert(end <= self.len, "End out of bounds.");
            safeAssert(start <= end, "Start is greater than end.");
            self.clearRangeUnchecked(start, end);
        }
    };
}

pub fn VecManaged(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Inner = VecUnmanaged(T);
        
        inner: Inner,
        alloc: Allocator,

        pub fn initCapacity(alloc: Allocator, capacity: usize) Self {
            return .{
                .inner = VecUnmanaged(T).initCapacity(alloc, capacity),
                .alloc = alloc,
            };
        }

        pub fn init(alloc: Allocator) Self {
            return .initCapacity(alloc, 0);
        }

        pub fn fromUnmanaged(alloc: Allocator, unmanaged: VecUnmanaged(T)) Self {
            return .{
                .inner = unmanaged,
                .alloc = alloc,
            };
        }

        pub fn deinit(self: Self) void {
            self.inner.deinit(self.alloc);
        }

        pub inline fn slice(self: *const Self) []const T {
            return self.inner.slice();
        }

        pub inline fn sliceMut(self: *const Self) []T {
            return self.inner.sliceMut();
        }

        pub inline fn getLen(self: Self) usize {
            return self.inner.len;
        }

        pub inline fn setLen(self: *Self, new_len: usize) void {
            self.inner.len = new_len;
        }

        pub inline fn getRawPtr(self: *const Self) [*]const T {
            return self.inner.ptr;
        }

        pub inline fn getRawMut(self: *Self) [*]T {
            return self.inner.ptr;
        }

        pub inline fn get(self: *const Self, index: usize) T {
            return self.inner.get(index);
        }

        pub inline fn getPtr(self: *const Self, index: usize) *const T {
            return self.inner.getPtr(index);
        }

        pub inline fn getMut(self: *Self, index: usize) *T {
            return self.inner.getMut(index);
        }

        pub fn ensureCapacity(self: *Self, cap: usize) void {
            self.inner.ensureCapacity(self.alloc, cap);
        }

        pub fn reserve(self: *Self, count: usize) void {
            self.inner.reserve(self.alloc, count);
        }

        pub fn pop(self: *Self) ?T {
            self.inner.pop();
        }

        pub fn push(self: *Self, value: T) void {
            self.inner.push(self.alloc, value);
        }

        pub fn pushMany(
            self: *Self,
            many: []const T,
        ) void {
            self.inner.pushMany(self.alloc, many);
        }

        pub fn pushManyWith(
            self: *Self,
            ctx: anytype,
            count: usize,
            map: fn(ctx: @TypeOf(ctx), index: usize) T,
        ) void {
            self.inner.pushManyWith(self.alloc, ctx, count, map);
        }

        pub fn insertUnchecked(
            self: *Self,
            index: usize,
            value: T,
        ) void {
            self.inner.insertUnchecked(self.alloc, index, value);
        }

        pub fn insert(
            self: *Self,
            index: usize,
            value: T,
        ) void {
            self.inner.insert(self.alloc, index, value);
        }

        pub fn insertManyUnchecked(
            self: *Self,
            index: usize,
            many: []const T,
        ) void {
            self.inner.insertManyUnchecked(self.alloc, index, many);
        }

        pub fn insertMany(
            self: *Self,
            index: usize,
            many: []const T,
        ) void {
            self.inner.insertMany(self.alloc, index, many);
        }

        pub fn insertManyWithUnchecked(
            self: *Self,
            start: usize,
            end: usize,
            ctx: anytype,
            map: fn(ctx: @TypeOf(ctx), index: usize) T,
        ) void {
            self.inner.insertManyWithUnchecked(self.alloc, start, end, ctx, map);
        }

        pub fn insertManyWith(
            self: *Self,
            start: usize,
            end: usize,
            ctx: anytype,
            map: fn(ctx: @TypeOf(ctx), index: usize) T,
        ) void {
            self.inner.insertManyWith(self.alloc, start, end, ctx, map);
        }

        pub fn removeUnchecked(self: *Self, index: usize) T {
            return self.inner.removeUnchecked(index);
        }

        pub fn remove(self: *Self, index: usize) T {
            return self.inner.remove(index);
        }

        pub fn swapRemoveUnchecked(self: *Self, index: usize) T {
            return self.inner.swapRemoveUnchecked(index);
        }

        pub fn swapRemove(self: *Self, index: usize) T {
            return self.inner.swapRemove(index);
        }

        pub fn swapRemoveManyUnchecked(
            self: *Self,
            index: usize,
            out: []T,
        ) void {
            self.inner.swapRemoveManyUnchecked(index, out);
        }

        pub fn swapRemoveMany(
            self: *Self,
            index: usize,
            out: []T,
        ) void {
            self.inner.swapRemoveMany(index, out);
        }

        pub fn swapUnchecked(self: *Self, a: usize, b: usize) void {
            self.inner.swapUnchecked(a, b);
        }

        pub fn swap(self: *Self, a: usize, b: usize) void {
            self.inner.swap(a, b);
        }

        pub fn removeManyUnchecked(
            self: *Self,
            index: usize,
            out: []T,
        ) void {
            self.inner.removeManyUnchecked(index, out);
        }

        pub fn removeMany(
            self: *Self,
            index: usize,
            out: []T,
        ) void {
            self.inner.removeMany(index, out);
        }

        pub fn transferFromUnchecked(
            self: *Self,
            dest_index: usize,
            src: *VecUnmanaged(T),
            src_start: usize,
            src_end: usize,
        ) void {
            self.inner.transferFromUnchecked(
                self.alloc,
                dest_index,
                src,
                src_start,
                src_end,
            );
        }

        pub fn transferFrom(
            self: *Self,
            dest_index: usize,
            src: *VecUnmanaged(T),
            src_start: usize,
            src_end: usize,
        ) void {
            self.inner.transferFrom(
                self.alloc,
                dest_index,
                src,
                src_start,
                src_end,
            );
        }

        pub fn drainUnchecked(
            self: *Self,
            ctx: anytype,
            start: usize,
            end: usize,
            takeItem: fn(ctx: @TypeOf(ctx), index: usize, item: T) bool,
        ) void {
            self.inner.drainUnchecked(ctx, start, end, takeItem);
        }

        pub fn drain(
            self: *Self,
            ctx: anytype,
            start: usize,
            end: usize,
            takeItem: fn(ctx: @TypeOf(ctx), index: usize, item: T) bool,
        ) void {
            self.inner.drain(ctx, start, end, takeItem);
        }

        pub fn contains(self: Self, item: T) bool {
            return self.inner.contains(item);
        }

        pub fn clear(self: *Self) void {
            self.inner.clear();
        }

        pub fn clearRangeUnchecked(
            self: *Self,
            start: usize,
            end: usize,
        ) void {
            self.inner.clearRangeUnchecked(start, end);
        }

        pub fn clearRange(
            self: *Self,
            start: usize,
            end: usize,
        ) void {
            self.inner.clearRange(start, end);
        }
    };
}

comptime {
    const vec_decls = std.meta.declarations(VecUnmanaged(void));
    for (vec_decls) |name| {
        const decl = @field(VecUnmanaged(void), name);
        const decl_type = @TypeOf(decl);
        if (@typeInfo(decl_type) == .@"fn") {
            if (!@hasDecl(VecManaged(void), name)) @compileError("Missing function in VecManaged: " ++ name);
        }
    }
}
