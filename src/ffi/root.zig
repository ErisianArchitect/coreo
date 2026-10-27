
pub inline fn cbool(b: c_int) bool {
    return b != 0;
}

pub inline fn isNull(any: anytype) bool {
    return any == null;
}

pub inline fn castPtr(comptime T: type, ptr: *const anyopaque) *const T {
    return @ptrCast(ptr);
}

pub inline fn readAs(comptime T: type, ptr: *const anyopaque) T {
    return castPtr(T, ptr).*;
}
