# set some useful paths
OBJ = obj
LIB = lib291.a

LFLAGS =
ASMFLAGS = -f coff -iinclude/

VPATH = examples src

PROGRAMS = mousetst testint

OBJS = myloader.o vesa.o textmode.o gfxfiles.o filefunc.o dpmi_int.o \
       dpmi_mem.o int_hand.o cb_hand.o dma.o

LIB_OBJS = $(addprefix $(OBJ)/, $(OBJS))

.PRECIOUS: $(OBJ)/%.o

.PHONY: all msg lib clean veryclean $(PROGRAMS)

all: msg $(LIB) $(PROGRAMS)
	@echo All done.

msg:
	@echo Compiling. Please wait...

lib: $(LIB)

$(OBJ)/%.o: %.asm
	nasm $(ASMFLAGS) -o $@ $< -l list/$*.lst

*/%.exe: $(OBJ)/%.o $(LIB)
	gcc $(LFLAGS) -o $@ $< $(LIB)

$(LIB): $(LIB_OBJS)
	ar rs $(LIB) $(LIB_OBJS)

clean:
	rm -f obj/*.* lib291.a list/*.*

veryclean: clean
	rm -f examples/*.exe

mousetst: examples/mousetst.exe
testint: examples/testint.exe
