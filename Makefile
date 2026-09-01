CPP_COMPILER = g++
CPP_FLAGS = -std=c++23 -Wall -Wextra -I./include/
LIBS = -lbrotlienc -lcurl -lsqlite3

main: ./src/main.cpp ./src/root.zig
	mkdir -p ./build
	zig build-obj ./src/root.zig -lc -femit-bin=./build/parser.o
	$(CPP_COMPILER) $(CPP_FLAGS) ./src/main.cpp ./src/process_repo.cpp ./include/miniz/miniz.c ./build/parser.o $(LIBS) -o ./build/main

init:
	mkdir -p ./include/miniz
	curl -fL https://github.com/richgel999/miniz/releases/download/3.1.2/miniz-3.1.2.zip -o /tmp/miniz.zip
	unzip -q /tmp/miniz.zip -d /tmp/miniz
	mv /tmp/miniz ./include/
	rm -rf /tmp/miniz /tmp/miniz.zip
	curl -fL https://github.com/nlohmann/json/releases/download/v3.12.0/json.hpp -o ./include/json.hpp
	curl -fL https://github.com/taskflow/taskflow/archive/refs/tags/v4.1.0.zip -o /tmp/taskflow.zip
	unzip -q /tmp/taskflow.zip -d /tmp/taskflow
	mv /tmp/taskflow/taskflow-4.1.0/taskflow ./include/taskflow
	rm -rf /tmp/taskflow /tmp/taskflow.zip

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