const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const int = @import("intersection.zig");
const lht = @import("light.zig");
const mat = @import("matrix.zig");
const mtl = @import("material.zig");
const ray = @import("ray.zig");
const sph = @import("sphere.zig");
const tup = @import("tuple.zig");

pub const World = struct {
    light: ?lht.PointLight,
    objects: std.ArrayList(sph.Sphere),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) World {
        return .{
            .light = null,
            .objects = std.ArrayList(sph.Sphere).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn defaultInit(allocator: std.mem.Allocator) !World {
        var w = World.init(allocator);

        // Add default light source.
        w.light = lht.pointLight(tup.point(-10, 10, -10), cnv.color(1, 1, 1));

        var s1 = sph.sphere();
        s1.material.color = cnv.color(0.8, 1.0, 0.6);
        s1.material.diffuse = 0.7;
        s1.material.specular = 0.2;

        var s2 = sph.sphere();
        s2.transform = mat.scaling(0.5, 0.5, 0.5);

        // Add default objects to the world.
        try w.objects.appendSlice(&[_]sph.Sphere{ s1, s2 });

        return w;
    }

    pub fn deinit(self: World) void {
        self.objects.deinit();
    }

    pub fn contains(self: World, object: sph.Sphere) bool {
        for (self.objects.items) |world_object| if (sph.equal(object, world_object)) return true;
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
    for (w.objects.items) |object| try sph.intersect(xs, object, r);

    // Call hit() only to sort the intersections.
    _ = int.hit(xs);
}

pub fn shadeHit(w: World, comps: int.Computation) cnv.Color {
    return mtl.lighting(comps.object.material, w.light.?, comps.point, comps.eye, comps.normal);
}

pub fn colorAt(w: World, r: ray.Ray) !cnv.Color {
    var intersections = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer intersections.deinit();

    try intersectWorld(&intersections, w, r);
    if (int.hit(&intersections)) |hit| {
        const comps = int.prepareComputations(hit, r);
        return shadeHit(w, comps);
    }
    return cnv.color(0, 0, 0);
}

test "creating a world" {
    const w = world(std.testing.allocator);
    defer w.deinit();

    try expectEqual(w.objects.items.len, 0);
    try expectEqual(w.light, null);
}

test "the default world" {
    const light = lht.pointLight(tup.point(-10, 10, -10), cnv.color(1, 1, 1));

    var s1 = sph.sphere();
    s1.id = 0;
    s1.material.color = cnv.color(0.8, 1.0, 0.6);
    s1.material.diffuse = 0.7;
    s1.material.specular = 0.2;

    var s2 = sph.sphere();
    s2.id = 1;
    s2.transform = mat.scaling(0.5, 0.5, 0.5);

    const w = try defaultWorld(std.testing.allocator);
    defer w.deinit();

    try expectEqual(w.light, light);
    try expect(w.contains(s1));
    try expect(w.contains(s2));
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
    const shape = w.objects.items[0];
    const i = int.intersection(4, shape);

    const comps = int.prepareComputations(i, r);
    const c = shadeHit(w, comps);

    try expect(cnv.equal(c, cnv.color(0.38066, 0.47583, 0.2855)));
}

test "shading an intersection from the inside" {
    var w = try defaultWorld(std.testing.allocator);
    w.light = lht.pointLight(tup.point(0, 0.25, 0), cnv.color(1, 1, 1));
    defer w.deinit();

    const r = ray.ray(tup.point(0, 0, 0), tup.vector(0, 0, 1));
    const shape = w.objects.items[1];
    const i = int.intersection(0.5, shape);

    const comps = int.prepareComputations(i, r);
    const c = shadeHit(w, comps);

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

    var outer = &w.objects.items[0];
    outer.material.ambient = 1;

    var inner = &w.objects.items[1];
    inner.material.ambient = 1;

    const r = ray.ray(tup.point(0, 0, 0.75), tup.vector(0, 0, -1));
    const c = try colorAt(w, r);

    try expectEqual(c, inner.material.color);
}
