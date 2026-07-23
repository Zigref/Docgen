//!    _____ _         ____         __
//!   |__  /(_)  __ _ |  _ \  ___  / _|
//!     / / | | / _` || |_) |/ _ \| |_
//!    / /_ | || (_| ||  _ <|  __/|  _|
//!   /____||_| \__, ||_| \_\\___||_|
//!             |___/
//!
//! This application consists of following steps:
//! - use this like zigref /path/to/input/folder
//! - Read all the zig files in the entire directories.
//! - Parse each one of them.
//! - Extract all the doc comments, functions, structs,
//!   and anything that is in the root directory.
//! - Render it as html to stdout.
//! - There are __INSERT_ labels in the html file,
//!   on which I will replace it with the documentation.

const std = @import("std");

const test_code: [:0]const u8 = @embedFile("main.zig");

pub fn parse(source: [:0]const u8) !void {
    var ast = try std.zig.Ast.parse(
        std.heap.page_allocator,
        source,
        .zig,
    );

    defer ast.deinit(std.heap.page_allocator);
    const tags = ast.nodes.items(.tag);
    const data = ast.nodes.items(.data);

    for (ast.rootDecls()) |decl| {
        const index = @intFromEnum(decl);

        switch (tags[index]) {
            .fn_decl => {
                const proto = data[index].node_and_node[0];
                const token = ast.nodeMainToken(proto);
                const name = ast.tokenSlice(token + 1);
                const signature = ast.getNodeSource(proto);

                std.debug.print("name of the function: {s} \n\nand source code of only the declaration of the function: {s}\n\n", .{ name, signature });
            },
            else => {},
        }
    }
}

pub fn main(_: std.process.Init) !void {
    try parse(test_code);
}
