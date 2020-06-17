out := target
src := src

default: build

clean:
	rm -rf $(out)

target:
	mkdir -p $(out)

$(out)/lib.o: $(src)/lib.S
	gcc -ggdb -o $(out)/lib.o -c $(src)/lib.S

$(out)/cat: $(out)/lib.o $(src)/cat.S
	gcc -ggdb -o $(out)/cat.o -c $(src)/cat.S
	ld -o $(out)/cat $(out)/lib.o $(out)/cat.o

$(out)/echo: $(out)/lib.o $(src)/echo.S
	gcc -ggdb -o $(out)/echo.o -c $(src)/echo.S
	ld -o $(out)/echo $(out)/lib.o $(out)/echo.o

build: target $(out)/cat $(out)/echo
