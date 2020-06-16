out := target
src := src

default: build

clean:
	rm -rf $(out)

target:
	mkdir -p $(out)

$(out)/cat: $(src)/cat.S target
	gcc -ggdb -o $(out)/cat.o -c $(src)/cat.S
	ld -o $(out)/cat $(out)/cat.o

build: $(out)/cat
