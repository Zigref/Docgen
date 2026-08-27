#include <fstream>
#include <iostream>
#include <string>
#include <miniz/miniz.h>
#include <sstream>
#include <nlohmann/json.hpp>

static std::string trim(const std::string &str)
{
    const auto first = str.find_first_not_of(" \t\r\n");
    if (first == std::string::npos)
    {
        return "";
    }
    const auto last = str.find_last_not_of(" \t\r\n");
    return str.substr(first, last - first + 1);
}
extern "C"
{
    const char *parse_zig_source(const char *_source);
    void free_zig_string(const char *_string_to_free);
}

#include <brotli/encode.h>
#include <string>

void brotli_compress_string(const std::string &string_to_compress)
{
    size_t size = BrotliEncoderMaxCompressedSize(string_to_compress.size());
    std::string out(size, '\0');

    BrotliEncoderCompress(
        BROTLI_MAX_QUALITY,
        BROTLI_MAX_WINDOW_BITS,
        BROTLI_MODE_TEXT,
        string_to_compress.size(),
        (const uint8_t *)string_to_compress.data(),
        &size,
        reinterpret_cast<uint8_t *>(out.data()));

    out.resize(size);
    std::cout.write(out.c_str(), size);
}

std::string get_git_commit_hash(mz_zip_archive *zip_archive_main_struct)
{
    return "";
}

/// Skip directory that contain unnesecary code.
static bool should_skip_this_folder(std::stringstream &rel)
{
    std::string segment;

    while (std::getline(rel, segment, '/'))
    {
        if (segment == "zig-pkg" || segment == "deps" || segment == "vendor" ||
            segment == "third_party" || segment == ".zig-cache" || segment == "zig-cache" ||
            segment == "zig-out" || segment == ".git" || segment == "example" ||
            segment == "examples")
        {
            return true;
        }
    }

    return false;
}

int main(int argc, char *argv[])
{
    if (argc != 2)
    {
        std::cout << "Usage:" << std::endl;
        std::cout << "      zigref path/to/input/zip/file" << std::endl;
        return 0;
    }
    mz_zip_archive zip_archive_main_struct{};
    mz_zip_reader_init_file(&zip_archive_main_struct, argv[1], 0);

    nlohmann::json file_results;

    std::string top_level_documentation = "";

    try
    {
        bool already_parsed_the_root_file_for_documentation = false;
        int file_roll_number = 0;
        for (mz_uint i = 0; i < mz_zip_reader_get_num_files(&zip_archive_main_struct); i++)
        {
            char filename[256];

            mz_zip_reader_get_filename(&zip_archive_main_struct, i, filename, sizeof(filename));

            if (const char *ext = strrchr(filename, '.'); !ext || strcmp(ext, ".zig") != 0)
            {
                continue;
            }

            std::stringstream rel(filename);
            if (should_skip_this_folder(rel))
            {
                continue;
            }

            if (!already_parsed_the_root_file_for_documentation)
            {
                if (rel.str() == "src/root.zig" || rel.str() == "src/lib.zig")
                {
                    // means, this file is the one
                    // which will be the chosen as the main file
                    // of the library.
                    // means, it might have the //! thingy at the start.
                    // hence, I will be using it for the main, top level documentation.

                    size_t size;
                    void *data = mz_zip_reader_extract_to_heap(&zip_archive_main_struct, i, &size, 0);

                    if (!data)
                    {
                        std::cerr << "File that should exist, somehow doesn't exist: "
                                  << filename << std::endl;
                        return 0;
                    }

                    std::string source((const char *)data, size);
                    free(data);

                    std::istringstream file(source);

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

            size_t size;
            void *data = mz_zip_reader_extract_to_heap(&zip_archive_main_struct, i, &size, 0);

            if (!data)
            {
                std::cerr << "File that should exist, somehow doesn't exist: "
                          << filename << std::endl;
                return 0;
            }

            std::string source((const char *)data, size);
            free(data);

            const char *result = parse_zig_source(source.c_str());
            nlohmann::json as_json = nlohmann::json::parse(result);

            nlohmann::json *current = &file_results["project_tree"];

            std::string part;

            while (std::getline(rel, part, '/'))
            {
                current = &((*current)[part]);
            }
            *current = file_roll_number;

            file_results["actual_data"].push_back(as_json); // The roll number will directly map to this
            file_roll_number++;
        }
    }
    catch (std::exception &e)
    {
        std::cerr << "Filesystem error: " << e.what() << '\n';
        return 1;
    }

    nlohmann::json final_results;
    nlohmann::json config;
    config["commit_hash"] = get_git_commit_hash(&zip_archive_main_struct);
    final_results["metadata"]["top_level_documentation"] = top_level_documentation;
    final_results["metadata"] = config;
    final_results["metadata"]["project_tree"] = file_results["project_tree"];
    final_results["data"] = file_results["actual_data"];
    brotli_compress_string(final_results.dump());

    mz_zip_reader_end(&zip_archive_main_struct);
    return 0;
}
