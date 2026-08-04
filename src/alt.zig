//! I just thought, what if I first remove
//! the body content of each function.
//! And store only the declarations, before
//! the parsing even begins.
//! Also, the source code has gone unnesecarilly complex.
//! I am starting to comment each and every single thing.

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
