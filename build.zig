const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const tests = b.addTest("src/main.zig");
    tests.setBuildMode(mode);
    tests.setTarget(target);
    tests.addPackage(ray_tracer);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&tests.step);

    // Construct the only sample so far.
    const exe = b.addExecutable("red-sphere", "samples/red_sphere.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    // Link the library.
    exe.addPackage(ray_tracer);

    // Build the sample.
    exe.install();
}

pub const ray_tracer = std.build.Pkg{
    .name = "ray-tracer",
    .path = std.build.FileSource.relative("src/main.zig"),
};
