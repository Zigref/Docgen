CPP_COMPILER = clang++
CPP_FLAGS = -std=c++23 -Wall -Wextra -lbrotlienc

main: ./src/main.cpp ./src/root.zig
	mkdir -p ./build
	zig build-obj ./src/root.zig -lc -femit-bin=./build/parser.o
	$(CPP_COMPILER) $(CPP_FLAGS) ./src/main.cpp ./build/parser.o -o ./build/main

clean:
	rm -rf ./build
	rm -rf ./.zig-cache