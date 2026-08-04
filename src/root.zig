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
//! - Render it as json to stdout.
//! - The json would be used to render the json
//!   as a proper documentation.

const std = @import("std");

pub const AVAILABLE_TYPES = enum(u32) {
    STRUCT,
    ENUM,
    FUNCTION,
    const testerer = opaque {
        pub fn tester_inside_opaque() void {}
    };
    pub fn tester() void {}
};

pub const identifier = struct {
    name: []const u8,
    comment: ?[]const u8,
    type: []const u8,
    signature: ?[]const u8,
    line_number: u32,
    pub fn tester() void {}
};

fn returns_the_comment_before_the_identifier_nullable(ast: std.zig.Ast, decl: std.zig.Ast.Node.Index) ?[]const u8 {
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
    const comment_as_source_code = ast.source[index_where_comment_declared..index_where_identifier_declared];

    var splitted_lines = std.mem.splitScalar(u8, comment_as_source_code, '\n');

    var resultant_comment: std.ArrayList(u8) = .empty;

    while (splitted_lines.next()) |next_line| {
        if (std.mem.startsWith(u8, next_line, "///")) {
            resultant_comment.appendSlice(allocator, next_line[3..]) catch return null;
        } else if (std.mem.startsWith(u8, next_line, "//!")) {
            resultant_comment.appendSlice(allocator, next_line[3..]) catch return null;
        } else if (std.mem.startsWith(u8, next_line, "//")) {
            resultant_comment.appendSlice(allocator, next_line[3..]) catch return null;
        }
    }

    return resultant_comment.toOwnedSlice(allocator) catch return null;
}

fn get_line_number(ast: std.zig.Ast, decl: std.zig.Ast.Node.Index) u32 {
    // get the first token.
    const first_token = ast.firstToken(decl);
    // getting the exact index of the character at which the token is starting.
    const byte_offset_kind_of_index = ast.tokenStart(first_token);

    // counting the number of new line characters from the 0th line till the byte offest
    return @as(u32, @intCast(std.mem.count(u8, ast.source[0..byte_offset_kind_of_index], "\n"))) + 1;
}

/// Just noticed that other programming languages
/// only index the pub/export declared functions.
fn check_if_declaration_public(ast: std.zig.Ast, decl: std.zig.Ast.Node.Index) bool {
    const first = ast.firstToken(decl);

    return switch (ast.tokenTag(first)) {
        .keyword_pub,
        .keyword_export,
        => true,
        else => false,
    };
}

const allocator = std.heap.c_allocator;

