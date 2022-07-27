const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const con = @import("cone.zig");
const cub = @import("cube.zig");
const cyl = @import("cylinder.zig");
const int = @import("intersection.zig");
const lht = @import("light.zig");
const mat = @import("matrix.zig");
const mtl = @import("material.zig");
const pat = @import("pattern.zig");
const pln = @import("plane.zig");
const ray = @import("ray.zig");
const sph = @import("sphere.zig");
const tup = @import("tuple.zig");

// Set limit for number of recursive calls or ray casts allowed to calculate
// color of reflection or refraction.
const ray_depth_limit: usize = 5;

pub const World = struct {
    light: lht.PointLight,
    spheres: std.ArrayList(sph.Sphere),
    planes: std.ArrayList(pln.Plane),
    cubes: std.ArrayList(cub.Cube),
    cylinders: std.ArrayList(cyl.Cylinder),
    cones: std.ArrayList(con.Cone),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) World {
        return .{
            .light = .{
                .position = tup.point(-10, 10, -10),
                .intensity = cnv.Color{1, 1, 1},
            },
            .spheres = std.ArrayList(sph.Sphere).init(allocator),
            .planes = std.ArrayList(pln.Plane).init(allocator),
            .cubes = std.ArrayList(cub.Cube).init(allocator),
            .cylinders = std.ArrayList(cyl.Cylinder).init(allocator),
            .cones = std.ArrayList(con.Cone).init(allocator),
            .allocator = allocator,
        };
    }

    // The tests below rely on this function.
    fn defaultInit(allocator: std.mem.Allocator) !World {
        var w = World.init(allocator);

        const s1 = sph.Sphere{
            .common_attrs = .{
                .material = .{
                    .color = cnv.Color{0.8, 1.0, 0.6},
                    .diffuse = 0.7,
                    .specular = 0.2,
                },
            },
        };

        const s2 = sph.Sphere{
            .common_attrs = .{
                .transform = mat.scaling(0.5, 0.5, 0.5),
            },
        };

        // Add default spheres to the world.
        try w.spheres.appendSlice(&[_]sph.Sphere{ s1, s2 });

        return w;
    }

    pub fn deinit(self: World) void {
        self.spheres.deinit();
        self.planes.deinit();
        self.cubes.deinit();
        self.cylinders.deinit();
        self.cones.deinit();
    }

    pub fn containsSphere(self: World, s: sph.Sphere) bool {
        for (self.spheres.items) |t| if (sph.equal(s, t)) return true;
        return false;
    }

    pub fn containsPlane(self: World, p: pln.Plane) bool {
        for (self.planes.items) |q| if (std.meta.equal(p, q)) return true;
        return false;
    }

    pub fn containsCube(self: World, c: cub.Cube) bool {
        for (self.cubes.items) |d| if (std.meta.equal(c, d)) return true;
        return false;
    }

    pub fn containsCylinder(self: World, c: cyl.Cylinder) bool {
        for (self.cylinder.items) |d| if (std.meta.equal(c, d)) return true;
        return false;
    }
};

pub inline fn world(allocator: std.mem.Allocator) World {
    return World.init(allocator);
}

pub inline fn defaultWorld(allocator: std.mem.Allocator) !World {
    return World.defaultInit(allocator);
}

pub fn intersectWorld(xs: *std.ArrayList(int.Intersection), w: World, r: ray.Ray) void {
    // Cast a ray through each object in the world and append any intersections
    // to the list.

    // FIXME Handle OutOfMemory errors gracefully.
    for (w.spheres.items) |sphere| sph.intersect(xs, sphere, r) catch unreachable;
    for (w.planes.items) |plane| pln.intersect(xs, plane, r) catch unreachable;
    for (w.cubes.items) |cube| cub.intersect(xs, cube, r) catch unreachable;
    for (w.cylinders.items) |cylinder| cyl.intersect(xs, cylinder, r) catch unreachable;
    for (w.cones.items) |cone| con.intersect(xs, cone, r) catch unreachable;

    // Call hit() only to sort the intersections.
    _ = int.hit(xs.items);
}

pub fn shadeHit(w: World, comps: int.Computation) cnv.Color {
    return shadeHitInternal(w, comps, ray_depth_limit);
}

