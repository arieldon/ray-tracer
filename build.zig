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
}

pub const ray_tracer = std.build.Pkg{
    .name = "ray-tracer",
    .path = std.build.FileSource.relative("src/main.zig"),
};
