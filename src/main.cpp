#include <iostream>
#include <filesystem>

extern "C"
{
    const char *parse(const char *_source);
    void free_zig_string(const char *_string_to_free);
}

const char x[] = "const std = @import(\"zig\"); const std2 = @import(\"zig\");";

int main(int argc, char *argv[])
{
    if (argc != 2)
    {
        std::cout << "Usage:" << std::endl;
        std::cout << "      zigref path/to/input/folder" << std::endl;
        return 0;
    }
    std::filesystem::path input_folder = argv[1];

    try
    {
        for (const auto &entry : std::filesystem::recursive_directory_iterator(input_folder))
        {
            if (!entry.is_regular_file())
            {
                continue;
            }

            if (entry.path().extension() != ".zig")
            {
                continue;
            }

            std::cout << entry.path() << std::endl;
        }
    }
    catch (std::exception &e)
    {
        std::cerr << "Filesystem error: " << e.what() << '\n';
    }
    // std::cout << "This is from C++" << std::endl;
    // const char *res = parse(x);

    // std::cout << res << std::endl;

    // free_zig_string(res);

    return 0;
}