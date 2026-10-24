
const std = @import("std");

const vec = @import("vec.zig");
const object_pool = @import("object_pool.zig");

pub const VecUnmanaged = vec.VecUnmanaged;
pub const VecManaged = vec.VecManaged;

pub const PoolId = object_pool.PoolId;
pub const ObjectPoolError = object_pool.ObjectPoolError;
pub const ObjectPoolUnmanaged = object_pool.ObjectPoolUnmanaged;

comptime {
    std.testing.refAllDecls(vec);
}
