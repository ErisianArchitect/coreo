
const std = @import("std");

const comp = @import("comp");

const Allocator = std.mem.Allocator;

const GenId = @import("dsa").GenId;



const Sealed = comp.typing.GenericOpaqueSeal(opaque{});

pub fn SlotMap(comptime T: type) type {
    return extern struct {
        const Self = @This();

        pub const Id = GenId(Sealed(T));

        slots: [*]T,
        ids: [*]Id,
        free: [*]Id,
        // Keep SlotMap bounded to 4.2B, that should be enough.
        // Now @sizeOf(SlotMap(Any)) == 40
        len: u32,
        free_top: u32,
        cap: u32,
    };
}
