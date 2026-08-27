#include <miniz/miniz.h>
#include <cstdio>
#include <cstdlib>

int main() {
    mz_zip_archive zip_archive_main_struct{};

    mz_zip_reader_init_file(&zip_archive_main_struct, "test.zip", 0);

    for (mz_uint i = 0; i < mz_zip_reader_get_num_files(&zip_archive_main_struct); i++) {
        char filename[256];

        mz_zip_reader_get_filename(&zip_archive_main_struct, i, filename, sizeof(filename));

        printf("\n\n|||||||||||||||||||%s|||||||||||||||||||||\n\n", filename);

        size_t size_of_data;
        void* data = mz_zip_reader_extract_to_heap(&zip_archive_main_struct, i, &size_of_data, 0);

        if (data) {
            fwrite(data, 1, size_of_data, stdout);
            putchar('\n');
            free(data);
        }
    }

    mz_zip_reader_end(&zip_archive_main_struct);
    return 0;
}
