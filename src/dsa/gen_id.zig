
pub fn GenId(comptime tag: anytype) type {
    return packed struct(u64) {
        const Self = @This();
        const TAG = tag;

        pub const NULL: Self = .{.id = 0, .gen = 0};

        id: u32,
        gen: u32,

        pub inline fn init(id: u32, gen: u32) Self {
            return .{.id = id, .gen = gen};
        }

        pub inline fn initFirstGen(id: u32) Self {
            return .init(id, 1);
        }

        pub inline fn isNull(self: Self) bool {
            return self == NULL;
        }

        pub inline fn rotate(self: Self) Self {
            var new = self;
            new.gen +%= 2;
            return self;
        }
    };
}
