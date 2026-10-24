
const std = @import("std");

const vec = @import("vec.zig");
const gen_id = @import("gen_id.zig");
const object_pool = @import("object_pool.zig");
const slot_map = @import("slot_map.zig");

pub const VecUnmanaged = vec.VecUnmanaged;
pub const VecManaged = vec.VecManaged;

pub const GenId = gen_id.GenId;
pub const PoolId = object_pool.PoolId;
pub const ObjectPoolError = object_pool.ObjectPoolError;
pub const ObjectPoolUnmanaged = object_pool.ObjectPoolUnmanaged;

comptime {
    std.testing.refAllDecls(vec);
}
