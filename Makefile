out := target

default: build

clean:
	rm -rf $(out)

target:
	mkdir -p $(out)

$(out)/cat.o: cat.S target
	gcc -Wall -pedantic -ggdb -o $(out)/cat.o -c cat.S

$(out)/cat: $(out)/cat.o
	ld -o $(out)/cat $(out)/cat.o

build: $(out)/cat

run: build
	-./$(out)/cat

strace: build
	-strace ./$(out)/cat
