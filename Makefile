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
	curl -fL https://github.com/nlohmann/json/releases/download/v3.12.0/json.hpp -o ./include/json.hpp
	unzip -q /tmp/miniz.zip -d /tmp/miniz
	mv /tmp/miniz ./include/
	rm -rf /tmp/miniz /tmp/miniz.zip

clean:
	rm -rf ./build
	rm -rf ./.zig-cache