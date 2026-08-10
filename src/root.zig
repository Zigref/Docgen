const std = @import("std");
const lib = @import("alt.zig");

const allocator = std.heap.c_allocator;

export fn parse_zig_source(_source: [*:0]const u8) [*:0]const u8 {
    const source = std.mem.span(_source);

    const res = lib.__main(source) catch {
        const allocated_string = allocator.dupeZ(u8, "Error while parsing.") catch @panic("No more RAM available");
        return allocated_string;
    };

    const allocated_string = allocator.dupeZ(u8, res) catch @panic("No more RAM available.");
    allocator.free(res);
    return allocated_string.ptr;
}

export fn free_zig_string(allocated_string: [*:0]const u8) void {
    allocator.free(std.mem.span(allocated_string));
}
