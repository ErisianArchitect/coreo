
const std = @import("std");

const debug = @import("debug");

const Allocator = std.mem.Allocator;

const Vec = @import("dsa").VecUnmanaged;

/// Out of memory panic.
inline fn oom(comptime src: ?std.lang.SourceLocation) noreturn {
    if (src) |loc| {
        @panic(std.fmt.comptimePrint("Out of memory: {s}:{d}:{d}", .{loc.file, loc.line, loc.column}));
    } else {
        @panic("Out of memory.");
    }
}

const PrivateToken = opaque {};

pub fn ObjId(comptime Marker: anytype) type {
    return packed struct(u64) {
        const _ = .{Marker};

        const Self = @This();

        pub const NULL: Self = .init(0, 0);
        
        id: u32,
        gen: u32,


        pub inline fn init(id: u32, gen: u32) Self {
            return .{.id = id, .gen = gen};
        }

        pub inline fn first(id: u32) Self {
            return .{.id = id, .gen = 1};
        }

        pub inline fn rotGen(self: *Self) void {
            self.gen +%= 2;
        }

        pub inline fn withRotGen(self: Self) Self {
            self.incrGen();
            return self;
        }
    };
}

pub const ObjectPoolError = error {
    IdMismatch,
};

pub fn ObjectPoolUnmanaged(comptime T: type) type {
    return extern struct {
        const Self = @This();

        pub fn SlicePtr(comptime P: type) type {
            return extern struct {
                ptr: [*]P,
                len: usize,
            };
        }

        pub const Id = ObjId(.{T, ObjectPoolUnmanaged, PrivateToken});

        pool: SlicePtr(T),
        pool_ids: [*]Id,
        index: SlicePtr(u32),
        free: SlicePtr(Id),
        cap: usize,

        fn capPoolSlice(self: *const Self) []const T {
            return self.pool.ptr[0..self.cap];
        }

        fn capPoolSliceMut(self: *Self) []T {
            return self.pool.ptr[0..self.cap];
        }

        fn capPoolIndexSlice(self: *const Self) []const u32 {
            return self.pool_ids[0..self.cap];
        }

        fn capPoolIndexSliceMut(self: *Self) []u32 {
            return self.pool_ids[0..self.cap];
        }

        fn capIndexSlice(self: *const Self) []const u32 {
            return self.index.ptr[0..self.cap];
        }

        fn capIndexSliceMut(self: *Self) []u32 {
            return self.index.ptr[0..self.cap];
        }

        fn capFreeSlice(self: *const Self) []const ObjId {
            return self.free.ptr[0..self.cap];
        }

        fn capFreeSliceMut(self: *Self) []ObjId {
            return self.free.ptr[0..self.cap];
        }

        pub fn initCapacity(alloc: Allocator, capacity: usize) Self {
            const pool_ptr       = (alloc.alloc(T,     capacity) catch oom(@src())).ptr;
            const pool_index_ptr = (alloc.alloc(Id,   capacity) catch oom(@src())).ptr;
            const index_ptr      = (alloc.alloc(u32,   capacity) catch oom(@src())).ptr;
            const free_ptr       = (alloc.alloc(Id, capacity) catch oom(@src())).ptr;
            return .{
                .pool_ids = pool_index_ptr,
                .pool       = .{.ptr = pool_ptr,       .len = 0},
                .index      = .{.ptr = index_ptr,      .len = 0},
                .free       = .{.ptr = free_ptr,       .len = 0},
                .cap        = capacity,
            };
        }

        pub fn init(alloc: Allocator) Self {
            return .initCapacity(alloc, 0);
        }

        pub fn deinit(self: Self, alloc: Allocator) void {
            alloc.free(self.capPoolSliceMut());
            alloc.free(self.capPoolIndexSliceMut());
            alloc.free(self.capIndexSliceMut());
            alloc.free(self.capFreeSliceMut());
            self.pool  = undefined;
            self.index = undefined;
            self.free  = undefined;
            self.len = 0;
            self.cap = 0;
        }

        pub fn ensureCapacity(self: *Self, alloc: Allocator, capacity: usize) void {
            if (self.cap >= capacity) return;
            const new_cap = std.math.ceilPowerOfTwo(usize, @max(capacity, 4)) catch @panic("Capacity was too large.");
            self.pool.ptr       = alloc.realloc(self.capPoolSliceMut(),      new_cap) catch oom(@src());
            self.pool_ids.ptr = alloc.realloc(self.capPoolIndexSliceMut(), new_cap) catch oom(@src());
            self.index.ptr      = alloc.realloc(self.capIndexSliceMut(),     new_cap) catch oom(@src());
            self.free.ptr       = alloc.realloc(self.capFreeSliceMut(),      new_cap) catch oom(@src());
            self.cap = new_cap;
        }

        pub fn reserve(self: *Self, alloc: Allocator, count: usize) void {
            const reserve_capacity = self.pool.len + count;
            if (self.cap >= reserve_capacity) return;
            self.ensureCapacity(alloc, reserve_capacity);
        }

        fn popId(self: *Self) ?Id {
            if (self.free.len == 0) return null;
            self.free.len -= 1;
            return self.free[self.free.len];
        }

        fn pushId(self: *Self) Id {
            const id_ind: u32 = @as(u32, self.index.len);
            self.index.len += 1;
            // generation increases by 2, start at index 1, if it rolls around, it ends up back at 1 instead of 0.
            // This maintains that 0 is reserved for null.
            return Id.first(id_ind);
        }

        fn allocate(self: *Self, alloc: Allocator) Id {
            self.reserve(alloc, 1);
            if (self.popId()) |popped| {
                return popped;
            } else {
                return self.pushId();
            }
        }

        fn swapRemove(self: *Self, index: usize) struct{ T, ?u32 } {
            const result = self.pool[index];
            const end = self.pool.len - 1;
            if (end == self.pool.len) {
                self.pool.len -= 1;
                return .{result, null};
            } else {
                self.pool.len -= 1;
                self.pool.ptr[index] = self.pool.ptr[end];
                const end_id = self.pool_ids[end];
                self.pool_ids[index] = end_id;
                return .{result, end_id};
            }
        }

        pub fn get(self: *const Self, id: Id) ObjectPoolError!*const T {
            const pool_index = self.index.ptr[id.id];
            const pool_id = self.pool_ids[pool_index];
            if (pool_id != id) return ObjectPoolError.IdMismatch;
            return &self.pool.ptr[pool_index];
        }

        pub fn getMut(self: *Self, id: Id) ObjectPoolError!*T {
            const pool_index = self.index.ptr[id.id];
            const pool_id = self.pool_ids[pool_index];
            if (pool_id != id) return ObjectPoolError.IdMismatch;
            return &self.pool.ptr[pool_index];
        }

        pub fn push(self: *Self, alloc: Allocator, value: T) Id {
            const id = self.allocate(alloc);
            const index = self.pool.len;
            self.pool.ptr[index] = value;
            self.pool_ids[index] = id;
            self.pool.len += 1;
            self.index[id.id] = index;
            return id;
        }

        pub fn pop(self: *Self, id: Id) ObjectPoolError!T {
            const pool_index = self.index.ptr[id.id];
            const pool_id = self.pool_ids[pool_index];
            if (pool_id != id) return ObjectPoolError.IdMismatch;
            const result, const swapped = self.swapRemove(pool_index);
            if (swapped) |swap_id| {
                self.index.ptr[swap_id.id] = pool_index;
            }
            self.free.ptr[self.free.len] = id;
            self.free.len += 1;
            return result;
        }
    };
}
