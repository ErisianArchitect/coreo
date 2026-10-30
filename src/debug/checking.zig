
const std = @import("std");
const CFG = @import("CFG");

const comp = @import("comp");
const dsa = @import("dsa");
const StackVec = dsa.StackVec;

pub fn checkAllDecls(comptime check: bool, comptime types: []const type) void {comptime {
    if (!check) return;
    @setEvalBranchQuota(std.math.maxInt(u32));
    for (types) |t| {
        std.testing.refAllDecls(t);
    }
}}

pub fn checkInterface(comptime check: bool, comptime Interface: type, comptime Impl: type) void {comptime {
    if (!check) return;
    @setEvalBranchQuota(std.math.maxInt(u32));
    const declarations = std.meta.declarations(Interface);
    var missing = StackVec([]const u8, declarations.len).init();
    for (declarations) |decl| {
        const decl_field = @field(Interface, decl);
        const Decl = @TypeOf(decl_field);
        if (@typeInfo(Decl) == .@"fn" and !@hasDecl(Impl, decl)) {
            missing.push(decl);
        }
    }
    if (missing.len == 0) return;
    var missing_names: [missing.len][]const u8 = undefined;
    @memcpy(&missing_names, missing.items[0..missing.len]);
    const list_str = comp.joinSlices(u8, "\n", comp.internArray([]const u8, missing_names));
    @compileError(std.fmt.comptimePrint("Missing declarations in {s}:\n{s}", .{@typeName(Impl), list_str}));
}}
