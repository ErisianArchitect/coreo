
const std = @import("std");

const vec = @import("vec.zig");
const stack_vec = @import("stack_vec.zig");
const gen_id = @import("gen_id.zig");
const object_pool = @import("object_pool.zig");
const slot_map = @import("slot_map.zig");

comptime {
    @import("debug").checking.checkAllDecls(
        @import("CFG").CHECK,
        &.{
            vec,
            stack_vec,
            gen_id,
            object_pool,
            slot_map,
        },
    );
}

pub const VecUnmanaged = vec.VecUnmanaged;
pub const VecManaged = vec.VecManaged;
pub const StackVec = stack_vec.StackVec;

pub const GenId = gen_id.GenId;
pub const ObjectPoolError = object_pool.ObjectPoolError;
pub const ObjectPoolUnmanaged = object_pool.ObjectPoolUnmanaged;
