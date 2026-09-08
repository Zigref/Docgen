#include "../include/json.hpp"
#include <cerrno>
#include <chrono>
#include <cstring>
#include <curl/curl.h>
#include <format>
#include <fstream>
#include <iostream>
#include <miniz/miniz.h>
#include <signal.h>
#include <sstream>
#include <string>
#include <sys/wait.h>
#include <thread>
#include <unistd.h>
#include <vector>

#define MAX_ZIP_DOWNLOAD_SIZE 500ULL * 1024 * 1024 // this is 500MiB

static size_t curl_writer(void* data, size_t size, size_t count, void* user)
{
    auto* buffer = (std::string*)user;
    const size_t bytes = size * count;

    if (buffer->size() + bytes > MAX_ZIP_DOWNLOAD_SIZE) {
        return 0;
    }

    buffer->append((char*)data, bytes);
    return bytes;
}

static std::string fetch_zip(const char* url)
{
    std::string zip;
    CURL* curl = curl_easy_init();

    if (!curl)
        return { };

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_writer);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &zip);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

    const CURLcode res = curl_easy_perform(curl);

    curl_easy_cleanup(curl);

    if (res != CURLE_OK) {
        if (res == CURLE_WRITE_ERROR && zip.size() >= MAX_ZIP_DOWNLOAD_SIZE) {
            std::cerr << "Skipping repository: ZIP exceeds 500 MiB\n";
        } else {
            std::cerr << "Failed to download ZIP: "
                      << curl_easy_strerror(res) << '\n';
        }

        return { };
    }

    return zip;
}

static std::string trim(const std::string& str)
{
    const auto first = str.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) {
        return "";
    }
    const auto last = str.find_last_not_of(" \t\r\n");
    return str.substr(first, last - first + 1);
}
extern "C" {
const char* parse_zig_source(const char* _source);
void free_zig_string(const char* _string_to_free);
}

static bool try_to_parse(const std::string& source)
{
    pid_t pid = fork();

    if (pid < 0)
        return false;

    if (pid == 0) {
        alarm(5);
        parse_zig_source(source.c_str());
        _exit(0);
    }

    int status;
    if (waitpid(pid, &status, 0) < 0)
        return false;

    return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

std::string get_git_commit_hash(mz_zip_archive* zip_archive_main_struct)
{
    return "";
}

/// Skip directory that contain unnesecary code.
static bool should_skip_this_folder(const std::vector<std::string>& parts)
{
    for (const auto& segment : parts) {
        if (segment == "zig-pkg" || segment == "deps" || segment == "vendor" || segment == "third_party" || segment == ".zig-cache" || segment == "zig-cache" || segment == "zig-out" || segment == ".git" || segment == "example" || segment == "examples") {
            return true;
        }
    }

    return false;
}

std::string process_repo(std::string provider, std::string owner_name, std::string repo_name, std::string commit_hash)
{
    mz_zip_archive zip_archive_main_struct { };

    std::string file_to_fetch;
    const auto url_to_fetch = std::format("https://{}/{}/{}/archive/{}.zip", provider, owner_name, repo_name, commit_hash);

    auto zip = fetch_zip(url_to_fetch.c_str());

    if (zip.empty()) {
        return "{\"error\" : \"failed to fetch repo.\"}";
    }

    if (!mz_zip_reader_init_mem(
            &zip_archive_main_struct,
            zip.data(),
            zip.size(),
            0)) {
        return "{\"error\" : \"failed to read repo archive.\"}";
    }

    nlohmann::json file_results;
    file_results["project_tree"] = nlohmann::json::object();
    file_results["actual_data"] = nlohmann::json::array();

    std::string top_level_documentation = "";

    try {
        bool already_parsed_the_root_file_for_documentation = false;
        int file_roll_number = 0;
        for (mz_uint i = 0; i < mz_zip_reader_get_num_files(&zip_archive_main_struct); i++) {
            char filename[1024];

            if (!mz_zip_reader_get_filename(&zip_archive_main_struct, i, filename, sizeof(filename))) {
                continue;
            }

            if (const char* ext = strrchr(filename, '.'); !ext || strcmp(ext, ".zig") != 0) {
                continue;
            }

            std::vector<std::string> parts;
            std::string segment;
            std::stringstream ss(filename);

            while (std::getline(ss, segment, '/'))
                if (!segment.empty())
                    parts.push_back(segment);

            if (parts.size() < 2)
                continue;

            parts.erase(parts.begin());

            std::string rel_path;
            for (const auto& part : parts) {
                if (!rel_path.empty()) {
                    rel_path += '/';
                }
                rel_path += part;
            }
            if (should_skip_this_folder(parts)) {
                continue;
            }

            if (!already_parsed_the_root_file_for_documentation) {
                if (rel_path == "src/root.zig" || rel_path == "src/main.zig" || rel_path == "src/lib.zig") {
                    // means, this file is the one
                    // which will be the chosen as the main file
                    // of the library.
                    // means, it might have the //! thingy at the start.
                    // hence, I will be using it for the main, top level documentation.

                    size_t size;
                    void* data = mz_zip_reader_extract_to_heap(&zip_archive_main_struct, i, &size, 0);

                    if (!data) {
                        std::cerr << "File that should exist, somehow doesn't exist: "
                                  << filename << std::endl;
                    }

                    std::string source((const char*)data, size);
                    free(data);

                    std::istringstream file(source);

                    std::string line;
                    while (std::getline(file, line)) {
                        if (line.compare(0, 3, "//!") == 0) {
                            // the line is starting with //!
                            if (line.length() >= 3) {
                                top_level_documentation += trim(line.substr(3)) + '\n';
                            }
                        } else {
                            // means, the line is no more starting with //!
                            break;
                        }
                    }

                    already_parsed_the_root_file_for_documentation = true;
                }
            }

            size_t size;
            void* data = mz_zip_reader_extract_to_heap(&zip_archive_main_struct, i, &size, 0);

            if (!data) {
                std::cerr << "File that should exist, somehow doesn't exist: "
                          << filename << std::endl;
            }

            std::string source((const char*)data, size);
            free(data);

            // if parsing the file fails, I will skip the file.
            if (!try_to_parse(source)) {
                std::cerr << "Skipping file that failed the parse canary: "
                          << filename << std::endl;
                continue;
            }

            const char* result = parse_zig_source(source.c_str());
            nlohmann::json as_json;
            try {
                as_json = nlohmann::json::parse(result);
            } catch (std::exception& e) {
                return "{\"error\" : \"error while parsing.\"}";
            };
            nlohmann::json* current = &file_results["project_tree"];

            for (const auto& part : parts) {
                current = &((*current)[part]);
            }
            *current = file_roll_number;

            file_results["actual_data"].push_back(as_json); // The roll number will directly map to this
            file_roll_number++;
        }
    } catch (std::exception& e) {
        std::cerr << "Filesystem error: " << e.what() << '\n';
        std::exit(0);
    }

    nlohmann::json final_results;
    nlohmann::json config;
    config["commit_hash"] = commit_hash;
    config["project_tree"] = file_results.value("project_tree", nlohmann::json::object());
    if (!top_level_documentation.empty()) {
        config["top_level_documentation"] = top_level_documentation;
    }
    final_results["metadata"] = config;
    final_results["data"] = file_results.value("actual_data", nlohmann::json::array());

    mz_zip_reader_end(&zip_archive_main_struct);
    return final_results.dump();
}
