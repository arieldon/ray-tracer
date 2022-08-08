const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const canvas_pixels = 400;
    const wall_z = 10;
    const wall_size = 7.0;
    const pixel_size = wall_size / @intToFloat(f64, canvas_pixels);
    const half = wall_size / 2.0;

    const sphere = rt.sph.Sphere{};
    const color = rt.cnv.color(1, 0, 0);
    const ray_origin = rt.tup.point(0, 0, -5);

    var canvas = try rt.cnv.canvas(allocator, canvas_pixels, canvas_pixels);
    defer canvas.deinit();

    var intersections = std.ArrayList(rt.int.Intersection).init(allocator);
    defer intersections.deinit();

    var y: u32 = 0;
    while (y < canvas_pixels) : (y += 1) {
        const world_y = half - pixel_size * @intToFloat(f64, y);

        var x: u32 = 0;
        while (x < canvas_pixels) : (x += 1) {
            const world_x = -half + pixel_size * @intToFloat(f64, x);
            const position = rt.tup.point(world_x, world_y, wall_z);
            const r = rt.ray.ray(ray_origin, rt.tup.normalize(position - ray_origin));

            // Calculate ray-sphere intersections and paint hits red. Points
            // where no intersection occurs remain their default black.
            try sphere.intersect(r, &intersections);
            if (rt.int.hit(intersections.items) != null) canvas.writePixel(x, y, color);

            // Reset list.
            intersections.items.len = 0;
        }
    }

    // Create a new file in the current working directory.
    const file = try std.fs.cwd().createFile("red_sphere.ppm", .{});
    defer file.close();

    // Output contents of canvas as a viewable PPM file.
    try canvas.toPPM(file.writer());
}
