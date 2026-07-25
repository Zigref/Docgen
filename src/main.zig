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

pub fn returns_the_comment_before_the_identifier_nullable(ast: std.zig.Ast, decl: std.zig.Ast.Node.Index) ?[]const u8 {
    // firstToken returns the index of the declared token *Inside* the AST.
    const first_token_of_the_identifier_declared = ast.firstToken(decl);
    // ok, now that I got the first
    // token, I will start going backwards.
    // While moving backwards, I will check
    // if the token type is still a comment?
    // The moment the next character is
    // not a comment we stop.
    var current_token = first_token_of_the_identifier_declared;

    while (current_token > 0) { // to make sure I don't go to 0 index. (*o*)

        // because if I go to 0, (O-O)
        const previous = current_token - 1; // <- this thing becomes -1. (X_X)

        switch (ast.tokenTag(previous)) {
            .doc_comment, .container_doc_comment => {
                current_token = current_token - 1;
            },
            else => {
                break;
            },
        }
    }

    if (current_token == first_token_of_the_identifier_declared) {
        // means, there was no comment to loop over.
        // hence, our loop exited in the very first iteration.
        // hence, both the variables are same still.
        return null;
        // stating that we didn't find a comment.
    }

    const the_token_from_which_the_comment_starts = current_token;
    // the comment length does from:
    // the_token_from_which_the_comment_starts
    // till the
    // first_token_of_the_identifier_declared - 1

    // the tokenStart returns the starting character index of the token you are at.
    const index_where_identifier_declared = ast.tokenStart(first_token_of_the_identifier_declared);
    const index_where_comment_declared = ast.tokenStart(the_token_from_which_the_comment_starts);
    return ast.source[index_where_comment_declared..index_where_identifier_declared];
}

const identifier = struct {
    name: []const u8,
    comment: ?[]const u8,
    signature: []const u8,
    file_name: []const u8,
};

pub fn parse(source: [:0]const u8, file_name: []const u8, gpa: std.mem.Allocator) !std.ArrayList(identifier) {
    var ast = try std.zig.Ast.parse(
        gpa,
        source,
        .zig,
    );

    const tags = ast.nodes.items(.tag);
    const data = ast.nodes.items(.data);

    var result_to_return: std.ArrayList(identifier) = .empty;

    for (ast.rootDecls()) |decl| {
        var the_current_identifier: identifier = undefined;
        const index = @intFromEnum(decl);

        const comment = returns_the_comment_before_the_identifier_nullable(ast, decl);

        switch (tags[index]) {
            .fn_decl => {
                const proto = data[index].node_and_node[0];
                const token = ast.nodeMainToken(proto);
                const name = ast.tokenSlice(token + 1);
                const signature = ast.getNodeSource(proto);

                the_current_identifier = .{
                    .comment = comment,
                    .file_name = file_name,
                    .name = name,
                    .signature = signature,
                };
            },
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => {
                const token = ast.nodeMainToken(decl);
                const name = ast.tokenSlice(token + 1);
                const signature = ast.getNodeSource(decl);

                the_current_identifier = .{
                    .comment = comment,
                    .file_name = file_name,
                    .name = name,
                    .signature = signature,
                };
            },
            .test_decl => {
                const name = ast.getNodeSource(decl);

                the_current_identifier = .{
                    .comment = comment,
                    .file_name = file_name,
                    .name = name,
                    .signature = name,
                };
            },
            else => {},
        }
        try result_to_return.append(
            gpa,
            the_current_identifier,
        );
    }

    return result_to_return;
}

pub fn main(init: std.process.Init) !void {
    var iterator = try init.minimal.args.iterateAllocator(init.gpa);

    const io = init.io;

    _ = iterator.next().?;

    var entire_documentation: std.ArrayList(identifier) = .empty;

    if (iterator.next()) |input_folder| {
        var dir = try std.Io.Dir.cwd().openDir(io, input_folder, .{ .iterate = true, .access_sub_paths = true });
        defer dir.close(io);

        var iter = try dir.walk(init.gpa);

        while (try iter.next(io)) |entry| {
            if (entry.kind != .file) {
                continue;
            }
            if (!std.mem.endsWith(u8, entry.path, ".zig")) {
                continue;
            }

            const file_content = try dir.readFileAlloc(io, entry.path, init.gpa, std.Io.Limit.unlimited);
            defer init.gpa.free(file_content);

            const content = try init.gpa.dupeZ(u8, file_content);

            const res = try parse(content, entry.path, init.gpa);
            try entire_documentation.appendSlice(init.gpa, res.items);
        }
    } else {
        std.debug.print("Usage:\n\nzigref path/to/input/dir", .{});
    }

    for (entire_documentation.items, 0..) |r, i| {
        std.debug.print("-----COMPONENT NUMBER {}-----\n", .{i});
        std.debug.print("name={s}\ncomment={?s}\nsignature={s}\nfile={s}\n", .{
            r.name,
            r.comment,
            r.signature,
            r.file_name,
        });
    }
}

test "normal_test" {
    const res = try parse(test_code, "main.zig");
    for (res.items, 0..) |r, i| {
        std.debug.print("-----COMPONENT NUMBER {}-----\n", .{i});
        std.debug.print("name={s}\ncomment={?s}\nsignature={s}\nfile={s}\n", .{
            r.name,
            r.comment,
            r.signature,
            r.file_name,
        });
    }
}
