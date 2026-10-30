const std = @import("std");

pub const dsa = @import("dsa");
pub const comp = @import("comp");
pub const debug = @import("debug");
pub const ffi = @import("ffi");
pub const str = @import("str");

comptime {
    @import("debug").checking.checkAllDecls(
        @import("CFG").CHECK,
        &.{
            dsa,
            comp,
            debug,
            ffi,
            str,
        },
    );
}

const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

test "VecManaged Test" {
    const VecManaged = dsa.VecManaged;
    var dgpa = std.heap.DebugAllocator(.{.thread_safe = false}).init;
    const alloc = dgpa.allocator();
    var vec = VecManaged(u32).init(alloc);
    defer vec.deinit();
    try expectEqual(0, vec.slice().len);
    try expectEqual(0, vec.getLen());
    try expectEqual(0, vec.inner.len);
    vec.push(0);
    try expectEqual(1, vec.slice().len);
    try expectEqual(1, vec.getLen());
    try expectEqual(1, vec.inner.len);
    try expectEqual(0, vec.slice()[0]);
    vec.push(69);
    try expectEqual(0, vec.slice()[0]);
    try expectEqual(69, vec.slice()[1]);
    try expectEqual(69, vec.pop());
    try expectEqual(0, vec.pop());
    try expectEqual(null, vec.pop());
    for (0..10) |i| {
        vec.push(@intCast(i));
    }
    vec.extractIf({}, 1, 9, struct {
        pub fn extract(_: void, index: usize, _: *u32) bool {
            if (index & 1 == 1) return true;
            return false;
        }
    }.extract);
    try expectEqual(6, vec.slice().len);
    try expectEqual(0, vec.slice()[0]);
    try expectEqual(2, vec.slice()[1]);
    try expectEqual(4, vec.slice()[2]);
    try expectEqual(6, vec.slice()[3]);
    try expectEqual(8, vec.slice()[4]);
    try expectEqual(9, vec.slice()[5]);
}

test "Object Pool" {
    const ObjectPool = dsa.ObjectPoolUnmanaged;
    var dgpa = std.heap.DebugAllocator(.{.thread_safe = false}).init;
    const alloc = dgpa.allocator();
    var pool = ObjectPool(u32).init(alloc);
    defer pool.deinit(alloc);
    const v0 = pool.push(alloc, 0);
    const v1 = pool.push(alloc, 1);
    const v2 = pool.push(alloc, 2);
    try expectEqual(0, (try pool.get(v0)));
    try expectEqual(1, (try pool.get(v1)));
    try expectEqual(2, (try pool.get(v2)));
    const v1_val = try pool.pop(v1);
    try expectEqual(v1_val, 1);

    try expectEqual(0, (try pool.get(v0)));
    try expectEqual(2, (try pool.get(v2)));
    try expectEqual(error.IdMismatch, pool.get(v1));
    try expectEqual(2, pool.pool.len);
    {
        const pool_slice = pool.slice();
        try expectEqual(0, pool_slice[0]);
        try expectEqual(2, pool_slice[1]);
    }
    const v3 = pool.push(alloc, 3);
    {
        const pool_slice = pool.slice();
        try expectEqual(0, pool_slice[0]);
        try expectEqual(2, pool_slice[1]);
        try expectEqual(3, pool_slice[2]);
    }
    {
        const v0_pop = pool.pop(v0);
        try expectEqual(0, v0_pop);
        const pool_slice = pool.slice();
        try expectEqual(2, pool_slice.len);
        try expectEqual(3, pool_slice[0]);
        try expectEqual(2, pool_slice[1]);
    }
    {
        const v3_pop = pool.pop(v3);
        try expectEqual(3, v3_pop);
        const pool_slice = pool.slice();
        try expectEqual(1, pool_slice.len);
        try expectEqual(2, pool_slice[0]);
    }
    {
        const v2_pop = pool.pop(v2);
        try expectEqual(2, v2_pop);
        const pool_slice = pool.slice();
        try expectEqual(0, pool_slice.len);
    }
    
}

test "Static Type Map" {
    @setEvalBranchQuota(comp.MAX_BRANCH_QUOTA);
    const t = struct {
        fn Ty(comptime tag: usize) type {
            return struct {
                const TAG = tag;
            };
        }

        fn manyTyPairs(comptime start: usize, comptime end: usize) []const struct {type, usize} {
            const size = end - start;
            var pairs: [size]struct {type, usize} = undefined;
            for (start..end, 0..) |tag, i| {
                pairs[i] = .{Ty(tag), tag};
            }
            return comp.internArray(struct {type, usize}, pairs);
        }
    };
    const pairs = comptime t.manyTyPairs(1000, 2000);
    const map = comptime comp.StaticTypeMap(usize).init(pairs);
    try expect(map.maxBucketSize() < 10);
    inline for (pairs, 1000..) |p, n| {
        try expectEqual(n, p[1]);
        try expectEqual(p[1], map.val(p[0]));
        try expectEqual(n, map.val(p[0]));
    }
}
