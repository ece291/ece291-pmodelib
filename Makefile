# Makefile to build library
#  By Peter Johnson, 1999-2000
#
# $Id: Makefile,v 1.15 2001/04/17 23:51:47 pete Exp $

# set some useful paths
OBJ = obj
LIB = lib291.a

LFLAGS =
ASMFLAGS = -f coff -iinclude/

VPATH = examples src

PROGRAMS_BASE = mousetst testint testnet tcpweb tcpcli tcpsrv udpcli udpsrv \
	testsb

PROGRAMS = $(addsuffix .exe, $(addprefix examples/, $(PROGRAMS_BASE)))

OBJS = lib_load.o vbeaf.o textmode.o gfxfiles.o filefunc.o socket.o \
       dpmi_int.o dpmi_mem.o int_wrap.o rmcbwrap.o netbios.o misc.o \
       dma.o sb16.o

LIB_OBJS = $(addprefix $(OBJ)/, $(OBJS))

.PRECIOUS: $(OBJ)/%.o

.PHONY: all msg libobjs lib clean veryclean

all: $(LIB) $(PROGRAMS)
	@echo All done.

libobjs: $(LIB_OBJS)

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

