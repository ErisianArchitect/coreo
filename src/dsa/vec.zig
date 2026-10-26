
const std = @import("std");
const builtin = @import("builtin");
const CFG = @import("CFG");

const comp = @import("comp");
const dsa = @import("dsa");
const debug = @import("debug");

const StackVec = dsa.StackVec;

const safeAssert = debug.assert.safeAssert;

const Allocator = std.mem.Allocator;


comptime { // Checking.
    if (CFG.CHECK) {
        const vec_decls = std.meta.declarations(VecUnmanaged(void));
        var missing = StackVec([]const u8, vec_decls.len).init();
        for (vec_decls) |name| {
            const decl = @field(VecUnmanaged(void), name);
            const decl_type = @TypeOf(decl);
            if (@typeInfo(decl_type) == .@"fn" and !@hasDecl(VecManaged(void), name)) {
                missing.push(name);
            }
        }
        if (missing.len > 0) {
            var missing_names: [missing.len][]const u8 = undefined;
            @memcpy(&missing_names, missing.items[0..missing.len]);
            const missing_names_list = comp.joinSlices(.immut, u8, "\n", comp.internArray(.immut, []const u8, missing_names));
            @compileError(std.fmt.comptimePrint("Missing functions in VecManaged:\n{s}", .{missing_names_list}));
        }
    }
}

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

        pub fn popOut(self: *Self, out: *T) bool {
            if (self.len == 0) return false;
            self.len -= 1;
            out.* = self.ptr[self.len];
            return true;
        }

        pub fn pop(self: *Self) ?T {
            var out: T = undefined;
            if (self.popOut(&out)) return out;
            return null;
        }

        pub fn popMany(self: *Self, out: []T) bool {
            if (out.len > self.len) return false;
            @memcpy(out, self.ptr[self.len - out.len..self.len]);
            self.len -= out.len;
        }

        pub fn push(self: *Self, alloc: Allocator, value: T) void {
            self.reserve(alloc, 1);
            self.ptr[self.len] = value;
            self.len += 1;
        }

        pub fn pushMut(self: *Self, alloc: Allocator, value: T) *T {
            const index = self.len;
            self.push(alloc, value);
            return &self.ptr[index];
        }

        pub fn pushMany(
            self: *Self,
            alloc: Allocator,
            many: []const T,
        ) void {
            if (many.len == 0) return;
            self.reserve(alloc, many.len);
            @memcpy(self.ptr[self.len..][0..many.len], many);
            self.len += many.len;
        }

        pub fn pushManyMut(
            self: *Self,
            alloc: Allocator,
            many: []const T,
        ) []T {
            const index = self.len;
            self.pushMany(alloc, many);
            return self.ptr[index..self.len];
        }

        pub fn pushManyWith(
            self: *Self,
            alloc: Allocator,
            count: usize,
            ctx: anytype,
            map: fn(ctx: @TypeOf(ctx), index: usize) T,
        ) void {
            if (count == 0) return;
            self.reserve(alloc, count);
            for (self.ptr[self.len..][0..count], self.len..) |*it, i| {
                it.* = map(ctx, i);
            }
            self.len += count;
        }

        pub fn pushManyWithMut(
            self: *Self,
            alloc: Allocator,
            count: usize,
            ctx: anytype,
            map: fn(ctx: @TypeOf(ctx), index: usize) T,
        ) []T {
            const index = self.len;
            self.pushManyWith(alloc, ctx, count, map);
            return self.ptr[index..self.len];
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

        pub fn insert(
            self: *Self,
            alloc: Allocator,
            index: usize,
            value: T,
        ) void {
            safeAssert(index <= self.len, .{.src = @src(), .msg = "Index out of bounds."});
            self.insertUnchecked(alloc, index, value);
        }

        pub fn insertMutUnchecked(
            self: *Self,
            alloc: Allocator,
            index: usize,
            value: T,
        ) *T {
            self.insertUnchecked(alloc, index, value);
            return &self.ptr[index];
        }

        pub fn insertMut(
            self: *Self,
            alloc: Allocator,
            index: usize,
            value: T,
        ) *T {
            self.insert(alloc, index, value);
            return &self.ptr[index];
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
            safeAssert(index <= self.len, .{.src = @src(), .msg = "Index out of bounds."});
            if (many.len == 0) return;
            self.insertManyUnchecked(alloc, index, many);
        }

        pub fn insertManyMutUnchecked(
            self: *Self,
            alloc: Allocator,
            index: usize,
            many: []const T,
        ) []T {
            self.insertManyUnchecked(alloc, index, many);
            return self.ptr[index..][0..many.len];
        }

        pub fn insertManyMut(
            self: *Self,
            alloc: Allocator,
            index: usize,
            many: []const T,
        ) []T {
            self.insertMany(alloc, index, many);
            return self.ptr[index..][0..many.len];
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
            for (start..end) |i| {
                self.ptr[i] = map(ctx, i);
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
            safeAssert(start <= self.len, .{.src = @src(), .msg = "Start out of bounds."});
            safeAssert(start <= end, .{.src = @src(), .msg = "Start is greater than end."});
            self.insertManyWithUnchecked(alloc, start, end, ctx, map);
        }

        pub fn insertManyWithMutUnchecked(
            self: *Self,
            alloc: Allocator,
            start: usize,
            end: usize,
            ctx: anytype,
            map: fn(ctx: @TypeOf(ctx), index: usize) T,
        ) []T {
            self.insertManyWithUnchecked(alloc, start, end, ctx, map);
            return self.ptr[start..end];
        }

        pub fn insertManyWithMut(
            self: *Self,
            alloc: Allocator,
            start: usize,
            end: usize,
            ctx: anytype,
            map: fn(ctx: @TypeOf(ctx), index: usize) T,
        ) []T {
            self.insertManyWith(alloc, start, end, ctx, map);
            return self.ptr[start..end];
        }

        pub fn removeOutUnchecked(self: *Self, index: usize, out: *T) void {
            out.* = self.ptr[index];
            if (index + 1 != self.len) {
                @memmove(self.ptr[index..self.len-1], self.ptr[index+1..self.len]);
            }
            self.len -= 1;
        }

        pub fn removeOut(self: *Self, index: usize, out: *T) void {
            safeAssert(index < self.len, .{.src = @src(), .msg = "Index out of bounds."});
            self.removeOutUnchecked(index, out);
        }

        pub fn removeUnchecked(self: *Self, index: usize) T {
            var result: T = undefined;
            self.removeOutUnchecked(index, &result);
            return result;
        }

        pub fn remove(self: *Self, index: usize) T {
            safeAssert(index < self.len, .{.src = @src(), .msg = "Index out of bounds."});
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
            safeAssert(index < self.len, .{.src = @src(), .msg = "Index out of bounds."});
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
            safeAssert(index + out.len <= self.len, .{.src = @src(), .msg = "Out of bounds."});
            if (out.len == 0) return;
            self.swapRemoveManyUnchecked(index, out);
        }

        pub fn swapUnchecked(self: *Self, a: usize, b: usize) void {
            std.mem.swap(T, &self.ptr[a], &self.ptr[b]);
        }

        pub fn swap(self: *Self, a: usize, b: usize) void {
            safeAssert(a < self.len, .{.src = @src(), .msg = "Index `a` out of bounds."});
            safeAssert(b < self.len, .{.src = @src(), .msg = "Index `b` out of bounds."});
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
            safeAssert(index + out.len <= self.len, .{.src = @src(), .msg = "Out of bounds."});
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
            safeAssert(dest_index <= self.len, .{.src = @src(), .msg = "Destination index out of bounds"});
            safeAssert(src_end <= src.len, .{.src = @src(), .msg = "End index out of bounds."});
            safeAssert(src_start <= src_end, .{.src = @src(), .msg = "Start greater than end."});
            self.transferFromUnchecked(alloc, dest_index, src, src_start, src_end);
        }

        pub fn append(
            self: *Self,
            alloc: Allocator,
            src: *Self,
        ) void {
            self.reserve(alloc, src.len);
            @memcpy(self.ptr[self.len..][0..src.len], src.ptr[0..src.len]);
            src.clear();
        }

        pub fn extractIfUnchecked(
            self: *Self,
            ctx: anytype,
            start: usize,
            end: usize,
            extract: fn(ctx: @TypeOf(ctx), index: usize, item: *T) bool,
        ) void {
            var read_head: usize = start;
            var write_head: usize = start;
            const Branch = enum {
                Sync,
                Async,
            };
            loop: switch (Branch.Sync) {
                .Sync => while (read_head < end) {
                    const item = &self.ptr[read_head];
                    if (extract(ctx, read_head, item)) {
                        read_head += 1;
                        continue :loop .Async;
                    } else {
                        write_head += 1;
                        read_head += 1;
                    }
                },
                .Async => {
                    while (read_head < end) {
                        const item = &self.ptr[read_head];
                        if (!extract(ctx, read_head, item)) {
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

        pub fn extractIf(
            self: *Self,
            ctx: anytype,
            start: usize,
            end: usize,
            extract: fn(ctx: @TypeOf(ctx), index: usize, item: *T) bool,
        ) void {
            safeAssert(end <= self.len, .{.src = @src(), .msg = "End out of bounds."});
            safeAssert(start <= end, .{.src = @src(), .msg = "Start is greater than end."});
            self.extractIfUnchecked(ctx, start, end, extract);
        }

        pub fn contains(self: Self, item: T) bool {
            for (self.ptr[0..self.len]) |it| {
                if(std.meta.eql(item, it)) return true;
            }
            return false;
        }

        pub fn sort(self: *Self, ctx: anytype, lessThanFn: fn(ctx: @TypeOf(ctx), lhs: T, rhs: T) bool) void {
            std.sort.heap(T, self.sliceMut(), ctx, lessThanFn);
        }

        pub inline fn isEmpty(self: Self) bool {
            return self.len == 0;
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
            safeAssert(end <= self.len, .{.src = @src(), .msg = "End out of bounds."});
            safeAssert(start <= end, .{.src = @src(), .msg = "Start is greater than end."});
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

        pub fn popOut(self: *Self, out: *T) bool {
            return self.inner.popOut(out);
        }

        pub fn pop(self: *Self) ?T {
            return self.inner.pop();
        }

        pub fn popMany(self: *Self, out: []T) bool {
            return self.inner.popMany(out);
        }

        pub fn push(self: *Self, value: T) void {
            self.inner.push(self.alloc, value);
        }

        pub fn pushMut(self: *Self, value: T) *T {
            self.inner.pushMut(self.alloc, value);
        }

        pub fn pushMany(
            self: *Self,
            many: []const T,
        ) void {
            self.inner.pushMany(self.alloc, many);
        }

        pub fn pushManyMut(
            self: *Self,
            many: []const T,
        ) []T {
            return self.inner.pushManyMut(self.alloc, many);
        }

        pub fn pushManyWith(
            self: *Self,
            count: usize,
            ctx: anytype,
            map: fn(ctx: @TypeOf(ctx), index: usize) T,
        ) void {
            self.inner.pushManyWith(self.alloc, count, ctx, map);
        }

        pub fn pushManyWithMut(
            self: *Self,
            count: usize,
            ctx: anytype,
            map: fn(ctx: @TypeOf(ctx), index: usize) T,
        ) []T {
            return self.inner.pushManyWithMut(self.alloc, count, ctx, map);
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

        pub fn insertMutUnchecked(
            self: *Self,
            index: usize,
            value: T,
        ) *T {
            return self.inner.insertMutUnchecked(self.alloc, index, value);
        }

        pub fn insertMut(
            self: *Self,
            index: usize,
            value: T
        ) *T {
            self.inner.insertMut(self.alloc, index, value);
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

        pub fn insertManyMutUnchecked(
            self: *Self,
            index: usize,
            many: []const T,
        ) []T {
            return self.inner.insertManyMutUnchecked(self.alloc, index, many);
        }

        pub fn insertManyMut(
            self: *Self,
            index: usize,
            many: []const T,
        ) []T {
            return self.inner.insertManyMut(self.alloc, index, many);
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

        pub fn insertManyWithMutUnchecked(
            self: *Self,
            start: usize,
            end: usize,
            ctx: anytype,
            map: fn(ctx: @TypeOf(ctx), index: usize) T,
        ) []T {
            return self.inner.insertManyWithMutUnchecked(self.alloc, start, end, ctx, map);
        }

        pub fn insertManyWithMut(
            self: *Self,
            start: usize,
            end: usize,
            ctx: anytype,
            map: fn(ctx: @TypeOf(ctx), index: usize) T,
        ) []T {
            return self.inner.insertManyWithMut(self.alloc, start, end, ctx, map);
        }

        pub fn removeOutUnchecked(self: *Self, index: usize, out: *T) void {
            self.inner.removeOutUnchecked(index, out);
        }

        pub fn removeOut(self: *Self, index: usize, out: *T) void {
            self.inner.removeOut(index, out);
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

        pub fn append(
            self: *Self,
            alloc: Allocator,
            src: *VecUnmanaged(T),
        ) void {
            self.inner.append(alloc, src);
        }

        pub fn extractIfUnchecked(
            self: *Self,
            ctx: anytype,
            start: usize,
            end: usize,
            extract: fn(ctx: @TypeOf(ctx), index: usize, item: *T) bool,
        ) void {
            self.inner.extractIfUnchecked(ctx, start, end, extract);
        }

        pub fn extractIf(
            self: *Self,
            ctx: anytype,
            start: usize,
            end: usize,
            extract: fn(ctx: @TypeOf(ctx), index: usize, item: *T) bool,
        ) void {
            self.inner.extractIf(ctx, start, end, extract);
        }

        pub fn contains(self: Self, item: T) bool {
            return self.inner.contains(item);
        }

        pub fn sort(self: *Self, ctx: anytype, lessThanFn: fn(ctx: @TypeOf(ctx), T, T) bool) void {
            self.inner.sort(ctx, lessThanFn);
        }

        pub inline fn isEmpty(self: Self) bool {
            return self.inner.isEmpty();
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
