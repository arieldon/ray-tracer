const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const image_width = 1024;
    const image_height = 1024;
    const field_of_view = std.math.pi / 3.0;

    const floor = rt.Plane{
        .common_attrs = .{
            .material = .{
                .pattern = .{
                    .a = rt.Color{0, 0, 0},
                    .b = rt.Color{0.25, 0.25, 0.25},
                    .color_map = rt.checker,
                },
                .reflective = 0.25,
            },
        },
    };

    var sphere = rt.Sphere{
        .common_attrs = .{
            .material = .{ .color = rt.Color{1, 0.3, 0.25} },
            .transform = rt.mat.translation(0, 1, 0.5),
        },
    };

    var world = rt.World{
        .allocator = allocator,
        .light = .{
            .position = rt.tup.point(0, 30, -5),
            .intensity = rt.Color{1, 1, 1},
        },
        .spheres = &.{ sphere },
        .planes = &.{ floor },
    };

    var camera = rt.camera(image_width, image_height, field_of_view);
    camera.transform = rt.trm.viewTransform(
        rt.tup.point(0, 1.5, -5), rt.tup.point(0, 1, 0), rt.tup.vector(0, 1, 0));

    var canvas = try rt.render(allocator, camera, world);
    defer canvas.deinit();

    const file = try std.fs.cwd().createFile("reflective_floor.ppm", .{});
    defer file.close();

    try canvas.toPPM(file.writer());
}
