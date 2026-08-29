//! ======================================
//! =   _____ _         ____         __  =
//! =  |__  /(_)  __ _ |  _ \  ___  / _| =
//! =    / / | | / _` || |_) |/ _ \| |_  =
//! =   / /_ | || (_| ||  _ <|  __/|  _| =
//! =  /____||_| \__, ||_| \_\\___||_|   =
//! =            |___/                   =
//! ======================================
//!
//! I just thought, what if I first remove
//! the body content of each function.
//! And store only the declarations, before
//! the parsing even begins.
//! Also, the source code has gone unnesecarilly complex.
//! I am starting to comment each and every single thing.
//!
//!
//!
//! Ok, I need to think about a very specific algorithmm:
//!
//! Hmm, ( O-O')
//! We will:
//!     - First remove bodies of all functions.
//!     - Loop over root declarations:
//!         TAG_1(namespace_if_present):
//!         - We will read each tag:
//!             - if the tag is private:
//!                  - skip that entire declaration + definition.
//!                  - No need to check whats nested inside.
//!                  - Because a pub inside a private, is anyways
//!                    not accessible.
//!             - else:
//!                  - Store the line number.
//!                  - Store the comment if present.
//!                  - if the tag is a fn/variable/constant.
//!                     - add it to documentation
//!                   - else if tag is a struct/enum/union/opaque(if it is a container type).
//!                     - if it has fields (in zig these are public if the struct is public) store them.
//!                     - if it has anything after the fields, something like functions, or constants.
//!                         - You can think that part like a seperate file of zig.
//!                         - Hence I will goto TAG_1(with the namespace).
//!                         - Hence, this becomes recursive.
//!

const std = @import("std");

pub const identifier = struct {
    name: []const u8,
    comment: ?[]const u8,
    type: enum {
        constant,
        function,
        @"struct",
        @"opaque",
        @"union",
        @"test",
        @"enum",
    },
    partial_definition: ?[]const u8,
    line_number: u32,

    pub fn deinit(self: *identifier, allocator: std.mem.Allocator) void {
        if (self.comment) |comment| allocator.free(comment);
        if (self.partial_definition) |pd| allocator.free(pd);
    }

    pub fn jsonStringify(self: @This(), s: *std.json.Stringify) std.json.Stringify.Error!void {
        try s.beginObject();
        try s.objectField("name");
        try s.write(self.name);
        if (self.comment) |comment| {
            try s.objectField("comment");
            try s.write(comment);
        }
        try s.objectField("type");
        try s.write(self.type);
        if (self.partial_definition) |partial_definition| {
            try s.objectField("partial_definition");
            try s.write(partial_definition);
        }
        try s.objectField("line_number");
        try s.write(self.line_number);
        try s.endObject();
    }
};

/// Ok, so, now think of the documentation like a tree.
/// namespace is a single node in the tree.
/// this namespace has:
///     - a name (obviously)
///     - children components (the things declared inside the namespace).
///     - And the children namespaces it has (these can be structs/enums/uniques/opaques).
pub const namespace = struct {
    name: []const u8,
    components: std.ArrayList(identifier),
    namespaces: std.ArrayList(namespace),

    pub fn deinit(self: *namespace, allocator: std.mem.Allocator) void {
        for (self.components.items) |*components| components.deinit(allocator);
        self.components.deinit(allocator);
        for (self.namespaces.items) |*namespaces| namespaces.deinit(allocator);
        self.namespaces.deinit(allocator);
    }

    pub fn jsonStringify(self: @This(), s: *std.json.Stringify) std.json.Stringify.Error!void {
        try s.beginObject();
        try s.objectField("name");
        try s.write(self.name);
        try s.objectField("components");
        try s.write(self.components.items);
        try s.objectField("namespaces");
        try s.write(self.namespaces.items);
        try s.endObject();
    }
};

