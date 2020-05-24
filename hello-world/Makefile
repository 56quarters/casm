out := target

default: build

clean:
	rm -r $(out)

target:
	mkdir -p $(out)

$(out)/hw.o: hw.S target
	gcc -o $(out)/hw.o -c hw.S

$(out)/hw: $(out)/hw.o
	ld -o $(out)/hw $(out)/hw.o

build: $(out)/hw
