
pub inline fn cbool(b: c_int) bool {
    return b != 0;
}

pub inline fn isNull(any: anytype) bool {
    return any == null;
}
