CPP_COMPILER = g++
CPP_FLAGS = -std=c++23 -Wall -Wextra -I./include/ 
LIBS = $(shell pkg-config --libs --cflags libbrotlienc sqlite3 libcurl)
C_COMPILER = clang

main: ./src/main.cpp ./src/root.zig
	mkdir -p ./build
	zig build-obj ./src/root.zig -lc -femit-bin=./build/parser.o
	$(C_COMPILER) $(C_FLAGS) -c ./include/miniz/miniz.c -o ./build/miniz.o
	$(CPP_COMPILER) $(CPP_FLAGS) ./src/main.cpp ./src/process_repo.cpp ./build/miniz.o ./build/parser.o $(LIBS) -o ./build/main

init:
	# ---------- Reset folders --------------#
	rm -rf /tmp/zigref_work/
	mkdir -p /tmp/zigref_work/
	rm -rf ./include/
	mkdir -p ./include/
	#----------------------------------------

	# ----------- Miniz ------------- #
	mkdir -p ./include/miniz
	curl -fL --retry-all-errors "https://github.com/richgel999/miniz/releases/download/3.1.2/miniz-3.1.2.zip" -o /tmp/zigref_work/miniz.zip
	unzip -q /tmp/zigref_work/miniz.zip -d /tmp/zigref_work/miniz
	mv /tmp/zigref_work/miniz ./include/
	rm -rf /tmp/zigref_work/miniz /tmp/zigref_work/miniz.zip
	# ------------------------------- #

	# ----------- Json HPP ------------- #
	curl -fL https://github.com/nlohmann/json/releases/download/v3.12.0/json.hpp -o ./include/json.hpp
	# ---------------------------------- #

	# ----------- Taskflow ------------- #
	curl -fL https://github.com/taskflow/taskflow/archive/refs/tags/v4.1.0.zip -o /tmp/zigref_work/taskflow.zip
	unzip -q /tmp/zigref_work/taskflow.zip -d /tmp/zigref_work/taskflow
	mv /tmp/zigref_work/taskflow/taskflow-4.1.0/taskflow/ ./include/taskflow
	rm -rf /tmp/zigref_work/taskflow /tmp/zigref_work/taskflow.zip
	# ---------------------------------- #


download_database:
	curl -fL "https://huggingface.co/buckets/Zigistry/Zigistry/resolve/zigistry.db" -o ./zigistry.db
	

clean:
	rm -rf ./build
	rm -rf ./.zig-cache

reset:
	rm -rf ./include	
	rm -rf ./build
	rm -rf ./.zig-cache
	rm zigistry.db zigistry.db-shm zigistry.db-wal

format:
	clang-format -i ./src/*.cpp --style=webkit
	clang-format -i ./src/*.h --style=webkit
	cd template && npm run format

.PHONY: run

run: main
	./build/main