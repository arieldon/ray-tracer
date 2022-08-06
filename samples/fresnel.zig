const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    // This sample demonstrates the Fresnel effect, which describes the way
    // light behaves on transparent surfaces. With a large angle between the
    // surface normal and the eye, the light refracts more than it reflects. As
    // this angle decreases, light tends to reflect more than it refracts.

    const allocator = std.heap.page_allocator;

    // Initialize the checkered plane that serves as the bottom of the lake.
    var bottom = rt.pln.Plane{
        .common_attrs = .{
            .transform = rt.mat.translation(0, -15, 0),
            .material = .{
                .ambient = 1.0,
                .pattern = .{
                    .a = rt.cnv.Color{0.85, 0.1, 0.1},
                    .b = rt.cnv.Color{0.3, 0.85, 0.15},
                    .color_map = rt.pat.checker,
                },
            },
        },
    };

    // For some reason, the program crashes during runtime when initializing
    // this field in the constant directly above.
    bottom.common_attrs.material.pattern.?.transform = rt.mat.scaling(3, 3, 3);

    // Initialize transparent plane that acts as lake water.
    const water = rt.pln.Plane{
        .common_attrs = .{
            .material = .{
                .diffuse = 0.1,
                .shininess = 300.0,
                .refractive_index = 1.33,
                .transparency = 1.0,
                .reflective = 0.9,
            },
        },
    };

    // Initialize the far wall that simulates some sort of scenery in the
    // distance.
    var far = rt.pln.Plane{
        .common_attrs = .{
            .transform = rt.mat.mul(rt.mat.translation(0, 0, 30), rt.mat.rotationX(std.math.pi / 2.0)),
            .material = .{
                .transparency = 0.75,
                .specular = 0.0,
                .pattern = .{
                    .a = rt.cnv.Color{1, 1, 1},
                    .b = rt.cnv.Color{0.5, 0.5, 0.5},
                    .color_map = rt.pat.checker,
                },
            },
        },
    };
    far.common_attrs.material.pattern.?.transform = rt.mat.scaling(0.25, 0.25, 0.25);

    const world = rt.wrd.World{
        .allocator = allocator,
        .light = .{
            .position = rt.tup.point(0, 30, -15),
            .intensity = rt.cnv.Color{1, 1, 1},
        },
        .planes = &.{ bottom, water, far },
    };

    const image_width = 512;
    const image_height = 256;
    const field_of_view = std.math.pi / 2.0;
    var camera = rt.cam.camera(image_width, image_height, field_of_view);

    const from = rt.tup.point(0, 1.5, -15);
    const to = rt.tup.point(0, 1, 0);
    const up = rt.tup.vector(0, 1, 0);
    camera.transform = rt.trm.viewTransform(from, to, up);

    var canvas = try rt.cam.render(allocator, camera, world);
    defer canvas.deinit();

    const file = try std.fs.cwd().createFile("fresnel.ppm", .{});
    defer file.close();

    try canvas.toPPM(file.writer());
}
