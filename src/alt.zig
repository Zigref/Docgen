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

/// This function replaces body of every single
/// function with {}
///
/// Parameters:
///     gpa: The allocator
///     source: Zig source code
/// Returns:
///     Zig source code with bodies of all functions replaced with {}
pub fn make_all_function_body_empty(gpa: std.mem.Allocator, source: [:0]const u8) ![:0]const u8 {
    var ast = try std.zig.Ast.parse(gpa, source, .zig);
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
pub fn capture_doc_comment(allocator: std.mem.Allocator, ast: std.zig.Ast, decl: std.zig.Ast.Node.Index) ?[]const u8 {
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

test "make_all_function_body_empty" {
    const test_zig_source_code: [:0]const u8 =
        \\ const std = @import("std");
        \\
        \\ /// test
        \\ pub fn tester() {
        \\   var something = "asd";
        \\   _ = something;
        \\ }
        \\ pub fn tester_2() {
        \\   var something = "asd";
        \\   _ = something;
        \\ }
    ;
    const res = try make_all_function_body_empty(std.heap.page_allocator, test_zig_source_code);
    std.debug.print("{s}", .{res});
}
