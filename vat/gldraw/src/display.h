#include <evdi_lib.h>

typedef struct {
	int fd;
	int size;
	void *data;
} shm;

typedef struct {
	evdi_handle handle;
	int canvas_server_fd;
	int width;
	int height;
	int stride;
	shm shm;
} display;
