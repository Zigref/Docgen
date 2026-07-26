#include <iostream>

extern "C"
{
    const char *parse(const char *_source);
}

const char x[] = "const std = @import(\"zig\"); const std2 = @import(\"zig\");";

int main()
{
    std::cout << "This is from C++" << std::endl;
    std::cout << parse(x) << std::endl;

    return 0;
}