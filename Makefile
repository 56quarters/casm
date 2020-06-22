out := target
src := src
cc := gcc

default: build

clean:
	rm -rf $(out)

target:
	mkdir -p $(out)

$(out)/lib.o: $(src)/lib.S
	$(cc) -o $(out)/lib.o -c $(src)/lib.S

$(out)/cat: $(out)/lib.o $(src)/cat.S
	$(cc) -o $(out)/cat.o -c $(src)/cat.S
	ld -o $(out)/cat $(out)/lib.o $(out)/cat.o

$(out)/echo: $(out)/lib.o $(src)/echo.S
	$(cc) -o $(out)/echo.o -c $(src)/echo.S
	ld -o $(out)/echo $(out)/lib.o $(out)/echo.o

$(out)/false: $(out)/lib.o $(src)/false.S
	$(cc) -o $(out)/false.o -c $(src)/false.S
	ld -o $(out)/false $(out)/lib.o $(out)/false.o

$(out)/true: $(out)/lib.o $(src)/true.S
	$(cc) -o $(out)/true.o -c $(src)/true.S
	ld -o $(out)/true $(out)/lib.o $(out)/true.o

build: target $(out)/cat $(out)/echo $(out)/false $(out)/true
