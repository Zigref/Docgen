#include <iostream>
#include <filesystem>
#include <fstream>
#include <nlohmann/json.hpp>

extern "C"
{
    const char *parse(const char *_source);
    void free_zig_string(const char *_string_to_free);
}

int main(int argc, char *argv[])
{
    if (argc != 2)
    {
        std::cout << "Usage:" << std::endl;
        std::cout << "      zigref path/to/input/folder" << std::endl;
        return 0;
    }
    std::filesystem::path input_folder = argv[1];

    nlohmann::json final_results;

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

            std::ifstream file(entry.path(), std::ios::binary);

            if (!file)
            {
                std::cerr << "File that should exist, somehow doesn't exist: " << entry.path() << std::endl;
                return 0;
            }
            std::stringstream buffer;
            buffer << file.rdbuf();

            const char *result = parse(buffer.str().c_str());
            nlohmann::json as_json = nlohmann::json::parse(result);

            auto rel = std::filesystem::relative(entry.path(), input_folder);
            final_results[rel.string()] = as_json;
        }
    }
    catch (std::exception &e)
    {
        std::cerr << "Filesystem error: " << e.what() << '\n';
        return 1;
    }

    std::cout << final_results.dump() << std::endl;

    return 0;
}
