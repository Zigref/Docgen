#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <nlohmann/json.hpp>

extern "C" {
const char* parse_zig_source(const char* _source);
void free_zig_string(const char* _string_to_free);
}

std::string get_git_commit_hash(const std::string& dir) {
    std::string cmd = "git -C \"" + dir + "\" rev-parse HEAD";
    FILE* f = popen(cmd.c_str(), "r");

    char buf[41]{};
    fgets(buf, sizeof(buf), f);
    pclose(f);

    return buf;
}

static std::string trim(const std::string& str)
{
    const auto first = str.find_first_not_of(" \t\r\n");
    if (first == std::string::npos)
    {
        return "";
    }
    const auto last = str.find_last_not_of(" \t\r\n");
    return str.substr(first, last - first + 1);
}

/// Skip directory that contain unnesecary code.
static bool should_skip_this_folder(const std::filesystem::path& rel)
{
    for (const auto& part : rel)
    {
        const auto segment = part.string();
        if (segment == "deps" || segment == "vendor" || segment == "third_party" || segment == ".zig-cache" || segment
            == "zig-cache" || segment == "zig-out" || segment == ".git")
        {
            return true;
        }
    }
    return false;
}

int main(int argc, char* argv[])
{
    if (argc != 2)
    {
        std::cout << "Usage:" << std::endl;
        std::cout << "      zigref path/to/input/folder" << std::endl;
        return 0;
    }
    std::filesystem::path input_folder = argv[1];

    nlohmann::json file_results;

    std::string top_level_documentation = "";

    try
    {
        bool already_parsed_the_root_file_for_documentation = false;
        for (const auto& entry :
             std::filesystem::recursive_directory_iterator(input_folder))
        {
            if (!entry.is_regular_file())
            {
                continue;
            }

            if (entry.path().extension() != ".zig")
            {
                continue;
            }

            const auto rel = std::filesystem::relative(entry.path(), input_folder);
            if (should_skip_this_folder(rel))
            {
                continue;
            }

            if (!already_parsed_the_root_file_for_documentation)
            {
                if (rel.string() == "src/root.zig" || rel.string() == "src/lib.zig")
                {
                    // means, this file is the one
                    // which will be the chosen as the main file
                    // of the library.
                    // means, it might have the //! thingy at the start.
                    // hence, I will be using it for the main, top level documentation.
                    std::ifstream file(entry.path(), std::ios::binary);

                    if (!file)
                    {
                        std::cerr << "File that should exist, somehow doesn't exist: "
                            << entry.path() << std::endl;
                        return 0;
                    }

                    std::string line;
                    while (std::getline(file, line))
                    {
                        if (line.compare(0, 3, "//!") == 0)
                        {
                            // the line is starting with //!
                            if (line.length() >= 3)
                            {
                                top_level_documentation += trim(line.substr(3)) + '\n';
                            }
                        }
                        else
                        {
                            // means, the line is no more starting with //!
                            break;
                        }
                    }

                    already_parsed_the_root_file_for_documentation = true;
                }
            }

            std::ifstream file(entry.path(), std::ios::binary);

            if (!file)
            {
                std::cerr << "File that should exist, somehow doesn't exist: "
                    << entry.path() << std::endl;
                return 0;
            }
            std::stringstream buffer;
            buffer << file.rdbuf();

            const char* result = parse_zig_source(buffer.str().c_str());
            nlohmann::json as_json = nlohmann::json::parse(result);

            nlohmann::json* current = &file_results;
            for (const auto& part : rel)
            {
                current = &((*current)[part.string()]);
            }
            *current = as_json;
        }
    }
    catch (std::exception& e)
    {
        std::cerr << "Filesystem error: " << e.what() << '\n';
        return 1;
    }

    nlohmann::json final_results;
    nlohmann::json config;
    config["commit_hash"] = get_git_commit_hash(input_folder);
    final_results["documentation"] = file_results;
    final_results["top_level_documentation"] = top_level_documentation == "" ? nullptr : top_level_documentation;
    final_results["config"] = config;

    std::cout << final_results.dump() << std::endl;

    return 0;
}
