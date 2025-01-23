#include <evdi_lib.h>

struct display;
typedef struct display display;

#define DISPLAY_STATUS_INIT         0
#define DISPLAY_STATUS_MODE_SET     1
#define DISPLAY_STATUS_BUFFER_READY 2

#define DISPLAY_ERROR_NO_ERROR         0
#define DISPLAY_ERROR_BAD_CONNECTION   1
#define DISPLAY_ERROR_INTERNAL_FAILURE 2
