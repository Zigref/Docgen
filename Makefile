CPP_COMPILER = clang++
CPP_FLAGS = -std=c++23 -Wall -Wextra -lbrotlienc -lcurl -lminiz -lsqlite3 -I./include/


main: ./src/main.cpp ./src/root.zig
	mkdir -p ./build
	zig build-obj ./src/root.zig -lc -femit-bin=./build/parser.o
	$(CPP_COMPILER) $(CPP_FLAGS) ./src/main.cpp ./src/process_repo.cpp ./build/parser.o -o ./build/main

init:
	mkdir -p ./include/miniz
	curl -fL https://github.com/richgel999/miniz/releases/download/3.1.2/miniz-3.1.2.zip -o /tmp/miniz.zip
	unzip -q /tmp/miniz.zip -d /tmp/miniz
	mv /tmp/miniz ./include/
	rm -rf /tmp/miniz /tmp/miniz.zip


clean:
	rm -rf ./build
	rm -rf ./.zig-cache