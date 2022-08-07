const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const con = @import("cone.zig");
const cub = @import("cube.zig");
const cyl = @import("cylinder.zig");
const grp = @import("group.zig");
const int = @import("intersection.zig");
const lht = @import("light.zig");
const mat = @import("matrix.zig");
const mtl = @import("material.zig");
const pat = @import("pattern.zig");
const pln = @import("plane.zig");
const ray = @import("ray.zig");
const sph = @import("sphere.zig");
const tri = @import("triangle.zig");
const tup = @import("tuple.zig");

// Set limit for number of recursive calls or ray casts allowed to calculate
// color of reflection or refraction.
const ray_depth_limit: usize = 5;

pub const World = struct {
    allocator: std.mem.Allocator,

    light: lht.PointLight = .{
        .position = tup.point(-10, 10, -10),
        .intensity = cnv.Color{1, 1, 1},
   },

    spheres: []const sph.Sphere = &.{},
    planes: []const pln.Plane = &.{},
    cubes: []const cub.Cube = &.{},
    cylinders: []const cyl.Cylinder = &.{},
    cones: []const con.Cone = &.{},
    triangles: []const tri.Triangle = &.{},
    groups: []grp.Group = &.{},

    pub fn intersect(self: *const World, r: ray.Ray, xs: *std.ArrayList(int.Intersection)) void {
        for (self.spheres) |sphere| sphere.intersect(r, xs) catch unreachable;
        for (self.planes) |plane| plane.intersect(r, xs) catch unreachable;
        for (self.cubes) |cube| cube.intersect(r, xs) catch unreachable;
        for (self.cylinders) |cylinder| cylinder.intersect(r, xs) catch unreachable;
        for (self.cones) |cone| cone.intersect(r, xs) catch unreachable;
        for (self.triangles) |triangle| triangle.intersect(r, xs) catch unreachable;
        for (self.groups) |*group| group.intersect(r, xs) catch unreachable;
        int.sortIntersections(xs.items);
    }
};

fn shadeHit(world: *const World, comps: int.Computation) cnv.Color {
    return shadeHitInternal(world, comps, ray_depth_limit);
}

fn shadeHitInternal(world: *const World, comps: int.Computation, remaining: usize) cnv.Color {
    const over_point = comps.point + comps.normal * @splat(4, @as(f64, tup.epsilon));
    const shadowed = isShadowed(world, over_point);
    const surface = mtl.lighting(
        comps.shape_attrs,
        world.light,
        over_point,
        comps.eye,
        comps.normal,
        shadowed);

    // In the most general case, a certain fraction of the light is reflected
    // from the interface, and the remainder is refracted, assuming the
    // material of the shape has reflective and refractive properties.
    const reflected = reflectedColorInternal(world, comps, remaining);
    const refracted = refractedColorInternal(world, comps, remaining);

    const material = comps.shape_attrs.material;
    if (material.reflective > 0 and material.transparency > 0) {
        const reflectance = @splat(3, int.schlick(comps));
        return surface + reflected * reflectance +
                         refracted * (@splat(3, @as(f64, 1.0)) - reflectance);
    }

    return surface + reflected + refracted;
}

pub fn colorAt(world: *const World, r: ray.Ray) cnv.Color {
    return colorAtInternal(world, r, ray_depth_limit);
}

fn colorAtInternal(world: *const World, r: ray.Ray, remaining: usize) cnv.Color {
    var intersections = std.ArrayList(int.Intersection).init(world.allocator);
    defer intersections.deinit();

    world.intersect(r, &intersections);
    if (int.hit(intersections.items)) |hit| {
        const comps = int.prepareComputationsForRefraction(hit, r, intersections.items);
        return shadeHitInternal(world, comps, remaining);
    }
    return cnv.color(0, 0, 0);
}

fn isShadowed(world: *const World, p: tup.Point) bool {
    // Measure distance from point to light source and calculate magnitude of
    // resulting vector.
    const v = world.light.position - p;
    const distance = tup.magnitude(v);

    // Create shadow ray to cast. If between the point and the light source,
    // this ray intersects an object, then a shadow engulfs that object.
    const direction = tup.normalize(v);
    const shadow_ray = ray.ray(p, direction);

    var intersections = std.ArrayList(int.Intersection).init(world.allocator);
    defer intersections.deinit();

    world.intersect(shadow_ray, &intersections);

    // Again, if the shadow ray intersects an object at some point in the
    // distance between the light source and the point, then the object lies
    // within a shadow.
    if (int.hit(intersections.items)) |hit| {
        return hit.shape_attrs.material.cast_shadow and hit.t < distance;
    }
    return false;
}

fn reflectedColor(world: *const World, comps: int.Computation) cnv.Color {
    return reflectedColorInternal(world, comps, ray_depth_limit);
}

fn reflectedColorInternal(world: *const World, comps: int.Computation, remaining: usize) cnv.Color {
    const black = cnv.Color{0, 0, 0};

    // Limit recursion to handle rays that bounce between parallel mirrors.
    if (remaining == 0) return black;

    // In this case, the ray intersects a nonreflective surface, so reflection
    // stops.
    if (comps.shape_attrs.material.reflective == 0) return black;

    const reflect_ray = ray.Ray{
        .origin = comps.point + comps.normal * @splat(4, @as(f64, tup.epsilon)),
        .direction = comps.reflect,
    };
    const color = colorAtInternal(world, reflect_ray, remaining - 1);

    return color * @splat(3, comps.shape_attrs.material.reflective);
}

fn refractedColor(world: *const World, comps: int.Computation) cnv.Color {
    return refractedColorInternal(world, comps, ray_depth_limit);
}

fn refractedColorInternal(world: *const World, comps: int.Computation, remaining: usize) cnv.Color {
    const black = cnv.Color{0, 0, 0};

    // Stop if the computation reaches the ray depth or number of recursive.
    if (remaining == 0) return black;

    // Stop if the ray hits a material through which light doesn't transmit.
    if (comps.shape_attrs.material.transparency == 0) return black;

    // Find the ratio of the first to the second refractive index.
    const n_ratio = comps.n1 / comps.n2;

    // Compute the cosine of the angle of incidence.
    const cos_i = tup.dot(comps.eye, comps.normal);

    // Use the Pythagorean trigonometric identity to calculate the sine-squared
    // of the angle of refraction.
    const sin2_t = (n_ratio * n_ratio) * (1 - cos_i * cos_i);

    // Total internal reflection of light from a denser medium occurs if the
    // angle of incidence is greater than the critical angle, where physics
    // defines the critical angle as the smallest angle at which total internal
    // reflection occurs. In this case, no transmission of light occurs from
    // one medium to the other.
    if (sin2_t > 1) return black;

    // Use the Pythagorean identity again to find the cosine of the angle of
    // refraction.
    const cos_t = @sqrt(1.0 - sin2_t);

    const refract_ray = ray.Ray{
        .origin = comps.point - comps.normal * @splat(4, @as(f64, tup.epsilon)),
        .direction = comps.normal * @splat(4, n_ratio * cos_i - cos_t) - comps.eye * @splat(4, n_ratio),
    };

    const color = colorAtInternal(world, refract_ray, remaining - 1);
    return color * @splat(3, comps.shape_attrs.material.transparency);
}
