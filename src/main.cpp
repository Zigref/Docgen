#include "process_repo.h"
#include <brotli/encode.h>
#include <filesystem>
#include <format>
#include <fstream>
#include <iostream>
#include <sqlite3.h>
#include <sstream>
#include <string_view>
#include <taskflow/taskflow.hpp>

#define JSON_ERROR_RESPONCE "{\"error\" : \"the documentation generated exceeded the limit.\"}"

std::string brotli_compress_string(const std::string& string_to_compress, int repo_star_count)
{
    size_t size = BrotliEncoderMaxCompressedSize(string_to_compress.size());

    std::string out(size, '\0');
    BrotliEncoderCompress(
        BROTLI_MAX_QUALITY,
        BROTLI_MAX_WINDOW_BITS,
        BROTLI_MODE_TEXT,
        string_to_compress.size(),
        reinterpret_cast<const uint8_t*>(string_to_compress.data()),
        &size,
        reinterpret_cast<uint8_t*>(out.data()));
    out.resize(size);

    if (repo_star_count <= 10 && size > 15 * 1024) {
        return JSON_ERROR_RESPONCE;
    } else if (repo_star_count <= 20 && size > 25 * 1024) {
        return JSON_ERROR_RESPONCE;
    } else if (repo_star_count <= 100 && size > 50 * 1024) {
        return JSON_ERROR_RESPONCE;
    } else if (size > 70 * 1024) {
        return JSON_ERROR_RESPONCE;
    } else {
        return out;
    }
}
std::array<std::string, 3> split_modify_string(const char* str)
{
    std::stringstream ss(str);
    std::string part;

    std::array<std::string, 3> res;

    std::getline(ss, res[0], '/');
    std::getline(ss, res[1], '/');
    std::getline(ss, res[2], '/');

    return res;
}

const char* query = R"(

    SELECT repos.id, repos.latest_commit_hash, repos.stargazer_count,
    COALESCE(
        unixepoch(repos.last_updated_in_this_database) >= unixepoch('now', '-30 hours')
        OR unixepoch(repos.pushed_at) >= unixepoch('now', '-30 hours')
        , 1
    )
    FROM repos
    INNER JOIN packages
    ON packages.repo_id = repos.id

)";

int main(int argc, char** argv)
{
    const bool all = argc > 1 && std::string_view(argv[1]) == "--all";

    sqlite3* db;
    sqlite3_open("./zigistry.db", &db);

    sqlite3_stmt* stmt;
    sqlite3_prepare_v2(
        db,
        query,
        -1,
        &stmt,
        nullptr);

    tf::Executor executor(80);
    tf::Taskflow taskflow;

    int total_count = 0;
    int skipped_count = 0;
    int queued_count = 0;

    while (sqlite3_step(stmt) == SQLITE_ROW) {
        total_count++;
        const auto id_text = (const char*)sqlite3_column_text(stmt, 0);
        if (!id_text) {
            continue;
        }
        const auto res = split_modify_string(id_text);
        if (res[0].empty() || res[1].empty() || res[2].empty()) {
            continue;
        }
        const auto provider = res[0] == "gh" ? "github.com" : "codeberg.org";

        const auto owner_name = res[1];
        const auto repo_name = res[2];
        const auto commit_text = (const char*)sqlite3_column_text(stmt, 1);
        const std::string commit_hash = commit_text ? commit_text : "";
        if (commit_hash.empty()) {
            continue;
        }
        const auto repo_star_count = sqlite3_column_int(stmt, 2);
        const bool is_recent = sqlite3_column_int(stmt, 3);

        const std::string folder = std::format("./database/{}/{}", res[0], owner_name);
        const std::string file_name = std::format("{}/{}.br", folder, repo_name);

        if (!all && !is_recent && std::filesystem::exists(file_name)) {
            skipped_count++;
            continue;
        }

        queued_count++;
        taskflow.emplace([=] {
            const auto process_repo_res = process_repo(provider, owner_name, repo_name, commit_hash);
            const auto compressed_string = brotli_compress_string(process_repo_res, repo_star_count);

            std::filesystem::create_directories(folder);

            std::ofstream file(file_name, std::ios::binary);
            file.write(compressed_string.data(), compressed_string.size());
        });
    }

    std::cout << "total packages: " << total_count << "\n";
    std::cout << "skipped: " << skipped_count << "\n";
    std::cout << "going to generate: " << queued_count << "\n";

    executor.run(taskflow).wait();
    std::cout << "Documentation generation completed successfully.\n";

    sqlite3_finalize(stmt);
    sqlite3_close(db);
    return 0;
}