/// This function replaces body of every single
/// function with {}
///
/// Parameters:
///     gpa: The allocator
///     source: Zig source code
/// Returns:
///     Zig source code with bodies of all functions replaced with {}
fn make_all_function_body_empty(gpa: std.mem.Allocator, source: [:0]const u8) ![:0]const u8 {
    var ast = std.zig.Ast.parse(gpa, source, .zig) catch @panic("problem with zig source code.");
    if (ast.errors.len > 0) return error.problem_with_zig_code;
    defer ast.deinit(gpa);

    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(gpa);

    var cursor: usize = 0; // This will store character index.
    for (ast.nodes.items(.tag), 0..) |tag, node_index| {
        if (tag != .fn_decl) {
            continue;
        }

        const body_of_the_function = ast.nodeData(@enumFromInt(node_index)).node_and_node[1];

        // the character from which the body starts
        const start_character_index = ast.tokenStart(ast.firstToken(body_of_the_function));

        // Skipping nested functions
        if (start_character_index < cursor) {
            continue;
        }

        // This contains the last token of the function body (Not the last index).
        const last_token = ast.lastToken(body_of_the_function);

        // This is like, you are at the last token, but not the last index.
        // To really get the last index, you need to add the length of the token
        // to the token starting index.
        const end_index = ast.tokenStart(last_token) + ast.tokenSlice(last_token).len;

        // Like, appending the source code of the declaration
        try result.appendSlice(gpa, ast.source[cursor..start_character_index]);

        // Now, appending the new body.
        try result.appendSlice(gpa, "{}");

        // Now, the cursor will start reading from the end index, i.e after the }.
        cursor = end_index;
    }

    try result.appendSlice(gpa, ast.source[cursor..]);
    return result.toOwnedSliceSentinel(gpa, 0);
}

/// This function returns the doc comment associated
/// with a declaration. If no doc comment is written, it returns null.
/// Parameters:
///     allocator
///     ast
///     decl: the declaration whose comment would be returned.
/// Returns:
///     The comment of the declaration or null if no comment present.
fn capture_doc_comment(allocator: std.mem.Allocator, ast: std.zig.Ast, decl: std.zig.Ast.Node.Index) !?[]const u8 {
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
            resultant_comment.appendSlice(allocator, std.mem.trim(u8, next_line[3..], " \t\r\n ")) catch {
                resultant_comment.deinit(allocator);
                return null;
            };
        } else if (std.mem.startsWith(u8, next_line, "//!")) {
            resultant_comment.appendSlice(allocator, std.mem.trim(u8, next_line[3..], " \t\r\n ")) catch {
                resultant_comment.deinit(allocator);
                return null;
            };
        } else if (std.mem.startsWith(u8, next_line, "//")) {
            resultant_comment.appendSlice(allocator, std.mem.trim(u8, next_line[2..], " \t\r\n ")) catch {
                resultant_comment.deinit(allocator);
                return null;
            };
        }
    }

    return resultant_comment.toOwnedSlice(allocator) catch |err| {
        resultant_comment.deinit(allocator);
        return err;
    };
}

/// This function checks if the parser should parse/ignore a declaration.
fn parser_should_parse_this_declaration(ast: std.zig.Ast, decl: std.zig.Ast.Node.Index) bool {
    const first = ast.firstToken(decl);

    return switch (ast.tokenTag(first)) {
        .keyword_pub,
        .keyword_export,
        .keyword_test,
        => true,
        else => false,
    };
}

