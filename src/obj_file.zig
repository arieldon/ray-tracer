const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const grp = @import("group.zig");
const mat = @import("matrix.zig");
const tri = @import("triangle.zig");
const tup = @import("tuple.zig");
const wrd = @import("world.zig");

const Vertex = tup.Point;
const Face = tri.Triangle;
const Group = std.ArrayList(Face);

const ParserCommand = enum {
    /// Define a new vertex.
    vertex,

    /// Define a new face, where a face consists of three points that form a
    /// triangle or four or more points that form a polygon. The parser then
    /// converts the latter into triangles.
    face,

    /// Specify a group name for the next face.
    group,
};

const ParserError = error {
    InvalidCommand,
};

const ObjFile = struct {
    allocator: std.mem.Allocator,

    /// Store all vertices declared in OBJ file.
    vertices: std.ArrayList(Vertex),

    /// Store any faces declared outside of a named group. In other words, this
    /// list serves as the default group for faces.
    faces: std.ArrayList(Face),

    /// Store faces declared under a named group in a separate list for this
    /// group.
    groups: std.StringHashMap(Group),

    /// Convert the parsed result of an OBJ file to a group of shapes that the
    /// ray tracer can render.
    pub fn toShapeGroup(self: *ObjFile, world_allocator: std.mem.Allocator) !grp.Group {
        var obj_group = grp.Group.init(world_allocator, mat.identity);

        // Append faces without an explicitly defined group to the general list
        // of triangles of struct `World`.
        try obj_group.triangles.appendSlice(self.faces.items);

        // Append faces of each named group from OBJ file to a unique group in
        // the world.
        var iter = self.groups.valueIterator();
        while (iter.next()) |faces| {
            var subgroup = grp.Group.init(world_allocator, mat.identity);
            try subgroup.triangles.appendSlice(faces.items);
            try obj_group.subgroups.append(subgroup);
        }

        return obj_group;
    }

    pub fn deinit(self: *ObjFile) void {
        self.vertices.deinit();
        self.faces.deinit();

        var group_iter = self.groups.iterator();
        while (group_iter.next()) |named_group| {
            self.allocator.free(named_group.key_ptr.*);
            named_group.value_ptr.deinit();
        }
        self.groups.deinit();
    }
};

pub fn parseObjFile(allocator: std.mem.Allocator, file: std.fs.File) !ObjFile {
    var obj = ObjFile{
        .allocator = allocator,
        .vertices = std.ArrayList(Vertex).init(allocator),
        .faces = std.ArrayList(Face).init(allocator),
        .groups = std.StringHashMap(Group).init(allocator),
    };
    errdefer obj.deinit();

    // In OBJ file format, index count begins from 1 instead of 0. Fill the
    // zeroth slot of the list of vertices with a sentinel -- it shouldn't be
    // referenced at any point.
    try obj.vertices.append(undefined);

    var contents = try file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(contents);

    var group_name: ?[]const u8 = null;
    var lines = std.mem.tokenize(u8, contents, "\n");
    while (lines.next()) |line| {
        var literals = std.mem.tokenize(u8, line, " ");
        while (literals.next()) |literal| {
            // This parser only supports commands v, f, and g -- all of which
            // are of length 1.
            if (literal.len > 1) return ParserError.InvalidCommand;

            switch (literal[0]) {
                'v' => {
                    const x = try std.fmt.parseFloat(f64, try getLiteral(&literals));
                    const y = try std.fmt.parseFloat(f64, try getLiteral(&literals));
                    const z = try std.fmt.parseFloat(f64, try getLiteral(&literals));
                    try obj.vertices.append(tup.point(x, y, z));
                },
                'f' => {
                    var indices = std.ArrayList(usize).init(obj.allocator);
                    defer indices.deinit();

                    while (literals.next()) |vertex_index|
                        try indices.append(try std.fmt.parseInt(usize, vertex_index, 10));

                    // By default, append the new face to the standard list.
                    // However, append the face to a named list given a group
                    // name specified with the `g` command.
                    var faces: *std.ArrayList(Face) = &obj.faces;
                    if (group_name) |group| {
                        const entry = try obj.groups.getOrPut(try allocator.dupe(u8, group));
                        if (!entry.found_existing) entry.value_ptr.* = Group.init(allocator);
                        faces = entry.value_ptr;
                    }

                    if (indices.items.len > 3) {
                        try triangulatePolygon(faces, obj.vertices.items, indices.items);
                    } else {
                        try faces.append(Face.init(
                            obj.vertices.items[indices.items[0]],
                            obj.vertices.items[indices.items[1]],
                            obj.vertices.items[indices.items[2]]));
                    }
                },
                'g' => group_name = try getLiteral(&literals),
                else => return ParserError.InvalidCommand,
            }

            // Report an unused literal in a command as an error.
            if (literals.next() != null) return ParserError.InvalidCommand;
        }
    }

    // NOTE Caller owns returned memory.
    return obj;
}

fn getLiteral(literals: *std.mem.TokenIterator(u8)) ![]const u8 {
    return literals.next() orelse return ParserError.InvalidCommand;
}

/// Convert some convex polygon to a set of triangles, where a convex polygon
/// is a polygon whose interior angles are all less than or equal to 180
/// degrees.
fn triangulatePolygon(faces: *std.ArrayList(Face), vertices: []Vertex, vertex_indices: []usize) !void {
    std.debug.assert(vertex_indices.len > 3);
    for (vertex_indices[1..vertex_indices.len]) |_, index| {
        try faces.append(Face.init(
            vertices[vertex_indices[0]],
            vertices[vertex_indices[index]],
            vertices[vertex_indices[index + 1]]));
    }
}