fn shadeHitInternal(w: World, comps: int.Computation, remaining: usize) cnv.Color {
    const shadowed = isShadowed(w, comps.over_point);
    const surface = mtl.lighting(
        comps.shape_attrs,
        w.light,
        comps.over_point,
        comps.eye,
        comps.normal,
        shadowed);

    // In the most general case, a certain fraction of the light is reflected
    // from the interface, and the remainder is refracted, assuming the
    // material of the shape has reflective and refractive properties.
    const reflected = reflectedColorInternal(w, comps, remaining);
    const refracted = refractedColorInternal(w, comps, remaining);

    const material = comps.shape_attrs.material;
    if (material.reflective > 0 and material.transparency > 0) {
        const reflectance = @splat(3, int.schlick(comps));
        return surface + reflected * reflectance +
                         refracted * (@splat(3, @as(f64, 1.0)) - reflectance);
    }

    return surface + reflected + refracted;
}

pub fn colorAt(w: World, r: ray.Ray) cnv.Color {
    return colorAtInternal(w, r, ray_depth_limit);
}

fn colorAtInternal(w: World, r: ray.Ray, remaining: usize) cnv.Color {
    var intersections = std.ArrayList(int.Intersection).init(w.allocator);
    defer intersections.deinit();

    intersectWorld(&intersections, w, r);
    if (int.hit(intersections.items)) |hit| {
        const comps = int.prepareComputationsForRefraction(hit, r, intersections.items);
        return shadeHitInternal(w, comps, remaining);
    }
    return cnv.color(0, 0, 0);
}

pub fn isShadowed(w: World, p: tup.Point) bool {
    // Measure distance from point to light source and calculate magnitude of
    // resulting vector.
    const v = w.light.position - p;
    const distance = tup.magnitude(v);

    // Create shadow ray to cast. If between the point and the light source,
    // this ray intersects an object, then a shadow engulfs that object.
    const direction = tup.normalize(v);
    const shadow_ray = ray.ray(p, direction);

    var intersections = std.ArrayList(int.Intersection).init(w.allocator);
    defer intersections.deinit();

    intersectWorld(&intersections, w, shadow_ray);

    // Again, if the shadow ray intersects an object at some point in the
    // distance between the light source and the point, then the object lies
    // within a shadow.
    if (int.hit(intersections.items)) |hit| {
        return hit.shape_attrs.material.cast_shadow and hit.t < distance;
    }
    return false;
}

pub fn reflectedColor(w: World, comps: int.Computation) cnv.Color {
    return reflectedColorInternal(w, comps, ray_depth_limit);
}

fn reflectedColorInternal(w: World, comps: int.Computation, remaining: usize) cnv.Color {
    const black = cnv.Color{0, 0, 0};

    // Limit recursion to handle rays that bounce between parallel mirrors.
    if (remaining == 0) return black;

    // In this case, the ray intersects a nonreflective surface, so reflection
    // stops.
    if (comps.shape_attrs.material.reflective == 0) return black;

    const reflect_ray = ray.Ray{
        .origin = comps.over_point,
        .direction = comps.reflect,
    };
    const color = colorAtInternal(w, reflect_ray, remaining - 1);

    return color * @splat(3, comps.shape_attrs.material.reflective);
}

pub fn refractedColor(w: World, comps: int.Computation) cnv.Color {
    return refractedColorInternal(w, comps, ray_depth_limit);
}

fn refractedColorInternal(w: World, comps: int.Computation, remaining: usize) cnv.Color {
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
        .origin = comps.under_point,
        .direction = comps.normal * @splat(4, n_ratio * cos_i - cos_t) - comps.eye * @splat(4, n_ratio),
    };

    const color = colorAtInternal(w, refract_ray, remaining - 1);
    return color * @splat(3, comps.shape_attrs.material.transparency);
}

test "creating a world" {
    const w = world(std.testing.allocator);
    defer w.deinit();

    const default_light = lht.PointLight{
        .position = tup.point(-10, 10, -10),
        .intensity = cnv.Color{1, 1, 1},
    };

    try expectEqual(w.spheres.items.len, 0);
    try expectEqual(w.light, default_light);
}

test "the default world" {
    const light = lht.PointLight{
        .position = tup.point(-10, 10, -10),
        .intensity = cnv.Color{1, 1, 1},
    };

    const s1 = sph.Sphere{
        .common_attrs = .{
            .material = .{
                .color = cnv.Color{0.8, 1.0, 0.6},
                .diffuse = 0.7,
                .specular = 0.2,
            },
        },
    };
    const s2 = sph.Sphere{
        .common_attrs = .{
            .transform = mat.scaling(0.5, 0.5, 0.5),
        },
    };

    const w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    try expectEqual(w.light, light);
    try expect(w.containsSphere(s1));
    try expect(w.containsSphere(s2));
}

