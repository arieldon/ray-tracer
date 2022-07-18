const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    // This sample demonstrates the Fresnel effect, which describes the way
    // light behaves on transparent surfaces. With a large angle between the
    // surface normal and the eye, the light refracts more than it reflects. As
    // this angle decreases, light tends to reflect more than it refracts.

    const allocator = std.heap.page_allocator;

    // Initialize the checkered plane that serves as the bottom of the lake.
    const bottom = rt.pln.Plane{
        .shape = .{
            .shape_type = .plane,
            .transform = rt.mat.translation(0, -3, 0),
            .material = .{
                .ambient = 1.0,
                .pattern = .{
                    .a = rt.cnv.Color{0.85, 0, 0},
                    .b = rt.cnv.Color{0.3, 0.85, 0.15},
                    .color_map = rt.pat.checker,
                },
            },
            .transform = rt.mat.translation(0, -15, 0),
        },
    };

    // For some reason, the program crashes during runtime when initializing
    // this field in the constant directly above.
    bottom.shape.material.pattern.?.transform = rt.mat.scaling(3, 3, 3);

    // Initialize transparent plane that acts as lake water.
    const water = rt.pln.Plane{
        .shape = .{
            .shape_type = .plane,
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
        .shape = .{
            .shape_type = .plane,
            .transform = rt.mat.mul(rt.mat.translation(0, 0, 30), rt.mat.rotationX(std.math.pi / 2.0)),
            .material = .{
                .transparency = 0.75,
                .pattern = .{
                    .a = rt.cnv.Color{1, 1, 1},
                    .b = rt.cnv.Color{0.5, 0.5, 0.5},
                    .color_map = rt.pat.checker,
                },
            },
        },
    };
    far.shape.material.pattern.?.transform = rt.mat.scaling(0.25, 0.25, 0.25);

    var world = rt.wrd.world(allocator);
    defer world.deinit();

    world.light.position = rt.tup.point(0, 40, -10);

    try world.planes.append(water);
    try world.planes.append(bottom);
    try world.planes.append(water);
    try world.planes.append(far);

    const image_width = 1024;
    const image_height = 512;
    const field_of_view = std.math.pi / 2.0;
    var camera = rt.cam.camera(image_width, image_height, field_of_view);

    const from = rt.tup.point(0, 1.5, -5);
    const to = rt.tup.point(0, 1, 0);
    const up = rt.tup.vector(0, 1, 0);
    camera.transform = rt.trm.viewTransform(from, to, up);

    var canvas = try rt.cam.render(allocator, camera, world);
    defer canvas.deinit();

    const file = try std.fs.cwd().createFile("fresnel.ppm", .{});
    defer file.close();

    try canvas.toPPM(file.writer());
}