/// I am making this to ensure that any string
/// being returned from this is definitley
/// allocated.
export fn parse(_source: [*:0]const u8) [*:0]const u8 {
    const source = std.mem.span(_source);

    const res = parse_zig(source) catch {
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

fn visitDecl(
    ast: std.zig.Ast,
    decl: std.zig.Ast.Node.Index,
    list: *std.ArrayList(identifier),
    gpa: std.mem.Allocator,
) !void {
    if (!check_if_declaration_public(ast, decl))
        return;

    if (process_declaration(ast, decl)) |r| {
        try list.append(gpa, r);
    }

    const var_decl = ast.fullVarDecl(decl) orelse return;

    var buffer: [2]std.zig.Ast.Node.Index = undefined;

    const init_node = var_decl.ast.init_node.unwrap() orelse return;

    const container = ast.fullContainerDecl(&buffer, init_node) orelse return;

    for (container.ast.members) |member| {
        try visitDecl(ast, member, list, gpa);
    }
}

fn process_declaration_only_test(ast: std.zig.Ast, decl: std.zig.Ast.Node.Index) ?identifier {
    var identifier_to_return: identifier = undefined;
    const index = @intFromEnum(decl);

    const tags = ast.nodes.items(.tag);

    const comment = returns_the_comment_before_the_identifier_nullable(ast, decl);

    const line_number = get_line_number(ast, decl);
    switch (tags[index]) {
        .test_decl => {
            const token = ast.nodeMainToken(decl);
            const name = ast.tokenSlice(token + 1);
            // const signature = ast.getNodeSource(decl);

            identifier_to_return = .{
                .comment = comment,
                .name = name,
                .type = "test",
                .signature = null,
                .line_number = line_number,
            };
        },
        else => {
            return null;
        },
    }
    return identifier_to_return;
}

fn returns_source_inside_struct_body_till_the_key_value_pairs(
    ast: std.zig.Ast,
    init_node: std.zig.Ast.Node.Index,
    container: std.zig.Ast.full.ContainerDecl,
) []const u8 {
    var open_brace_token = container.ast.main_token + 1;
    while (ast.tokenTag(open_brace_token) != .l_brace) : (open_brace_token += 1) {}

    const source_starts_from = ast.tokenStart(open_brace_token) + 1;

    var end_offset = ast.tokenStart(ast.lastToken(init_node));

    for (container.ast.members) |member| {
        if (ast.fullVarDecl(member) == null and ast.fullContainerField(member) == null) {
            end_offset = ast.tokenStart(ast.firstToken(member));
            break;
        }
    }

    return ast.source[source_starts_from..end_offset];
}

fn from_the_end_of_key_value_pairs_till_the_struct_body_end(
    ast: std.zig.Ast,
    init_node: std.zig.Ast.Node.Index,
    container: std.zig.Ast.full.ContainerDecl,
) []const u8 {
    var start_offset = ast.tokenStart(ast.lastToken(init_node));

    for (container.ast.members) |member| {
        if (ast.fullVarDecl(member) == null and ast.fullContainerField(member) == null) {
            start_offset = ast.tokenStart(ast.firstToken(member));
            break;
        }
    }

    const close_token = ast.lastToken(init_node);
    var close_end = ast.tokenStart(close_token) + ast.tokenSlice(close_token).len;
    close_end -= 1; // becuase of the end }, will cause parsing issues.

    return ast.source[start_offset..close_end];
}

fn make_container_identifier(
    ast: std.zig.Ast,
    init_node: std.zig.Ast.Node.Index,
    container: std.zig.Ast.full.ContainerDecl,
    comment: ?[]const u8,
    name: []const u8,
    type_name: []const u8,
    line_number: u32,
) ?identifier {
    var signature = returns_source_inside_struct_body_till_the_key_value_pairs(ast, init_node, container);
    const if_valid_this_should_look_like_a_normal_file = from_the_end_of_key_value_pairs_till_the_struct_body_end(ast, init_node, container);

    const z = allocator.dupeZ(u8, if_valid_this_should_look_like_a_normal_file) catch return null;
    defer allocator.free(z);
    const parsed_zig = parse_zig(z) catch return null;
    defer allocator.free(parsed_zig);

    var signature_buffer: std.ArrayList(u8) = .empty;
    defer signature_buffer.deinit(allocator);
    signature_buffer.appendSlice(allocator, signature) catch return null;

    const parsed_identifiers = std.json.parseFromSlice([]identifier, allocator, parsed_zig, .{}) catch return null;
    defer parsed_identifiers.deinit();

    for (parsed_identifiers.value) |item| {
        if (item.signature) |item_signature| {
            signature_buffer.appendSlice(allocator, item_signature) catch return null;
        }
    }

    signature = signature_buffer.toOwnedSlice(allocator) catch return null;

    return identifier{
        .comment = comment,
        .name = name,
        .type = type_name,
        .signature = signature,
        .line_number = line_number,
    };
}

fn process_declaration(ast: std.zig.Ast, decl: std.zig.Ast.Node.Index) ?identifier {
    var identifier_to_return: identifier = undefined;
    const index = @intFromEnum(decl);

    const tags = ast.nodes.items(.tag);
    const data = ast.nodes.items(.data);

    const comment = returns_the_comment_before_the_identifier_nullable(ast, decl);

    const line_number = get_line_number(ast, decl);
    switch (tags[index]) {
        .fn_decl => {
            if (!check_if_declaration_public(ast, decl)) {
                return null;
            }
            const proto = data[index].node_and_node[0];
            const token = ast.nodeMainToken(proto);
            const name = ast.tokenSlice(token + 1);
            const signature = ast.getNodeSource(proto);

            identifier_to_return = .{
                .comment = comment,
                .name = name,
                .type = "function",
                .signature = signature,
                .line_number = line_number,
            };
        },
        .global_var_decl,
        .local_var_decl,
        .simple_var_decl,
        .aligned_var_decl,
        => {
            const token = ast.nodeMainToken(decl);
            const name = ast.tokenSlice(token + 1);

            const var_decl = ast.fullVarDecl(decl) orelse return null;

            const init_node = var_decl.ast.init_node.unwrap() orelse return null;

            var buffer: [2]std.zig.Ast.Node.Index = undefined;

            const container = ast.fullContainerDecl(&buffer, init_node) orelse return null;

            if (ast.tokenTag(container.ast.main_token) == .keyword_struct) {
                return make_container_identifier(ast, init_node, container, comment, name, "struct", line_number);
            }
            if (ast.tokenTag(container.ast.main_token) == .keyword_enum) {
                return make_container_identifier(ast, init_node, container, comment, name, "enum", line_number);
            }
            if (ast.tokenTag(container.ast.main_token) == .keyword_union) {
                return make_container_identifier(ast, init_node, container, comment, name, "union", line_number);
            }
            if (ast.tokenTag(container.ast.main_token) == .keyword_opaque) {
                return make_container_identifier(ast, init_node, container, comment, name, "opaque", line_number);
            }
            const signature = ast.getNodeSource(decl);

            identifier_to_return = .{
                .comment = comment,
                .name = name,
                .type = "variable",
                .signature = signature,
                .line_number = line_number,
            };
        },
        .test_decl => {
            const token = ast.nodeMainToken(decl);
            const name = ast.tokenSlice(token + 1);
            // const signature = ast.getNodeSource(decl);

            identifier_to_return = .{
                .comment = comment,
                .name = name,
                .type = "test",
                .signature = null,
                .line_number = line_number,
            };
        },
        else => {
            return null;
        },
    }
    return identifier_to_return;
}

fn parse_zig(source: [:0]const u8) ![]const u8 {
    var ast = try std.zig.Ast.parse(
        allocator,
        source,
        .zig,
    );

    defer ast.deinit(allocator);

    var result_to_return: std.ArrayList(identifier) = .empty;
    defer result_to_return.deinit(allocator);

    for (ast.rootDecls()) |decl| {
        if (process_declaration_only_test(ast, decl)) |res| {
            try result_to_return.append(
                allocator,
                res,
            );
        }
        try visitDecl(ast, decl, &result_to_return, allocator);
    }

    const result = try std.json.Stringify.valueAlloc(allocator, result_to_return.items, .{});
    for (0..result_to_return.items.len) |i| {
        if (result_to_return.items[i].comment) |c| {
            allocator.free(c);
        }
        if (std.mem.eql(u8, result_to_return.items[i].type, "struct") or
            std.mem.eql(u8, result_to_return.items[i].type, "enum") or
            std.mem.eql(u8, result_to_return.items[i].type, "union") or
            std.mem.eql(u8, result_to_return.items[i].type, "opaque"))
        {
            if (result_to_return.items[i].signature) |s| {
                allocator.free(s);
            }
        }
    }

    return result;
}

test "normal_test" {
    const test_code: [*:0]const u8 = "const std = @import(\"zig\");";
    const res = parse(test_code);
    std.debug.print("{s}", .{res});
}
