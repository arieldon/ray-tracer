const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const tests = b.addTest("src/main.zig");
    tests.setBuildMode(mode);
    tests.setTarget(target);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&tests.step);

    inline for (.{
        .{ .bin_name = "red-sphere", .source_path = "samples/red_sphere.zig" },
        .{ .bin_name = "shaded-sphere", .source_path = "samples/shaded_sphere.zig" },
        .{ .bin_name = "sphere-world", .source_path = "samples/sphere_world.zig" },
    }) |sample| {
        // Construct the sample.
        const exe = b.addExecutable(sample.bin_name, sample.source_path);
        exe.setTarget(target);
        exe.setBuildMode(mode);

        // Link the library.
        exe.addPackage(ray_tracer);

        // Build the sample.
        exe.install();
    }
}

pub const ray_tracer = std.build.Pkg{
    .name = "ray-tracer",
    .path = std.build.FileSource.relative("src/main.zig"),
};
