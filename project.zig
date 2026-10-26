// DO NOT MODIFY THIS FILE IF YOU ARE NOT IN THE `build_tools` REPOSITORY!
// version: 0.1.0

const std = @import("std");

const Build = std.Build;

pub const Module = std.Build.Module;
pub const Import = std.Build.Module.Import;

pub fn imp(name: []const u8, module: *Module) Import {
    return .{.name = name, .module = module};
}

/// Connect modules together using `addImport`. This will connect every module
/// to every other module.
pub fn connectImports(imports: []const Import) void {
    for (imports) |a| {
        for (imports) |b| {
            a.module.addImport(b.name, b.module);
        }
    }
}

pub const ConnectionType = enum {
    OneWay,
    TwoWay,
};

/// Use a fixed_buffer_capacity that will fit the number of imports
/// you want to connect. A good recommended size is 16 for small projects,
/// 32 for medium projects, and 64 or more for much larger ones. But you
/// can use whatever number you want.
pub fn Imports(comptime fixed_buffer_capacity: usize) type {
    return struct {
        const Self = @This();

        buf: [fixed_buffer_capacity]Import,
        connection_types: [fixed_buffer_capacity]ConnectionType,
        len: usize,

        pub fn init() Self {
            return .{.buf = undefined, .connection_types = undefined, .len = 0,};
        }

        pub fn slice(self: *const Self) []const Import {
            return self.buf[0..self.len];
        }

        pub fn sliceMut(self: *Self) []Import {
            return self.buf[0..self.len];
        }

        pub fn connectAdv(self: *Self, comptime connection_type: ConnectionType, import: Import) void {
            if (self.len >= self.buf.len) @panic("Buffer overflow. Use a higher number for fixed_buffer_capacity, nimwit.");
            for (self.slice(), 0..) |other, i| {
                if (self.connection_types[i] == .OneWay) continue;
                switch (comptime connection_type) {
                    .OneWay => {
                        other.module.addImport(import.name, import.module);
                    },
                    .TwoWay => {
                        other.module.addImport(import.name, import.module);
                        import.module.addImport(other.name, other.module);
                        import.module.addImport(import.name, import.module);
                    }
                }
            }
            self.buf[self.len] = import;
            self.connection_types[self.len] = connection_type;
            self.len += 1;
        }

        pub fn connect(self: *Self, import: Import) void {
            self.connectAdv(.TwoWay, import);
        }

        pub fn connectOneWay(self: *Self, import: Import) void {
            self.connectAdv(.OneWay, import);
        }

        /// This should be done after all modules are connected.
        pub fn addDependency(self: *Self, name: []const u8, module: *Module) void {
            self.connectOneWay(imp(name, module));
        }

        /// This should be done after all modules are connected but before dependencies are added.
        pub fn addOptions(self: *Self, name: []const u8, options: *Build.Step.Options) void {
            if (self.len == 0) @panic("No modules to add options to.");
            const opts = options.createModule();
            self.connectAdv(.OneWay, imp(name, opts));
        }
    };
}

/// Use this to manage dual imports for a main build and a checking build.
pub fn BuildCheckImports(comptime buffer_size: usize) type {
    return struct {
        const Self = @This();

        build: Imports(buffer_size),
        check: Imports(buffer_size),

        pub fn init() Self {
            return .{.build = .init(), .check = .init()};
        }

        pub fn connect(self: *Self, name: []const u8, build_module: *Module, check_module: *Module) void {
            self.build.connect(imp(name, build_module));
            self.check.connect(imp(name, check_module));
        }

        /// Can be paired with Project.dupedCreateModule.
        pub fn connectDuped(self: *Self, name: []const u8, modules: [2]*Module) void {
            self.connect(name, modules[0], modules[1]);
        }

        /// This should be done after all modules are connected and all options are added.
        pub fn addDependency(self: *Self, name: []const u8, build_dep: *Module, check_dep: ?*Module) void {
            self.build.addDependency(name, build_dep);
            self.check.addDependency(name, check_dep orelse build_dep);
        }

        /// This should be done after all modules are connected but before dependencies are added.
        pub fn addOptions(self: *Self, name: []const u8, build_options: *Build.Step.Options, check_options: *Build.Step.Options) void {
            self.build.addOptions(name, build_options);
            self.check.addOptions(name, check_options);
        }
    };
}

pub const Project = struct {
    const Self = @This();
    
    build: *Build,

    pub fn init(build: *Build) Self {
        return .{.build = build};
    }

    pub fn addModule(self: *const Self, name: []const u8, options: Module.CreateOptions) *Module {
        return self.build.addModule(name, options);
    }

    pub fn createModule(self: *const Self, name: []const u8, options: Module.CreateOptions) *Module {
        return self.build.createModule(name, options);
    }

    pub fn dupedCreateModule(
        self: *const Self,
        comptime count: usize,
        options: Module.CreateOptions,
    ) [count]*Module {
        var modules: [count]*Module = undefined;
        inline for(0..count) |i| {
            modules[i] = self.build.createModule(options);
        }
        return modules;
    }

    pub fn path(self: *const Self, sub_path: []const u8) Build.LazyPath {
        return self.build.path(sub_path);
    }
};

