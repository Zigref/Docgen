#include <filesystem>
#include <fstream>
#include <iostream>
#include <nlohmann/json.hpp>

extern "C" {
const char *parse(const char *_source);
void free_zig_string(const char *_string_to_free);
}

int main(int argc, char *argv[]) {
  if (argc != 2) {
    std::cout << "Usage:" << std::endl;
    std::cout << "      zigref path/to/input/folder" << std::endl;
    return 0;
  }
  std::filesystem::path input_folder = argv[1];

  nlohmann::json file_results;

  bool already_parsed_the_root_file_for_documentation = false;

  std::string top_level_documentation = "";

  try {
    for (const auto &entry :
         std::filesystem::recursive_directory_iterator(input_folder)) {
      if (!entry.is_regular_file()) {
        continue;
      }

      if (entry.path().extension() != ".zig") {
        continue;
      }

      if (!already_parsed_the_root_file_for_documentation) {
        auto rel = std::filesystem::relative(entry.path(), input_folder);
        if (rel.string() == "src/root.zig" || rel.string() == "src/lib.zig") {
          // means, this file is the one
          // which will be the chosen as the main file
          // of the library.
          // means, it might have the //! thingy at the start.
          // hence, I will be using it for the main, top level documentation.
          std::ifstream file(entry.path(), std::ios::binary);

          if (!file) {
            std::cerr << "File that should exist, somehow doesn't exist: "
                      << entry.path() << std::endl;
            return 0;
          }

          std::string line;
          while (std::getline(file, line)) {
            if (line.compare(0, 3, "//!") == 0) {
              // the line is starting with //!
              if (line.length() >= 3) {
                top_level_documentation += line.substr(3) + '\n';
              }
            } else {
              // means, the line is no more starting with //!
              break;
            }
          }

          already_parsed_the_root_file_for_documentation = true;
        }
      }

      std::ifstream file(entry.path(), std::ios::binary);

      if (!file) {
        std::cerr << "File that should exist, somehow doesn't exist: "
                  << entry.path() << std::endl;
        return 0;
      }
      std::stringstream buffer;
      buffer << file.rdbuf();

      const char *result = parse(buffer.str().c_str());
      nlohmann::json as_json = nlohmann::json::parse(result);

      auto rel = std::filesystem::relative(entry.path(), input_folder);
      file_results[rel.string()] = as_json;
    }
  } catch (std::exception &e) {
    std::cerr << "Filesystem error: " << e.what() << '\n';
    return 1;
  }

  nlohmann::json final_results;
  nlohmann::json config;
  config["commit_hash"] = "";
  final_results["files"] = file_results;
  final_results["top_level_documentation"] = top_level_documentation;
  final_results["config"] = config;

  std::cout << final_results.dump() << std::endl;

  return 0;
}