// This function returns a container's source code as two seperate components.
//
// For example if this is a struct:
//
// struct/enum/unique/opaque {
//     field1 : type,
//     field2 : type,
//     field3 : type,
//
//     pub const some_constant = value;
//     pub fn some_method_1(){...}
//     pub fn some_method_2(){...}
// }
//
// This returns all the fields as .fields
// and all the other things as .members
// Only source code.
fn returns_container_source_as_2_components(
    ast: std.zig.Ast,
    init_node: std.zig.Ast.Node.Index,
    container: std.zig.Ast.full.ContainerDecl,
) struct {
    fields: ?[]const u8,
    members: ?[]const u8,
} {
    // the main node is basically the struct/enum/opaque/unique word.
    var open_brace_token = container.ast.main_token + 1;
    // we will loop till we reach l brace.
    while (ast.tokenTag(open_brace_token) != .l_brace) : (open_brace_token += 1) {}

    // obviously the code starts after the {.
    const source_starts_from = ast.tokenStart(open_brace_token) + 1;

    // The end of the container body i.e }.
    var split_offset = ast.tokenStart(ast.lastToken(init_node));

    var found_field = false;
    var found_member = false;

    for (container.ast.members) |member| {
        if (ast.fullContainerField(member) != null) {
            found_field = true;
        } else if (!found_member) {
            // We found a member because there is a full declaration.
            split_offset = ast.tokenStart(ast.firstToken(member));
            found_member = true;
        }
    }

    const close_offset = ast.tokenStart(ast.lastToken(init_node));
    return .{
        .fields = if (found_field) ast.source[source_starts_from..split_offset] else null,
        .members = if (found_member) ast.source[split_offset .. close_offset - 1] else null,
    };
}

/// Returns the line number of a declaration.
fn get_line_number(ast: std.zig.Ast, decl: std.zig.Ast.Node.Index) u32 {
    // get the first token.
    const first_token = ast.firstToken(decl);
    // getting the exact index of the character at which the token is starting.
    const byte_offset_kind_of_index = ast.tokenStart(first_token);

    // counting the number of new line characters from the 0th line till the byte offest
    return @as(u32, @intCast(std.mem.count(u8, ast.source[0..byte_offset_kind_of_index], "\n"))) + 1;
}

