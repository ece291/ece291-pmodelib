# Makefile to build library
#  By Peter Johnson, 1999-2000
#
# $Id: Makefile,v 1.17 2001/10/17 20:54:50 pete Exp $

# set some useful paths
OBJ = obj
LIB = lib291.a

LFLAGS =
ASMFLAGS = -f coff -iinclude/
CFLAGS = -I$(EXTLIBS)/lpng108 -I$(EXTLIBS)/zlib -I$(EXTLIBS)/jpeg-6b

VPATH = examples src src_c

PROGRAMS_BASE = mousetst testint testnet tcpweb tcpcli tcpsrv udpcli udpsrv \
	testsb testsb16

PROGRAMS = $(addsuffix .exe, $(addprefix examples/, $(PROGRAMS_BASE)))

OBJS = lib_load.o vbeaf.o textmode.o gfxfiles.o filefunc.o socket.o \
       dpmi_int.o dpmi_mem.o int_wrap.o rmcbwrap.o netbios.o misc.o \
       dma.o sb16.o

COBJS = readpng.o readjpg.o

LIBOBJS = $(EXTLIBS)/lpng108/libpng.a \
          $(EXTLIBS)/zlib/libz.a \
          $(EXTLIBS)/jpeg-6b/libjpeg.a

LIB_OBJS = $(addprefix $(OBJ)/, $(OBJS)) $(addprefix $(OBJ)/, $(COBJS)) \
           $(LIBOBJS)

.PRECIOUS: $(OBJ)/%.o

.PHONY: all msg libobjs lib clean veryclean

all: $(LIB) $(PROGRAMS)
	@echo All done.

libobjs: $(LIB_OBJS)

lib: $(LIB)

$(OBJ)/%.o: %.asm
	nasm $(ASMFLAGS) -o $@ $< -l list/$*.lst

$(OBJ)/%.o: %.c
	gcc -c $(CFLAGS) -o $@ $<

*/%.exe: $(OBJ)/%.o $(LIB)
	gcc $(LFLAGS) -o $@ $< $(LIB)

$(LIB)(%): %
	ar cr $(LIB) $<

$(LIB): $(LIB)($(LIB_OBJS))
	ranlib $(LIB)

clean:
	rm -f obj/*.o lib291.a list/*.lst

veryclean: clean
	rm -f examples/*.exe

