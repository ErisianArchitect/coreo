
const std = @import("std");



pub fn XxHash64AutoHasher(comptime SEED: u64) type {
    return struct {
        pub fn hash(value: anytype) u64 {
            var hasher = std.hash.XxHash64.init(SEED);
            std.hash.autoHash(&hasher, value);
            return hasher.final();
        }
    };
}

pub fn XxHash64HashContext(comptime SEED: u64, comptime Key: type) type {
    return struct {
        const Self = @This();
        
        const Hasher = XxHash64AutoHasher(SEED);
        
        pub fn hash(_: Self, key: Key) u64 {
            return Hasher.hash(key);
        }

        pub fn eql(_: Self, lhs: Key, rhs: Key) bool {
            return lhs == rhs;
        }
    };
}

