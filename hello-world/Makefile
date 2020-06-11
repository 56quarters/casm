out := target
arch := x86-64
linker := /lib/ld-linux-$(arch).so.2

default: build

clean:
	rm -rf $(out)

target:
	mkdir -p $(out)

$(out)/hw.o: hw.S target
	gcc -ggdb -o $(out)/hw.o -c hw.S

$(out)/hw: $(out)/hw.o
	ld --dynamic-linker $(linker) -lc -o $(out)/hw $(out)/hw.o

build: $(out)/hw

run: build
	-./$(out)/hw

strace: build
	-strace ./$(out)/hw
