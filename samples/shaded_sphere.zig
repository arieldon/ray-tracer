const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Define constants for the scene.
    const canvas_pixels = 400;
    const wall_z = 10;
    const wall_size = 7.0;
    const half = wall_size / 2.0;
    const pixel_size = wall_size / @intToFloat(f32, canvas_pixels);
    const ray_origin = rt.tup.point(0, 0, -5);

    // Create a light source above, behind, and to the left of the eye.
    const light_position = rt.tup.point(-10, 10, -10);
    const light_color = rt.cnv.color(1, 1, 1);
    const light = rt.lht.PointLight{
        .position = light_position,
        .intensity = light_color
    };

    // Create a purple sphere.
    var sphere = rt.sph.sphere();
    sphere.shape.material.color = rt.cnv.color(1, 0.2, 1);

    // Create a canvas.
    var canvas = try rt.cnv.canvas(allocator, canvas_pixels, canvas_pixels);
    defer canvas.deinit();

    // Allocate a list to store intersections.
    var intersections = std.ArrayList(rt.int.Intersection).init(allocator);
    defer intersections.deinit();

    var y: u32 = 0;
    while (y < canvas_pixels) : (y += 1) {
        const world_y = half - pixel_size * @intToFloat(f32, y);

        var x: u32 = 0;
        while (x < canvas_pixels) : (x += 1) {
            const world_x = -half + pixel_size * @intToFloat(f32, x);
            const position = rt.tup.point(world_x, world_y, wall_z);
            const ray = rt.ray.ray(ray_origin, rt.tup.normalize(position - ray_origin));

            // Calculate ray-sphere intersections. Upon intersection, compute
            // pixel color based on the scene's lighting.
            try rt.sph.intersect(&intersections, sphere, ray);
            if (rt.int.hit(&intersections)) |hit| {
                const point = rt.ray.position(ray, hit.t);
                const normal = rt.sph.normal_at(hit.shape, point);
                const eye = -ray.direction;
                const color = rt.mtl.lighting(
                    hit.shape,
                    light,
                    point,
                    eye,
                    normal,
                    false);
                canvas.writePixel(x, y, color);
            }

            // Clear list of intersections.
            intersections.items.len = 0;
        }
    }

    // Create a new file in the current working directory.
    const file = try std.fs.cwd().createFile("shaded_sphere.ppm", .{});
    defer file.close();

    // Write contents of canvas as a viewable PPM file.
    try canvas.toPPM(file.writer());
}
