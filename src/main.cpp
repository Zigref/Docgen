#include "process_repo.h"
#include <brotli/encode.h>
#include <filesystem>
#include <format>
#include <fstream>
#include <iostream>
#include <sqlite3.h>
#include <sstream>
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

int main()
{
    sqlite3* db;
    sqlite3_open("./zigistry.db", &db);

    sqlite3_stmt* stmt;
    sqlite3_prepare_v2(
        db,
        "SELECT id, latest_commit_hash, last_updated_in_this_database, stargazer_count FROM repos",
        -1,
        &stmt,
        nullptr);

    tf::Executor executor(8);
    tf::Taskflow taskflow;

    while (sqlite3_step(stmt) == SQLITE_ROW) {
        const auto res = split_modify_string(
            (const char*)sqlite3_column_text(stmt, 0));
        const auto provider = res[0] == "gh" ? "github.com" : "codeberg.org";

        const auto owner_name = res[1];
        const auto repo_name = res[2];
        const auto commit_hash = (const char*)sqlite3_column_text(stmt, 1);
        const auto repo_star_count = sqlite3_column_int(stmt, 3);
        taskflow.emplace([=] {
        const auto process_repo_res = process_repo(provider, owner_name, repo_name, commit_hash);
        const auto compressed_string = brotli_compress_string(process_repo_res, repo_star_count);

        const std::string folder = std::format("./database/{}/{}", res[0], owner_name);
        std::filesystem::create_directories(folder);

        const std::string file_name = std::format("{}/{}.br", folder, repo_name);

        std::ofstream file(file_name, std::ios::binary);
        file.write(compressed_string.data(), compressed_string.size()); });
    }
    executor.run(taskflow).wait();

    sqlite3_finalize(stmt);
    sqlite3_close(db);
    return 0;
}
