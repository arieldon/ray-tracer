const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const int = @import("intersection.zig");
const lht = @import("light.zig");
const mat = @import("matrix.zig");
const mtl = @import("material.zig");
const pln = @import("plane.zig");
const ray = @import("ray.zig");
const sph = @import("sphere.zig");
const tup = @import("tuple.zig");

pub const World = struct {
    // FIXME Require a light for the scene. A scene without light isn't
    // particularly useful, and marking the light as optional forces
    // inefficient null checks later.
    light: ?lht.PointLight,
    spheres: std.ArrayList(sph.Sphere),
    planes: std.ArrayList(pln.Plane),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) World {
        return .{
            .light = null,
            .spheres = std.ArrayList(sph.Sphere).init(allocator),
            .planes = std.ArrayList(pln.Plane).init(allocator),
            .allocator = allocator,
        };
    }

    // The tests below rely on this function.
    fn defaultInit(allocator: std.mem.Allocator) !World {
        var w = World.init(allocator);

        // Add default light source.
        w.light = lht.pointLight(tup.point(-10, 10, -10), cnv.color(1, 1, 1));

        var s1 = sph.sphere();
        s1.shape.material.color = cnv.color(0.8, 1.0, 0.6);
        s1.shape.material.diffuse = 0.7;
        s1.shape.material.specular = 0.2;

        var s2 = sph.sphere();
        s2.shape.transform = mat.scaling(0.5, 0.5, 0.5);

        // Add default spheres to the world.
        try w.spheres.appendSlice(&[_]sph.Sphere{ s1, s2 });

        return w;
    }

    pub fn deinit(self: World) void {
        self.spheres.deinit();
        self.planes.deinit();
    }

    pub fn containsSphere(self: World, s: sph.Sphere) bool {
        for (self.spheres.items) |t| if (sph.equal(s, t)) return true;
        return false;
    }

    pub fn containsPlane(self: World, p: pln.Plane) bool {
        for (self.planes.items) |q| if (std.meta.equal(p, q)) return true;
        return false;
    }
};

pub inline fn world(allocator: std.mem.Allocator) World {
    return World.init(allocator);
}

pub inline fn defaultWorld(allocator: std.mem.Allocator) !World {
    return World.defaultInit(allocator);
}

pub fn intersectWorld(xs: *std.ArrayList(int.Intersection), w: World, r: ray.Ray) !void {
    // Cast a ray through each object in the world and append any intersections
    // to the list.
    for (w.spheres.items) |sphere| try sph.intersect(xs, sphere, r);
    for (w.planes.items)  |plane|  try pln.intersect(xs, plane, r);

    // Call hit() only to sort the intersections.
    _ = int.hit(xs);
}

pub fn shadeHit(w: World, comps: int.Computation) !cnv.Color {
    const shadowed = try isShadowed(w, comps.over_point);
    return mtl.lighting(
        comps.shape,
        w.light.?,
        comps.over_point,
        comps.eye,
        comps.normal,
        shadowed);
}

pub fn colorAt(w: World, r: ray.Ray) !cnv.Color {
    var intersections = std.ArrayList(int.Intersection).init(w.allocator);
    defer intersections.deinit();

    try intersectWorld(&intersections, w, r);
    if (int.hit(&intersections)) |hit| {
        const comps = int.prepareComputations(hit, r);
        return shadeHit(w, comps);
    }
    return cnv.color(0, 0, 0);
}

pub fn isShadowed(w: World, p: tup.Point) !bool {
    // Mesasure distance from point to light source and calculate magnitude of
    // resulting vector.
    const v = w.light.?.position - p;
    const distance = tup.magnitude(v);

    // Create shadow ray to cast. If between the point and the light source,
    // this ray intersects an object, then a shadow engulfs that object.
    const direction = tup.normalize(v);
    const shadow_ray = ray.ray(p, direction);

    var intersections = std.ArrayList(int.Intersection).init(w.allocator);
    defer intersections.deinit();

    try intersectWorld(&intersections, w, shadow_ray);

    // Again, if the shadow ray intersects an object at some point in the
    // distance between the light source and the point, then the object lies
    // within a shadow.
    if (int.hit(&intersections)) |hit| return hit.t < distance;
    return false;
}

