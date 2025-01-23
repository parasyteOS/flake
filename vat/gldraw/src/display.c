#include <limits.h>
#include <sys/mman.h>
#include "display.h"

typedef struct {
	int fd;
	int size;
	void *data;
	evdi_buffer buffer;
} shm;

struct display {
	evdi_handle handle;
	evdi_event_context ctx;
	int canvas_server_fd;

	int width;
	int height;
	int refresh_rate;
	int pixel_format;

	int stride;
	shm shm;

	int status;
	int error;
};

static void dpms_handler(int dpms_mode, void *user_data);
static void mode_changed_handler(struct evdi_mode mode, void *user_data);
static void update_ready_handler(int buffer_to_be_updated, void *user_data);
static void crtc_state_handler(int state, void *user_data);
static void cursor_set_handler(struct evdi_cursor_set cursor_set, void *user_data);
static void cursor_move_handler(struct evdi_cursor_move cursor_move, void *user_data);
static void ddcci_data_handler(struct evdi_ddcci_data ddcci_data, void *user_data);

void display_init(display *d, int canvas_server_fd)
{
	d->handle = evdi_open_attach_to_fixed(NULL, 0);
	d->canvas_server_fd = canvas_server_fd;
	d->mode_set = 0;
	d->status = DISPLAY_STATUS_INIT;
	d->error = DISPLAY_ERROR_NO_ERROR;
}

void display_connect(display *d, const unsigned char *edid, unsigned int edid_length)
{
	evdi_connect(d->handle, edid, edid_length, INT_MAX);
	d->ctx.dpms_handler = dpms_handler;
	d->ctx.mode_changed_handler = mode_changed_handler;
	d->ctx.update_ready_handler = update_ready_handler;
	d->ctx.crtc_state_handler = crtc_state_handler;
	d->ctx.cursor_set_handler = cursor_set_handler;
	d->ctx.cursor_move_handler = cursor_move_handler;
	d->ctx.ddcci_data_handler = ddcci_data_handler;
	d->ctx.user_data = d;
}

int display_event_source(display *d)
{
	return evdi_get_event_ready(d->handle);
}

void display_handle_events(display *d)
{
	evdi_handle_events(d->handle, &d->ctx);
}

int display_get_error(display *d)
{
	return d->error;
}

int display_refresh_rate(display *d)
{
	if (d->status < DISPLAY_STATUS_MODE_SET) {
  		return -1;
  	}
	return d->refresh_rate;
}

void display_disconnect(display *d)
{
	evdi_disconnect(d->handle);
}

static void dpms_handler(int dpms_mode, void *user_data)
{
	printf("DPMS mode: %d\n", dpms_mode);
}

static int ashmem_get_size_region(int fd)
{
  	int rc;
	do {
		rc = ioctl(fd, ASHMEM_GET_SIZE, NULL);
	} while (rc == -1 && errno == EINTR);
	return rc;
}

static void setup_buffer(display *d)
{
	int rc = get_buffer(d->canvas_server_fd, d->width, d->height);
	if (rc) {
		printf("Failed to get buffer.\n");
		display->error = DISPLAY_ERROR_BAD_CONNECTION;
		return;
	}

	d->stride = read_int(canvas_server_fd);
	if (d->stride <= 0) {
		printf("Failed to read stride from canvas.\n");
		display->error = DISPLAY_ERROR_BAD_CONNECTION;
		return;
	}

	d->shm.fd = recv_fd(canvas_server_fd);
	if (d->shm.fd < 0) {
		printf("Failed to receive shm fd.\n");
		display->error = DISPLAY_ERROR_BAD_CONNECTION;
		return;
	}

	d->shm.size = ashmem_get_size_region(d->shm.fd);
	if (d->shm.size < 0) {
		printf("Failed to get shm size.\n");
		display->error = DISPLAY_ERROR_INTERNAL_FAILURE;
		return;
	}

	d->shm.data = mmap(NULL, shm_size, PROT_READ|PROT_WRITE, MAP_SHARED, shm_fd, 0);
	if (d->shm.data == MAP_FAILED) {
		printf("Failed to mmap shm.\n");
		display->error = DISPLAY_ERROR_INTERNAL_FAILURE;
		return;
	}

	d->shm.buffer.id = 0;
	d->shm.buffer.width = d->width;
	d->shm.buffer.height = d->height;
	d->shm.buffer.stride = d->stride;
	d->shm.buffer.buffer = d.shm.data;
	evdi_register_buffer(d->handle, d->shm.buffer);

	display->status = DISPLAY_STATUS_BUFFER_READY;
}

static void mode_changed_handler(struct evdi_mode mode, void *user_data) {
	printf("Mode changed: width: %d, height: %d, refresh rate: %d, bits per pixel: %d, pixel format: %d\n",
		mode.width, mode.height, mode.refresh_rate, mode.bits_per_pixel, mode.pixel_format);

	display *d = (display *)user_data;
	d->width = mode.width;
	d->height = mode.height;
	d->refresh_rate = mode.refresh_rate;
	d->pixel_format = mode.pixel_format;
	d->status = DISPLAY_STATUS_MODE_SET;
	setup_buffer(d);
}

static void update_ready_handler(int buffer_to_be_updated, void *user_data);

static void crtc_state_handler(int state, void *user_data) {
	printf("CRTC state: %d\n", state);
}
static void cursor_set_handler(struct evdi_cursor_set cursor_set, void *user_data)
{
	printf("Cursor enabled: %d, hot [x,y]: %d, %d\n", cursor_set.enabled, cursor_set.hot_x, cursor_set.hot_y);
}
static void cursor_move_handler(struct evdi_cursor_move cursor_move, void *user_data)
{
	printf("Cursor move: %d, %d\n", cursor_move.x, cursor_move.y);
}
static void ddcci_data_handler(struct evdi_ddcci_data ddcci_data, void *user_data)
{
	printf("DDCCI data.\n");
}
