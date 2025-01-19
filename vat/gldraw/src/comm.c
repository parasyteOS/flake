#include "commn.h"

static int recv_fd(int sock)
{
	char nothing = '!';
	struct iovec nothing_ptr = { .iov_base = &nothing, .iov_len = 1 };

	struct {
		struct cmsghdr align;
		int fd[1];
	} ancillary_data_buffer;

	struct msghdr message_header = {
		.msg_name = NULL,
		.msg_namelen = 0,
		.msg_iov = &nothing_ptr,
		.msg_iovlen = 1,
		.msg_flags = 0,
		.msg_control = &ancillary_data_buffer,
		.msg_controllen = sizeof(struct cmsghdr) + sizeof(int)
	};

	struct cmsghdr* cmsg = CMSG_FIRSTHDR(&message_header);
	cmsg->cmsg_len = message_header.msg_controllen;
	cmsg->cmsg_level = SOL_SOCKET;
	cmsg->cmsg_type = SCM_RIGHTS;
	((int*) CMSG_DATA(cmsg))[0] = -1;

	if (recvmsg(sock, &message_header, 0) < 0) return -1;

	return ((int*) CMSG_DATA(cmsg))[0];
}

int read_full(int fd, void *buffer, size_t count) {
    int bytes_read = 0;
    int tried = 0;
    while (bytes_read < count) {
        ssize_t result = read(fd, (char *)buffer + bytes_read, count - bytes_read);
        tried++;
        if (result == 0) { // EOF
            return -1;
        }
        if (result < 0) {
            if (errno == EINTR) {
                if (tried >= 10) {
                    usleep(100000);
                    tried = 0;
                }
                continue; // Interrupted, try again
            }
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                if (bytes_read == 0) {
                    return 0;
                }
                if (tried >= 10) {
                    usleep(100000);
                    tried = 0;
                }
                continue;
            }
            return -1; // Error
        }
        bytes_read += result;
        tried = 0;
    }
    return bytes_read;
}

int read_int(int fd)
{
	int rc;
	READ_DATA(fd, rc);
	return rc;
}

int get_buffer(int fd, int width, int height)
{
	int msg = BUFFER_REQ;
	int rc;
	WRITE_DATA(fd, msg);
	WRITE_DATA(fd, width);
	WRITE_DATA(fd, height);
	READ_DATA(fd, rc);
	return rc;
}

int render(int fd)
{
	int msg = RENDER_REQ;
	int rc;
	WRITE_DATA(fd, msg);
	READ_DATA(fd, rc);
	return rc;
}

int response(int fd)
{
	int msg = SUCCESS_RESP;
	WRITE_DATA(fd, msg);
	return 0;
}

static int client_handshake(int fd)
{
	int msg = 'A';
	int rc;
	WRITE_DATA(fd, msg);

	READ_DATA(fd, rc);
	if (rc != 'C') {
		return -1;
	}

	msg = 'K';
	WRITE_DATA(fd, msg);

	return 0;
}

int create_socket(const char *path)
{
	int rc, fd;
	struct sockaddr_un socket_addr = {};

	fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (fd < 0) {
		perror("Create socket");
		return -1;
	}

	memset(&socket_addr, 0, sizeof(socket_addr));
	socket_addr.sun_family = AF_UNIX;
	strncpy(socket_addr.sun_path, path, sizeof(socket_addr.sun_path) - 1);

	rc = connect(fd, (struct sockaddr *)&socket_addr, sizeof(socket_addr));
	if (rc < 0) {
		perror("Connect to socket");
		return -1;
	}

	rc = client_handshake(fd);
	if (rc != 0) {
		printf("Handshake failed.\n");
		close(fd);
		return -1;
	}

	return fd;
}
