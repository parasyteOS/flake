#include <errno.h>
#include <unistd.h>
#include <sys/un.h>
#include <arpa/inet.h>

int recv_fd(int sock);
int read_full(int fd, void *buffer, size_t count);
int create_socket(const char *path);
int read_int(int fd);
int response(int fd);
int get_buffer(int fd, int width, int height);
int render(int fd);

#define WRITE_DATA(fd, data) \
        do { \
                int _data = htonl(data); \
                if (write(fd, &_data, sizeof(_data)) == -1) { \
                        printf("Line %d: Failed to write data.\n", __LINE__); \
                        perror("Error"); \
                        return -1; \
                } \
        } while (0)

#define READ_DATA(fd, data) \
        do { \
                if (read_full(fd, &data, sizeof(data)) == -1) { \
                        printf("Line %d: Failed to read data.\n", __LINE__); \
                        perror("Error"); \
                        return -1; \
                } \
                data = ntohl(data); \
        } while (0)

