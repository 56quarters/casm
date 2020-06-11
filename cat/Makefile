out := target
arch := x86-64
linker := /lib/ld-linux-$(arch).so.2

default: build

clean:
	rm -rf $(out)

target:
	mkdir -p $(out)

$(out)/cat.o: cat.S target
	gcc -ggdb -o $(out)/cat.o -c cat.S

$(out)/cat: $(out)/cat.o
#	ld --dynamic-linker $(linker) -lc -o $(out)/cat $(out)/cat.o
	ld -o $(out)/cat $(out)/cat.o

build: $(out)/cat

run: build
	-./$(out)/cat

strace: build
	-strace ./$(out)/cat
