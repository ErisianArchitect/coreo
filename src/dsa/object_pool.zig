
const std = @import("std");

const comp = @import("comp");
const debug = @import("debug");

const Allocator = std.mem.Allocator;

const dsa = @import("dsa");

const Vec = dsa.VecUnmanaged;
const GenId = dsa.GenId;

const oom = debug.outOfMemory;

const PrivateToken = opaque {};

const Seal = comp.typing.GenericOpaqueSeal(opaque{});

comptime {
    if (Seal(u32) == Seal(u64)) {
        @compileError("Seal is broken.");
    }
}

pub const ObjectPoolError = error {
    IdMismatch,
};

pub fn SlicePtr(comptime T: type) type {
    return extern struct {
        ptr: [*]T,
        len: usize,
    };
}

pub fn ObjectPoolUnmanaged(comptime T: type) type {
    return extern struct {
        const Self = @This();

        pub const Id = GenId(Seal(T));

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

        fn capPoolIndexSlice(self: *const Self) []const Id {
            return self.pool_ids[0..self.cap];
        }

        fn capPoolIndexSliceMut(self: *Self) []Id {
            return self.pool_ids[0..self.cap];
        }

        fn capIndexSlice(self: *const Self) []const u32 {
            return self.index.ptr[0..self.cap];
        }

        fn capIndexSliceMut(self: *Self) []u32 {
            return self.index.ptr[0..self.cap];
        }

        fn capFreeSlice(self: *const Self) []const Id {
            return self.free.ptr[0..self.cap];
        }

        fn capFreeSliceMut(self: *Self) []Id {
            return self.free.ptr[0..self.cap];
        }

        pub fn initCapacity(alloc: Allocator, capacity: usize) Self {
            const pool_ptr       = (alloc.alloc(T,   capacity) catch oom(.{.src=@src()})).ptr;
            const pool_index_ptr = (alloc.alloc(Id,  capacity) catch oom(.{.src=@src()})).ptr;
            const index_ptr      = (alloc.alloc(u32, capacity) catch oom(.{.src=@src()})).ptr;
            const free_ptr       = (alloc.alloc(Id,  capacity) catch oom(.{.src=@src()})).ptr;
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

        pub fn deinit(self: *Self, alloc: Allocator) void {
            alloc.free(self.capPoolSliceMut());
            alloc.free(self.capPoolIndexSliceMut());
            alloc.free(self.capIndexSliceMut());
            alloc.free(self.capFreeSliceMut());
            comp.undefFields(Self, self);
        }

        pub fn slice(self: *const Self) []const T {
            return self.pool.ptr[0..self.pool.len];
        }

        pub fn sliceMut(self: *Self) []T {
            return self.pool.ptr[0..self.pool.len];
        }

        pub fn ensureCapacity(self: *Self, alloc: Allocator, capacity: usize) void {
            if (self.cap >= capacity) return;
            const new_cap = std.math.ceilPowerOfTwo(usize, @max(capacity, 4)) catch @panic("Capacity was too large.");
            self.pool.ptr       = (alloc.realloc(self.capPoolSliceMut(),      new_cap) catch oom(.{.src=@src()})).ptr;
            self.pool_ids       = (alloc.realloc(self.capPoolIndexSliceMut(), new_cap) catch oom(.{.src=@src()})).ptr;
            self.index.ptr      = (alloc.realloc(self.capIndexSliceMut(),     new_cap) catch oom(.{.src=@src()})).ptr;
            self.free.ptr       = (alloc.realloc(self.capFreeSliceMut(),      new_cap) catch oom(.{.src=@src()})).ptr;
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
            return self.free.ptr[self.free.len];
        }

        fn pushId(self: *Self) Id {
            const id_ind: u32 = @intCast(self.index.len);
            self.index.len += 1;
            // generation increases by 2, start at index 1, if it rolls around, it ends up back at 1 instead of 0.
            // This maintains that 0 is reserved for null.
            return Id.initFirstGen(id_ind);
        }

        fn allocate(self: *Self, alloc: Allocator) Id {
            if (self.popId()) |id| {
                return id.rotate();
            } else {
                self.reserve(alloc, 1);
                return self.pushId();
            }
        }

        fn swapRemove(self: *Self, index: u32) T {
            const result = self.pool.ptr[index];
            const end = self.pool.len - 1;
            if (index == end) {
                self.pool.len -= 1;
                self.pool_ids[index] = .NULL;
                return result;
            } else {
                self.pool.len -= 1;
                self.pool.ptr[index] = self.pool.ptr[end];
                const end_id = self.pool_ids[end];
                self.pool_ids[index] = end_id;
                self.index.ptr[end_id.id] = index;
                return result;
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
            self.index.ptr[id.id] = @intCast(index);
            return id;
        }

        pub fn pop(self: *Self, id: Id) ObjectPoolError!T {
            const pool_index = self.index.ptr[id.id];
            const pool_id = self.pool_ids[pool_index];
            if (pool_id != id) return ObjectPoolError.IdMismatch;
            self.free.ptr[self.free.len] = id;
            self.free.len += 1;
            return self.swapRemove(pool_index);
        }
    };
}
