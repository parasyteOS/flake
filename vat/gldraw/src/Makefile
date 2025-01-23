.PHONY: all

CFLAGS = $(shell $(PKG_CONFIG) --cflags egl glesv2 drm) -I$(EVDI)/include
LDFLAGS = $(shell $(PKG_CONFIG) --libs egl glesv2 drm) -L$(EVDI)/lib -levdi

SRCS = $(shell find . -name '*.c')

OBJS = $(SRCS:%.c=%.o)

all: gldraw

gldraw: $(OBJS)
	$(CC) $(OBJS) -o $@ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

install: gldraw
	install -m0755 -D gldraw $(PREFIX)/bin/gldraw
