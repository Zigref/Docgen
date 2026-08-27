CPP_COMPILER = clang++
CPP_FLAGS = -std=c++23 -Wall -Wextra -lbrotlienc -I./include/


main: ./src/main.cpp ./src/root.zig
	mkdir -p ./build
	zig build-obj ./src/root.zig -lc -femit-bin=./build/parser.o
	$(CPP_COMPILER) $(CPP_FLAGS) ./src/main.cpp ./build/parser.o -o ./build/main

init:
	mkdir -p ./include/miniz-3.1.2
	curl -L https://github.com/richgel999/miniz/releases/download/3.1.2/miniz-3.1.2.zip -o /tmp/miniz.zip
	unzip /tmp/miniz.zip -d ./include/miniz-3.1.2


clean:
	rm -rf ./build
	rm -rf ./.zig-cache