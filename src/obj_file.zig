const std = @import("std");
const expectEqual = std.testing.expectEqual;
const tup = @import("tuple.zig");

const Vertex = tup.Point;

const ParserCommand = enum {
    /// Define a new vertex.
    vertex,
};

const ParserError = enum {
    InvalidParametersToCommand,
};

const Parser = struct {
    vertices: std.ArrayList(Vertex),
    number_of_ignored_lines: usize = 0,

    pub fn deinit(self: *Parser) void {
        self.vertices.deinit();
    }
};

pub fn parseObjFile(allocator: std.mem.Allocator, file: std.fs.File) !Parser {
    var parser = Parser{
        .vertices = std.ArrayList(Vertex).init(allocator),
    };
    errdefer parser.deinit();

    // In OBJ file format, index count begins from 1 instead of 0. Fill the
    // zeroth slot of the list of vertices with a sentinel -- it shouldn't be
    // referenced at any point.
    try parser.vertices.append(undefined);

    var contents = try file.reader().readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(contents);

    var line_start: usize = 0;
    iterate_contents: for (contents) |contents_character, contents_index| {
        if (contents_character == '\n') {
            const line_end = contents_index + 1;
            const line = contents[line_start..line_end];

            var literal_start = 0;
            var literal_end: usize =
                for (line) |literal_character, line_index| {
                    if (literal_character == ' ') break line_index;
                } else 0;
            var literal = line[literal_start..literal_end];

            var command: ParserCommand = undefined;
            if (std.mem.eql(u8, literal, "v")) {
                command = .vertex;
            } else {
                // Ignore invalid or unsupported commands silently.
                parser.number_of_ignored_lines += 1;
                continue :iterate_contents;
            }

            literal_start = literal_end;
            switch (command) {
                .vertex => {},
            }

            line_start = contents_index + 1;
        }
    }

    // NOTE Caller owns returned memory.
    return parser;
}

test "ignoring unrecognized lines" {
    // This file contains nonsense.
    const file = try std.fs.cwd().openFile("foo.txt", .{});
    defer file.close();

    var parser = try parseObjFile(std.testing.allocator, file);
    defer parser.deinit();

    try expectEqual(parser.number_of_ignored_lines, 5);
}

test "vertex records" {
    const file = try std.fs.cwd().openFile("vertex_records.txt", .{});
    defer file.close();

    var parser = try parseObjFile(std.testing.allocator, file);
    defer parser.deinit();

    try expectEqual(parser.vertices.items[0], undefined);
    try expectEqual(parser.vertices.items[1], tup.point(-1, 1, 0));
    try expectEqual(parser.vertices.items[2], tup.point(-1, 0.5, 0));
    try expectEqual(parser.vertices.items[3], tup.point(1, 0, 0));
    try expectEqual(parser.vertices.items[4], tup.point(1, 1, 0));
}
