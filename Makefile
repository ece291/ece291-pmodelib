# Makefile to build library
#  By Peter Johnson, 1999-2000
#
# $Id: Makefile,v 1.11 2001/04/07 21:06:34 mu Exp $

# set some useful paths
OBJ = obj
LIB = lib291.a

LFLAGS =
ASMFLAGS = -f coff -iinclude/

VPATH = examples src

PROGRAMS = mousetst testint testnet tcpweb testsb

OBJS = lib_load.o vbeaf.o textmode.o gfxfiles.o filefunc.o socket.o \
       dpmi_int.o dpmi_mem.o int_wrap.o rmcbwrap.o netbios.o misc.o \
       dma.o sb16.o

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
	rm -f obj/*.o lib291.a list/*.lst

veryclean: clean
	rm -f examples/*.exe

mousetst: examples/mousetst.exe
testint: examples/testint.exe
testnet: examples/testnet.exe
tcpweb: examples/tcpweb.exe
testsb: examples/testsb.exe
