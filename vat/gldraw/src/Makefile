.PHONY: all

CFLAGS = $(shell $(PKG_CONFIG) --cflags egl glesv2)
LDFLAGS = $(shell $(PKG_CONFIG) --libs egl glesv2)

SRCS = $(shell find . -name '*.c')

OBJS = $(SRCS:%.c=%.o)

all: gldraw

gldraw: $(OBJS)
	$(CC) $(OBJS) -o $@ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

install: gldraw
	install -m0755 -D gldraw $(PREFIX)/bin/gldraw
