const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;
const OptionsStep = std.build.OptionsStep;

const examples = [2][]const u8{ "main", "custom_types" };

const include_dir = switch (builtin.target.os.tag) {
    .linux => "/usr/include",
    .windows => "C:\\Program Files\\PostgreSQL\\14\\include",
    .macos => "/opt/homebrew/opt/libpq",
    else => "/usr/include",
};

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    b.addSearchPrefix(include_dir);

    const db_uri = b.option(
        []const u8,
        "db",
        "Specify the database url",
    ) orelse "postgresql://postgresql:postgresql@localhost:5432";

    const db_options = b.addOptions();
    db_options.addOption([]const u8, "db_uri", db_uri);

    inline for (examples) |example| {
        const exe = b.addExecutable(example, "examples/" ++ example ++ ".zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.addOptions("build_options", db_options);
        exe.addPackagePath("postgres", "src/postgres.zig");
        exe.linkSystemLibrary("pq");

        exe.install();

        const run_cmd = exe.run();
        run_cmd.step.dependOn(b.getInstallStep());

        const run_step = b.step(example, "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    const lib = b.addStaticLibrary("zig-postgres", "src/postgres.zig");
    lib.setTarget(target);
    lib.setBuildMode(mode);
    lib.addOptions("build_options", db_options);

    lib.linkSystemLibrary("pq");

    const tests = b.addTest("tests.zig");
    tests.setBuildMode(mode);
    tests.setTarget(target);
    tests.linkSystemLibrary("pq");
    tests.addPackagePath("postgres", "src/postgres.zig");
    tests.addOptions("build_options", db_options);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&tests.step);
}