test "intersect a world with a ray" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));

    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    intersectWorld(&xs, w, r);
    try expectEqual(xs.items.len, 4);
    try expectEqual(xs.items[0].t, 4);
    try expectEqual(xs.items[1].t, 4.5);
    try expectEqual(xs.items[2].t, 5.5);
    try expectEqual(xs.items[3].t, 6);
}

test "shading an intersection" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));
    const s = w.spheres.items[0];
    const i = int.Intersection{ .t = 4, .shape_attrs = s.common_attrs };

    const comps = int.prepareComputations(i, r);
    const c = shadeHit(w, comps);

    try expect(cnv.equal(c, cnv.color(0.38066, 0.47583, 0.2855)));
}

test "shading an intersection from the inside" {
    var w = try defaultWorld(std.testing.allocator);
    w.light = lht.PointLight{
        .position = tup.point(0, 0.25, 0),
        .intensity = cnv.Color{1, 1, 1},
    };
    defer w.deinit();

    const r = ray.ray(tup.point(0, 0, 0), tup.vector(0, 0, 1));
    const s = w.spheres.items[1];
    const i = int.Intersection{
        .t = 0.5,
        .shape_attrs = s.common_attrs,
        .normal = sph.normalAt(s, ray.position(r, 0.5)),
    };

    const comps = int.prepareComputations(i, r);
    const c = shadeHit(w, comps);

    try expect(cnv.equal(c, cnv.color(0.90498, 0.90498, 0.90498)));
}

test "the color when a ray misses" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 1, 0));
    const c = colorAt(w, r);

    try expectEqual(c, cnv.color(0, 0, 0));
}

test "the color when a ray hits" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));
    const c = colorAt(w, r);

    try expect(cnv.equal(c, cnv.color(0.38066, 0.47583, 0.2855)));
}

test "the color with an intersection behind the ray" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    var outer = &w.spheres.items[0];
    outer.common_attrs.material.ambient = 1;

    var inner = &w.spheres.items[1];
    inner.common_attrs.material.ambient = 1;

    const r = ray.ray(tup.point(0, 0, 0.75), tup.vector(0, 0, -1));
    const c = colorAt(w, r);

    try expectEqual(c, inner.common_attrs.material.color);
}

test "there is no shadow when nothing is collinear with point and light" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const p = tup.point(0, 10, 0);
    try expect(!isShadowed(w, p));
}

test "the shadow when an object is between the point and the light" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const p = tup.point(10, -10, 10);
    try expect(isShadowed(w, p));
}

test "there is no shadow when an object is behind the light" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const p = tup.point(-20, 20, -20);
    try expect(!isShadowed(w, p));
}

test "there is no shadow when an object is behind the point" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const p = tup.point(-2, 2, -2);
    try expect(!isShadowed(w, p));
}

test "shadeHit() is given an intersection in shadow" {
    var w = world(std.testing.allocator);
    w.light = lht.PointLight{
        .position = tup.point(0, 0, -10),
        .intensity = cnv.Color{1, 1, 1},
    };
    defer w.deinit();

    const s1 = sph.Sphere{};
    try w.spheres.append(s1);

    const s2 = sph.Sphere{
        .common_attrs = .{
            .transform = mat.translation(0, 0, 10),
        },
    };
    try w.spheres.append(s2);

    const r = ray.ray(tup.point(0, 0, 5), tup.vector(0, 0, 1));
    const i = int.Intersection{ .t = 4, .shape_attrs = s2.common_attrs };

    const comps = int.prepareComputations(i, r);
    const c = shadeHit(w, comps);
    try expectEqual(c, cnv.color(0.1, 0.1, 0.1));
}

test "the reflected color for a nonreflective material" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const r = ray.Ray{
        .origin = tup.point(0, 0, 0),
        .direction = tup.vector(0, 0, 1),
    };

    var sphere = &w.spheres.items[1];
    sphere.common_attrs.material.ambient = 1;

    const i = int.Intersection{ .t = 1, .shape_attrs = sphere.common_attrs };
    const comps = int.prepareComputations(i, r);

    const color = reflectedColor(w, comps);
    try expectEqual(color, cnv.Color{0, 0, 0});
}

