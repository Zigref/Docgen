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

    for (ast.rootDecls()) |decl| {
        const main_token = ast.nodeMainToken(decl);
        const name = ast.tokenSlice(main_token + 1);
        std.debug.print("{s}\n", .{name});
    }
}

pub fn main(_: std.process.Init) !void {
    try parse(test_code);
}
