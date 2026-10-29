
const std = @import("std");

const debug = @import("debug");
const comp = @import("comp");

const CFG = @import("CFG");

const Alloc = std.mem.Allocator;
const HashMap = std.HashMapUnmanaged;

pub fn TypeMapUnmanaged(comptime T: type) type {
    return struct {
        const Self = @This();
        
        const Context = struct {
            pub fn hash(_: Context, key: u32) u64 {
                const SEED: u64 = comptime 10142869613977478491;
                var hasher = std.hash.XxHash64.init(SEED);
                std.hash.autoHash(&hasher, key);
                return hasher.final();
            }

            pub fn eql(_: Context, lhs: u32, rhs: u32) bool {
                return lhs == rhs;
            }
        };

        pub const Map = HashMap(u32, T, Context, 80);

        map: Map = .empty,

        pub const empty: Self = .{.map = .empty};

        // const PrivateToken = opaque{comptime { _ = Self; }};
        // const Seal = comp.typing.GenericOpaqueSeal(PrivateToken);

        pub inline fn keyFor(comptime Key: type) u32 {
            return comptime comp.typing.uniqueId(Key);
        }

        pub inline fn get(self: Self, comptime Key: type) ?T {
            return self.map.get(keyFor(Key));
        }

        pub inline fn getRef(self: Self, comptime Key: type) ?*const T {
            return self.map.getPtr(keyFor(Key));
        }

        pub inline fn getMut(self: Self, comptime Key: type) ?*T {
            return self.map.getPtr(keyFor(Key));
        }

        pub inline fn contains(self: Self, comptime Key: type) bool {
            return self.map.contains(keyFor(Key));
        }

        pub inline fn insert(self: *Self, alloc: Alloc, comptime Key: type, value: T) !void {
            try self.map.put(alloc, keyFor(Key), value);
        }

        pub inline fn fetchInsert(self: *Self, alloc: Alloc, comptime Key: type, value: T) !?T {
            return if (try self.map.fetchPut(alloc, keyFor(Key), value)) |kv| kv.value else null;
        }

        pub inline fn remove(self: *Self, comptime Key: type) !bool {
            return self.map.remove(keyFor(Key));
        }

        pub inline fn fetchRemove(self: *Self, comptime Key: type) ?T {
            return if(self.map.fetchRemove(keyFor(Key))) |kv| kv.value else null;
        }
    };
}