test "the reflected color for a reflective material" {
    const a = @sqrt(2.0);
    const b = a / 2.0;

    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const plane = pln.Plane{
        .common_attrs = .{
            .material = .{ .reflective = 0.5 },
            .transform = mat.translation(0, -1, 0),
        }
    };
    try w.planes.append(plane);

    const r = ray.Ray{
        .origin = tup.point(0, 0, -3),
        .direction = tup.vector(0, -b, b),
    };
    const i = int.Intersection{
        .t = a,
        .shape_attrs = plane.common_attrs,
        .normal = pln.normalAt(plane, ray.position(r, a)),
    };

    const comps = int.prepareComputations(i, r);
    const color = reflectedColor(w, comps);
    try expect(cnv.equal(color, cnv.Color{0.19032, 0.2379, 0.14274}));
}

test "shadeHit() with a reflective material" {
    const a = @sqrt(2.0);
    const b = a / 2.0;

    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const plane = pln.Plane{
        .common_attrs = .{
            .material = .{ .reflective = 0.5 },
            .transform = mat.translation(0, -1, 0),
        }
    };
    try w.planes.append(plane);

    const r = ray.Ray{
        .origin = tup.point(0, 0, -3),
        .direction = tup.vector(0, -b, b),
    };
    const i = int.Intersection{
        .t = a,
        .shape_attrs = plane.common_attrs,
        .normal = pln.normalAt(plane, ray.position(r, a)),
    };

    const comps = int.prepareComputations(i, r);
    const color = shadeHit(w, comps);
    try expect(cnv.equal(color, cnv.Color{0.87677, 0.92436, 0.82918}));
}

test "colorAt() with mutually reflective surfaces" {
    var w = world(std.testing.allocator);
    defer w.deinit();

    w.light = lht.PointLight{
        .position = tup.point(0, 0, 0),
        .intensity = cnv.Color{1, 1, 1},
    };

    const lower = pln.Plane{
        .common_attrs = .{
            .material = .{ .reflective = 1 },
            .transform = mat.translation(0, -1, 0),
        },
    };
    try w.planes.append(lower);

    const upper = pln.Plane{
        .common_attrs = .{
            .material = .{ .reflective = 1 },
            .transform = mat.translation(0, 1, 0),
        },
    };
    try w.planes.append(upper);

    const r = ray.Ray{
        .origin = tup.point(0, 0, 0),
        .direction = tup.vector(0, 1, 0),
    };

    // As long as this terminates, consider the test passed.
    _ = colorAt(w, r);
}

test "the reflected color at the maximum recursive depth" {
    const a = @sqrt(2.0);
    const b = a / 2.0;

    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const plane = pln.Plane{
        .common_attrs = .{
            .material = .{ .reflective = 0.5 },
            .transform = mat.translation(0, -1, 0),
        },
    };
    try w.planes.append(plane);

    const r = ray.Ray{
        .origin = tup.point(0, 0, -3),
        .direction = tup.vector(0, -b, b),
    };
    const i = int.Intersection{
        .t = a,
        .shape_attrs = plane.common_attrs,
    };

    const comps = int.prepareComputations(i, r);
    const color = reflectedColorInternal(w, comps, 0);
    try expect(cnv.equal(color, cnv.Color{0, 0, 0}));
}

test "the refracted color with an opaque surface" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const sphere = &w.spheres.items[0];
    const r = ray.Ray{
        .origin = tup.point(0, 0, -5),
        .direction = tup.vector(0, 0, 1),
    };
    const xs = &[_]int.Intersection{
        .{ .t = 4, .shape_attrs = sphere.common_attrs },
        .{ .t = 6, .shape_attrs = sphere.common_attrs },
    };
    const comps = int.prepareComputationsForRefraction(xs[0], r, xs);

    const c = refractedColor(w, comps);
    try expectEqual(c, cnv.Color{0, 0, 0});
}

test "the refactor color at the maximum recursive depth" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const sphere = &w.spheres.items[0];
    sphere.common_attrs.material.transparency = 1.0;
    sphere.common_attrs.material.refractive_index = 1.5;
    const r = ray.Ray{
        .origin = tup.point(0, 0, -5),
        .direction = tup.vector(0, 0, 1),
    };
    const xs = &[_]int.Intersection{
        .{ .t = 4, .shape_attrs = sphere.common_attrs },
        .{ .t = 6, .shape_attrs = sphere.common_attrs },
    };
    const comps = int.prepareComputationsForRefraction(xs[0], r, xs);

    const c = refractedColorInternal(w, comps, 0);
    try expectEqual(c, cnv.Color{0, 0, 0});
}

