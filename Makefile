out := target
src := src
libs := $(out)/libio.o $(out)/libstr.o
cc := gcc -ggdb
ld := ld

default: debug

clean:
	rm -rf $(out)

target:
	mkdir -p $(out)

$(out)/libio.o: $(src)/libio.S
	$(cc) -o $(out)/libio.o -c $(src)/libio.S

$(out)/libstr.o: $(src)/libstr.S
	$(cc) -o $(out)/libstr.o -c $(src)/libstr.S

$(out)/base64: $(libs) $(src)/base64.S
	$(cc) -o $(out)/base64.o -c $(src)/base64.S
	$(ld) -o $(out)/base64 $(libs) $(out)/base64.o

$(out)/cat: $(libs) $(src)/cat.S
	$(cc) -o $(out)/cat.o -c $(src)/cat.S
	$(ld) -o $(out)/cat $(libs) $(out)/cat.o

$(out)/echo: $(libs) $(src)/echo.S
	$(cc) -o $(out)/echo.o -c $(src)/echo.S
	$(ld) -o $(out)/echo $(libs) $(out)/echo.o

$(out)/false: $(libs) $(src)/false.S
	$(cc) -o $(out)/false.o -c $(src)/false.S
	$(ld) -o $(out)/false $(libs) $(out)/false.o

$(out)/pwd: $(libs) $(src)/pwd.S
	$(cc) -o $(out)/pwd.o -c $(src)/pwd.S
	$(ld) -o $(out)/pwd $(libs) $(out)/pwd.o

$(out)/sleep: $(libs) $(src)/sleep.S
	$(cc) -o $(out)/sleep.o -c $(src)/sleep.S
	$(ld) -o $(out)/sleep $(libs) $(out)/sleep.o

$(out)/sync: $(libs) $(src)/sync.S
	$(cc) -o $(out)/sync.o -c $(src)/sync.S
	$(ld) -o $(out)/sync $(libs) $(out)/sync.o

$(out)/touch: $(libs) $(src)/touch.S
	$(cc) -o $(out)/touch.o -c $(src)/touch.S
	$(ld) -o $(out)/touch $(libs) $(out)/touch.o

$(out)/true: $(libs) $(src)/true.S
	$(cc) -o $(out)/true.o -c $(src)/true.S
	$(ld) -o $(out)/true $(libs) $(out)/true.o

$(out)/yes: $(libs) $(src)/yes.S
	$(cc) -o $(out)/yes.o -c $(src)/yes.S
	$(ld) -o $(out)/yes $(libs) $(out)/yes.o

build: target $(out)/base64 $(out)/cat $(out)/echo $(out)/false $(out)/pwd $(out)/sleep $(out)/sync \
	$(out)/touch $(out)/true $(out)/yes

debug: build

release: cc = gcc -Os
release: build