pub fn recursive_parse(allocator: std.mem.Allocator, source: [:0]const u8, name: []const u8) !namespace {
    var ast = std.zig.Ast.parse(
        allocator,
        source,
        .zig,
    ) catch @panic("problem with zig source code.");
    if (ast.errors.len > 0) @panic("problem with zig source code.");

    defer ast.deinit(allocator);

    const tags = ast.nodes.items(.tag);
    const data = ast.nodes.items(.data);

    var result: namespace = .{
        .name = name,
        .components = .empty,
        .namespaces = .empty,
    };
    errdefer result.components.deinit(allocator);
    errdefer result.namespaces.deinit(allocator);

    for (ast.rootDecls()) |decl| {
        if (!parser_should_parse_this_declaration(ast, decl)) {
            continue;
        }
        // var identifier_to_return: identifier = undefined;
        const comment_nullable = try capture_doc_comment(allocator, ast, decl);
        const line_number = get_line_number(ast, decl);

        const index = @intFromEnum(decl);
        switch (tags[index]) {
            .test_decl => {
                const token = ast.nodeMainToken(decl);
                const name_of = ast.tokenSlice(token + 1);
                // const signature = ast.getNodeSource(decl);

                const res: identifier = .{
                    .comment = comment_nullable,
                    .name = name_of,
                    .type = .@"test",
                    .line_number = line_number,
                    .partial_definition = null,
                };
                errdefer if (comment_nullable) |comment| allocator.free(comment);
                try result.components.append(allocator, res);
            },
            .fn_decl,
            .fn_proto,
            .fn_proto_simple,
            .fn_proto_multi,
            .fn_proto_one,
            => {
                // For a normal function declaration, i.e fn_decl
                // the proto contains the entire declaration.
                // But for something like extern function, its only
                // the declaration thats present, hence, anything
                // till the ; would be the declaration for extern functions.
                const proto = if (tags[index] == .fn_decl) data[index].node_and_node[0] else decl;
                const token = ast.nodeMainToken(proto);
                const name_of = ast.tokenSlice(token + 1);
                const partial_definition = try allocator.dupe(u8, ast.getNodeSource(proto));

                const res: identifier = .{
                    .comment = comment_nullable,
                    .name = name_of,
                    .type = .function,
                    .line_number = line_number,
                    .partial_definition = partial_definition,
                };
                errdefer {
                    if (comment_nullable) |c| allocator.free(c);
                    allocator.free(partial_definition);
                }
                try result.components.append(allocator, res);
            },
            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => {
                const token = ast.nodeMainToken(decl);
                const name_of = ast.tokenSlice(token + 1);

                const var_decl = ast.fullVarDecl(decl) orelse continue;

                const init_node = var_decl.ast.init_node.unwrap() orelse {
                    // these are the extern declarations
                    // that don't have an assignment, hence,
                    // putting these here.
                    const pd = try allocator.dupe(u8, ast.getNodeSource(decl));
                    errdefer {
                        if (comment_nullable) |c| allocator.free(c);
                        allocator.free(pd);
                    }
                    try result.components.append(allocator, .{
                        .comment = comment_nullable,
                        .name = name_of,
                        .type = .constant,
                        .line_number = line_number,
                        .partial_definition = pd,
                    });
                    continue;
                };

                var buffer: [2]std.zig.Ast.Node.Index = undefined;

                const container = ast.fullContainerDecl(&buffer, init_node) orelse {
                    const pd = try allocator.dupe(u8, ast.getNodeSource(decl));
                    errdefer {
                        if (comment_nullable) |c| allocator.free(c);
                        allocator.free(pd);
                    }
                    try result.components.append(allocator, .{
                        .comment = comment_nullable,
                        .name = name_of,
                        .type = .constant,
                        .line_number = line_number,
                        .partial_definition = pd,
                    });
                    continue;
                };

                const source_componenets = returns_container_source_as_2_components(ast, init_node, container);

                // Only storing here the fields, not the members
                // to avouid duplication
                var open_brace_token = container.ast.main_token + 1;
                while (ast.tokenTag(open_brace_token) != .l_brace) : (open_brace_token += 1) {}
                const header = ast.source[ast.tokenStart(ast.firstToken(decl)) .. ast.tokenStart(open_brace_token) + 1];

                const signature = if (source_componenets.fields) |fields|
                    try std.mem.concat(allocator, u8, &.{ header, fields, "}" })
                else
                    try std.mem.concat(allocator, u8, &.{ header, "}" });

                const ContainerType = @TypeOf(@as(identifier, undefined).type);
                const type_of_container: ContainerType = switch (ast.tokenTag(container.ast.main_token)) {
                    .keyword_struct => .@"struct",
                    .keyword_enum => .@"enum",
                    .keyword_union => .@"union",
                    .keyword_opaque => .@"opaque",
                    else => @panic("unknown container type."),
                };

                const res: identifier = .{
                    .comment = comment_nullable,
                    .name = name_of,
                    .type = type_of_container,
                    .line_number = line_number,
                    .partial_definition = signature,
                };
                errdefer {
                    if (comment_nullable) |c| allocator.free(c);
                    allocator.free(signature);
                }
                try result.components.append(allocator, res);

                if (source_componenets.members) |members| {
                    const members_z = try allocator.dupeZ(u8, members);
                    const child_namespace = try recursive_parse(allocator, members_z, name_of);
                    try result.namespaces.append(allocator, child_namespace);
                }
            },
            else => @panic("unsupported root declaration type."),
        }
    }

    return result;
}

pub fn __main(allocator: std.mem.Allocator, source: [:0]const u8) ![]const u8 {
    // First, I will remove all function bodies from this source code.
    const sanitized = try make_all_function_body_empty(allocator, source);
    defer allocator.free(sanitized);

    // Now i will start the parsing process
    var root = try recursive_parse(allocator, sanitized, "root");
    defer root.deinit(allocator);

    const result = try std.json.Stringify.valueAlloc(allocator, root, .{});

    return result;
}

test "make_all_function_body_empty" {
    const test_zig_source_code: [:0]const u8 =
        \\ const std = @import("std");
        \\
        \\ /// test
        \\ pub fn tester() void {
        \\   var something = "asd";
        \\   _ = something;
        \\ }
        \\ pub fn tester_2() void {
        \\   var something = "asd";
        \\   _ = something;
        \\ }
    ;
    const res = try make_all_function_body_empty(std.heap.page_allocator, test_zig_source_code);
    defer std.heap.page_allocator.free(res);
    std.debug.print("{s}", .{res});
}