test "the refracted color under total internal reflection" {
    const a = @sqrt(2.0);
    const b = a / 2.0;

    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const sphere = &w.spheres.items[0];
    sphere.common_attrs.material.transparency = 1.0;
    sphere.common_attrs.material.refractive_index = 1.5;
    const r = ray.Ray{
        .origin = tup.point(0, 0, b),
        .direction = tup.vector(0, 1, 0),
    };
    const xs = &[_]int.Intersection{
        .{ .t = -b, .shape_attrs = sphere.common_attrs },
        .{ .t = b, .shape_attrs = sphere.common_attrs },
    };
    const comps = int.prepareComputationsForRefraction(xs[1], r, xs);

    const c = refractedColor(w, comps);
    try expectEqual(c, cnv.Color{0, 0, 0});
}

test "the refracted color with a refracted ray" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const a = &w.spheres.items[0];
    a.common_attrs.material.ambient = 1.0;
    a.common_attrs.material.pattern = .{
        .a = cnv.Color{1, 1, 1},
        .b = cnv.Color{0, 0, 0},
        .color_map = pat.testPattern,
    };

    const b = &w.spheres.items[1];
    b.common_attrs.material.transparency = 1.0;
    b.common_attrs.material.refractive_index = 1.5;

    const r = ray.Ray{
        .origin = tup.point(0, 0, 0.1),
        .direction = tup.vector(0, 1, 0),
    };
    const xs = &[_]int.Intersection{
        .{
            .t = -0.9899,
            .shape_attrs = a.common_attrs,
            .normal = sph.normalAt(a.*, ray.position(r, -0.9899)),
        },
        .{
            .t = -0.4899,
            .shape_attrs = b.common_attrs,
            .normal = sph.normalAt(b.*, ray.position(r, -0.4899)),
        },
        .{
            .t =  0.4899,
            .shape_attrs = b.common_attrs,
            .normal = sph.normalAt(b.*, ray.position(r, 0.4899)),
        },
        .{
            .t =  0.9899,
            .shape_attrs = a.common_attrs,
            .normal = sph.normalAt(a.*, ray.position(r, 0.9899)),
        },
    };
    const comps = int.prepareComputationsForRefraction(xs[2], r, xs);

    const c = refractedColor(w, comps);
    try expect(cnv.equal(c, cnv.Color{0, 0.99888, 0.04725}));
}

test "shadeHit() with a transparent material" {
    const a = @sqrt(2.0);
    const b = a / 2.0;

    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const floor = pln.Plane{
        .common_attrs = .{
            .material = .{
                .transparency = 0.5,
                .refractive_index = 1.5,
            },
            .transform = mat.translation(0, -1, 0),
        },
    };
    const ball = sph.Sphere{
        .common_attrs = .{
            .material = .{
                .color = cnv.Color{1, 0, 0},
                .ambient = 0.5
            },
            .transform = mat.translation(0, -3.5, -0.5),
        },
    };
    const r = ray.Ray{
        .origin = tup.point(0, 0, -3),
        .direction = tup.vector(0, -b, b),
    };
    const xs = &[_]int.Intersection{
        .{
            .t = a,
            .shape_attrs = floor.common_attrs,
            .normal = pln.normalAt(floor, ray.position(r, a)),
        }
    };
    const comps = int.prepareComputationsForRefraction(xs[0], r, xs);

    try w.planes.append(floor);
    try w.spheres.append(ball);

    const color = shadeHit(w, comps);
    try expect(cnv.equal(color, cnv.Color{0.93642, 0.68642, 0.68642}));
}

test "shadeHit() with a reflective, transparent material" {
    const a = @sqrt(2.0);
    const b = a / 2.0;

    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const r = ray.Ray{
        .origin = tup.point(0, 0, -3),
        .direction = tup.vector(0, -b, b),
    };
    const floor = pln.Plane{
        .common_attrs = .{
            .transform = mat.translation(0, -1, 0),
            .material = .{
                .reflective = 0.5,
                .transparency = 0.5,
                .refractive_index = 1.5,
            },
        },
    };
    const ball = sph.Sphere{
        .common_attrs = .{
            .transform = mat.translation(0, -3.5, -0.5),
            .material = .{
                .color = cnv.Color{1, 0, 0},
                .ambient = 0.5,
            },
        },
    };

    try w.planes.append(floor);
    try w.spheres.append(ball);

    const xs = &[_]int.Intersection{
        .{
            .t = a,
            .shape_attrs = floor.common_attrs,
            .normal = pln.normalAt(floor, ray.position(r, a)),
        }
    };
    const comps = int.prepareComputationsForRefraction(xs[0], r, xs);

    const color = shadeHit(w, comps);
    try expect(cnv.equal(color, cnv.Color{0.93391, 0.69643, 0.69243}));
}
