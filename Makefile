# Makefile to build library
#  By Peter Johnson, 1999-2000
#
# $Id: Makefile,v 1.19 2001/12/12 07:12:09 pete Exp $

# set some useful paths
OBJ = obj
LIB = lib291.a
TMPLIB = lib291t.a

LFLAGS =
ASMFLAGS = -f coff -iinclude/
CFLAGS = -I$(EXTLIBS)/lpng -I$(EXTLIBS)/zlib -I$(EXTLIBS)/jpeg-6b

VPATH = examples src src_c

PROGRAMS_BASE = mousetst testint testnet tcpweb tcpcli tcpsrv udpcli udpsrv \
	testsb testsb16

PROGRAMS = $(addsuffix .exe, $(addprefix examples/, $(PROGRAMS_BASE)))

OBJS = lib_load.o vbeaf.o textmode.o gfxfiles.o filefunc.o socket.o \
       dpmi_int.o dpmi_mem.o int_wrap.o rmcbwrap.o netbios.o misc.o \
       dma.o sb16.o loadpng.o jpg.o

COBJS = readpng.o readjpg.o

EXTLIBOBJS = $(EXTLIBS)/lpng/libpng.a \
             $(EXTLIBS)/zlib/libz.a \
             $(EXTLIBS)/jpeg-6b/libjpeg.a

LIBOBJS = $(addprefix $(OBJ)/, $(OBJS)) $(addprefix $(OBJ)/, $(COBJS))

.PRECIOUS: $(OBJ)/%.o

.PHONY: all msg libobjs lib clean veryclean

all: lib $(PROGRAMS)
	@echo All done.

arscript: $(TMPLIB) $(EXTLIBOBJS)
	@echo "CREATE $(LIB)" >$@
	@echo "ADDLIB $(TMPLIB)" >>$@
	@echo "ADDLIB $(EXTLIBS)/lpng/libpng.a" >>$@
	@echo "ADDLIB $(EXTLIBS)/zlib/libz.a" >>$@
	@echo "ADDLIB $(EXTLIBS)/jpeg-6b/libjpeg.a" >>$@
	@echo "SAVE" >>$@

$(LIB): arscript
	ar -M <arscript
	-del arscript
	-del $(TMPLIB)

lib: $(LIB)
	ranlib $(LIB)

$(OBJ)/%.o: %.asm
	nasm $(ASMFLAGS) -o $@ $< -l list/$*.lst

$(OBJ)/%.o: %.c
	gcc -c $(CFLAGS) -o $@ $<

*/%.exe: $(OBJ)/%.o $(LIB)
	gcc $(LFLAGS) -o $@ $< $(LIB)

$(TMPLIB)(%): %
	ar cr $(TMPLIB) $<

$(TMPLIB): $(TMPLIB)($(LIBOBJS))

clean:
	-del obj\*.o
	-del lib291.a
	-del list\*.lst
	-del lib291t.a
	-del arscript

veryclean: clean
	-del examples\*.exe

