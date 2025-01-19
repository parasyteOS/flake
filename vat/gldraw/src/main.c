#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <limits.h>

#include <evdi_lib.h>

#include "comm.h"
#include "ashmem.h"

#define CANVAS_SOCKET_PATH "/run/outerspace/canvas.socket"
#define EVENTS_SOCKET_PATH "/run/outerspace/events.socket"

// Requests from client
#define BUFFER_REQ 0
#define RENDER_REQ 1

// Response to client
#define SUCCESS_RESP 0
#define FAILED_RESP (-1)

static int ashmem_get_size_region(int fd)
{
  	int rc;
	do {
		rc = ioctl(fd, ASHMEM_GET_SIZE, NULL);
	} while (rc == -1 && errno == EINTR);
	return rc;
}

int renderThread(int canvas_server, int events_server, unsigned char* edid, size_t edid_size)
{
  	int rc;

	evdi_handle handle;

	int cmd = 0;
	int width = 0;
	int height = 0;
	int stride = 0;
	int shm_fd = -1, shm_size;
	void *shm = NULL;

	printf("Trying to connect to evdi...\n");
	handle = evdi_open_attached_to_fixed(NULL, 0);
	if (handle == EVDI_INVALID_HANDLE) {
		printf("Failed to open evdi.\n");
		return -1;
	}
	evdi_connect(handle, edid, edid_size, INT_MAX);

	printf("Trying to get buffer...\n");
	rc = get_buffer(canvas_server);
	if (rc != SUCCESS_RESP) {
		continue;
	}
	width = read_int(canvas_server);
	if (width <= 0) {
		printf("Failed to read width.\n");
		goto cleanup;
	}
	height = read_int(canvas_server);
	if (height <= 0) {
		printf("Failed to read height.\n");
		goto cleanup;
	}
	stride = read_int(canvas_server);
	if (stride <= 0) {
		printf("Failed to read stride.\n");
		goto cleanup;
	}
	shm_fd = recv_fd(canvas_server);
	if (shm_fd < 0) {
		printf("Failed to receive shm fd.\n");
		goto cleanup;
	}
	shm_size = ashmem_get_size_region(shm_fd);
	shm = mmap(NULL, shm_size, PROT_READ|PROT_WRITE, MAP_SHARED, shm_fd, 0);
	if (shm == MAP_FAILED) {
		printf("Client failed to map shm.\n");
		goto cleanup;
	}

	while (true) {
		rc = read(events_server, &cmd, sizeof(cmd));
		if (rc == 0) goto cleanup;
		if (rc < 0 && errno != EAGAIN && errno != EWOULDBLOCK) goto cleanup;

		// No events, render
		if (rc < 0) {
		  	if (!ready) {
				ready = 1;
			}

            		rc = render(canvas_server);

            		if (rc < 0) {
            		    printf("Failed to render.\n");
                    	    usleep(100000);
			    continue;
            		}

			// if (rc > 0) {
			//     DESTROY;
			// }
		}
		// Handle events
		else {
		  	if (rc < sizeof(cmd)) {
				rc = read_full(events_server, (char *)&cmd + rc, sizeof(cmd) - rc);
				if (rc < 0) {
					printf("Failed to read full cmd.\n");
					goto cleanup;
				}
		  	}
			cmd = ntohl(cmd);
			printf("Unknown cmd: %d\n", cmd);
			rc = response(events_server);
			if (rc != 0) goto cleanup;
		}
	}

cleanup:
	printf("Cleanup.\n");
	return -1;
}

static unsigned char* read_edid(const char* filename, size_t *edid_size)
{
	long file_size;
	size_t read_size;
	FILE *file = fopen(filename, "rb");
	if (!file) {
		perror("Failed to open file");
		return NULL;
	}

	fseek(file, 0, SEEK_END);
	file_size = ftell(file);
	fseek(file, 0, SEEK_SET);
	*edid_size = file_size;

	unsigned char* buffer = (unsigned char*) malloc(file_size);
	if (!buffer) {
		perror("Failed to allocate memory");
		fclose(file);
		return NULL;
	}

	read_size = fread(buffer, 1, file_size, file);
	if (read_size != file_size) {
		printf("Failed to read all file content.\n");
		free(buffer);
		fclose(file);
		return NULL;
	}

	fclose(file);
	return buffer;
}

int main(int argc, char* argv[])
{
  	int rc = -1;
	unsigned char* edid = NULL;
	size_t edid_size;
	int canvas_server, events_server;

	if (argc < 2) {
		printf("expect a edid file.\n");
		goto close;
	}

	edid = read_edid(argv[1], &edid_size);
	if (edid == NULL) {
		printf("Failed to read edid file.\n");
		goto close;
	}

	canvas_server = create_socket(CANVAS_SOCKET_PATH);
	if (canvas_server < 0) {
		printf("Failed to connect to canvas.\n");
		goto close;
	}

	events_server = create_socket(EVENTS_SOCKET_PATH);
	if (events_server < 0) {
		printf("Failed to connect to events.\n");
		goto close;
	}

    	fcntl(events_server, F_SETFL, fcntl(events_server, F_GETFL, 0) | O_NONBLOCK);

	rc = renderThread(canvas_server, events_server, edid, edid_size);
close:
	if (edid != NULL) free(edid);
	if (canvas_server > 0) close(canvas_server);
	if (events_server > 0) close(events_server);
	return rc;
}