test "creating a world" {
    const w = world(std.testing.allocator);
    defer w.deinit();

    try expectEqual(w.spheres.items.len, 0);
    try expectEqual(w.light, null);
}

test "the default world" {
    const light = lht.pointLight(tup.point(-10, 10, -10), cnv.color(1, 1, 1));

    var s1 = sph.sphere();
    s1.id = 0;
    s1.shape.material.color = cnv.color(0.8, 1.0, 0.6);
    s1.shape.material.diffuse = 0.7;
    s1.shape.material.specular = 0.2;

    var s2 = sph.sphere();
    s2.id = 1;
    s2.shape.transform = mat.scaling(0.5, 0.5, 0.5);

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

    try intersectWorld(&xs, w, r);
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
    const i = int.intersection(4, s.shape);

    const comps = int.prepareComputations(i, r);
    const c = try shadeHit(w, comps);

    try expect(cnv.equal(c, cnv.color(0.38066, 0.47583, 0.2855)));
}

test "shading an intersection from the inside" {
    var w = try defaultWorld(std.testing.allocator);
    w.light = lht.pointLight(tup.point(0, 0.25, 0), cnv.color(1, 1, 1));
    defer w.deinit();

    const r = ray.ray(tup.point(0, 0, 0), tup.vector(0, 0, 1));
    const s = w.spheres.items[1];
    const i = int.intersection(0.5, s.shape);

    const comps = int.prepareComputations(i, r);
    const c = try shadeHit(w, comps);

    try expect(cnv.equal(c, cnv.color(0.90498, 0.90498, 0.90498)));
}

test "the color when a ray misses" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 1, 0));
    const c = try colorAt(w, r);

    try expectEqual(c, cnv.color(0, 0, 0));
}

test "the color when a ray hits" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));
    const c = try colorAt(w, r);

    try expect(cnv.equal(c, cnv.color(0.38066, 0.47583, 0.2855)));
}

test "the color with an intersection behind the ray" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    var outer = &w.spheres.items[0];
    outer.shape.material.ambient = 1;

    var inner = &w.spheres.items[1];
    inner.shape.material.ambient = 1;

    const r = ray.ray(tup.point(0, 0, 0.75), tup.vector(0, 0, -1));
    const c = try colorAt(w, r);

    try expectEqual(c, inner.shape.material.color);
}

test "there is no shadow when nothing is collinear with point and light" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const p = tup.point(0, 10, 0);
    try expect(!try isShadowed(w, p));
}

test "the shadow when an object is between the point and the light" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const p = tup.point(10, -10, 10);
    try expect(try isShadowed(w, p));
}

test "there is no shadow when an object is behind the light" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const p = tup.point(-20, 20, -20);
    try expect(!try isShadowed(w, p));
}

test "there is no shadow when an object is behind the point" {
    var w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    const p = tup.point(-2, 2, -2);
    try expect(!try isShadowed(w, p));
}

test "shadeHit() is given an intersection in shadow" {
    var w = world(std.testing.allocator);
    w.light = lht.pointLight(tup.point(0, 0, -10), cnv.color(1, 1, 1));
    defer w.deinit();

    var s1 = sph.sphere();
    try w.spheres.append(s1);

    var s2 = sph.sphere();
    s2.shape.transform = mat.translation(0, 0, 10);
    try w.spheres.append(s2);

    const r = ray.ray(tup.point(0, 0, 5), tup.vector(0, 0, 1));
    const i = int.intersection(4, s2.shape);

    const comps = int.prepareComputations(i, r);
    const c = try shadeHit(w, comps);
    try expectEqual(c, cnv.color(0.1, 0.1, 0.1));
}
