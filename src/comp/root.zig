
const std = @import("std");

pub const typing = @import("typing.zig");


pub fn undefFields(comptime T: type, obj: *T) void {
    inline for (comptime std.meta.fieldNames(T)) |name| {
        @field(obj, name) = undefined;
    }
}
