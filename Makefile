CPP_COMPILER = clang++
CPP_FLAGS = -std=c++23 -Wall -Wextra

main: ./src/main.cpp ./src/parser.zig
	zig build-obj ./src/parser.zig -lc -femit-bin=./build/parser.o
	$(CPP_COMPILER) $(CPP_FLAGS) ./src/main.cpp ./build/parser.o -o ./build/main
