#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <time.h>
#include <fcntl.h>
#include <arpa/inet.h>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

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

static int read_full(int fd, void *buffer, size_t count) {
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

static int read_int(int fd)
{
	int rc;
	READ_DATA(fd, rc);
	return rc;
}

static int get_buffer(int fd)
{
	int msg = BUFFER_REQ;
	int rc;
	WRITE_DATA(fd, msg);
	READ_DATA(fd, rc);
	return rc;
}

static int render(int fd)
{
	int msg = RENDER_REQ;
	int rc;
	WRITE_DATA(fd, msg);
	READ_DATA(fd, rc);
	return rc;
}

static int response(int fd)
{
	int msg = SUCCESS_RESP;
	WRITE_DATA(fd, msg);
	return 0;
}

// convenience function to exit when an gles error is encountered
static bool checkGLError(const char* function) {
    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        printf("%s: 0x%x\n", function, err);
        return false;
    }
    return true;
}

// creates a shader of a specific type from source, to not duplicate the code for both the
// vertex and fragment shader
static GLuint createShader(GLenum type, const char* source) {
    GLuint shader = glCreateShader(type);
    checkGLError("glCreateShader");
    glShaderSource(shader, 1, &source, NULL);
    checkGLError("glShaderSource");
    glCompileShader(shader);
    checkGLError("glCompileShader");
    GLint compiled = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    checkGLError("glGetShaderiv");
    if (compiled != GL_TRUE) {
        GLint len;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &len);
        checkGLError("glGetShaderiv");
        char* log = (char *)calloc(len, 1);
        glGetShaderInfoLog(shader, len, NULL, log);
        checkGLError("glGetShaderInfoLog");
        printf("Shader compilation error:\nshader source:\n%s\nCompilation log:\n%s\n", source, log);
        return GL_FALSE;
    }
    return shader;
}

#define CHECK_GL_ERROR(function) if (!checkGLError(function)) goto cleanup

int renderProcess(int canvas_server, int events_server)
{
  	int rc;
	printf("Start render process.\n");

        // initialize EGL
        EGLDisplay d = eglGetDisplay(EGL_DEFAULT_DISPLAY);
        if (d == EGL_NO_DISPLAY) {
            printf("No egl display\n");
            goto cleanup;
        }

        EGLint major, minor;
        if (!eglInitialize(d, &major, &minor)) {
            printf("eglInitialize: 0x%x\n", eglGetError());
            goto cleanup;
        }
        // check for requirements
        if (major != 1 || minor < 2) {
            printf("Too old EGL version: %d.%d\n", major, minor);
            goto cleanup;
        }

        // choose a matching config
        const EGLint configAttribs[] = {
                EGL_RED_SIZE, 8,
                EGL_GREEN_SIZE, 8,
                EGL_BLUE_SIZE, 8,
                EGL_COLOR_BUFFER_TYPE, EGL_RGB_BUFFER,
                EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
                EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
                EGL_NONE
        };
        EGLConfig config;
        EGLint configSize;

        if (!eglChooseConfig(d, configAttribs, &config, 1, &configSize)) {
            printf("eglChooseConfig: 0x%x\n", eglGetError());
            goto cleanup;
        }
        if (configSize == 0) {
            printf("no matching EGL config found\n");
            goto cleanup;
        }

        // create an GLES2 context
        if (! eglBindAPI(EGL_OPENGL_ES_API)) {
            printf("eglBindAPI: 0x%x\n", eglGetError());
            goto cleanup;
        }

        const EGLint contextAttribs[] = {
                EGL_CONTEXT_MAJOR_VERSION, 2,
                EGL_NONE
        };
        EGLContext gles2 = eglCreateContext(d, config, NULL, contextAttribs);
        if (gles2 == EGL_NO_CONTEXT) {
            printf("eglCreateContext: 0x%x\n", eglGetError());
            goto cleanup;
        }

	// =======================================================================
	// Main loop
	printf("Start main loop.\n");

	int cmd = 0;
	int ready = 0;
	int width = 0;
	int height = 0;
	int shm_fd = -1, shm_size;
	void *shm = NULL;
	int progress = 0;
	EGLSurface surface = EGL_NO_SURFACE;
	GLuint prog = 0;
	GLuint vert = 0;
	GLuint frag = 0;
	GLuint posI = 0;

#define INIT do { \
	width = read_int(canvas_server); \
	if (width <= 0) { \
		printf("Failed to read width.\n"); \
		goto cleanup; \
	} \
	height = read_int(canvas_server); \
	if (height <= 0) { \
		printf("Failed to read height.\n"); \
		goto cleanup; \
	} \
\
	shm_fd = recv_fd(canvas_server); \
	if (shm_fd < 0) { \
		printf("Failed to receive shm fd.\n"); \
		goto cleanup; \
	} \
\
	shm_size = ashmem_get_size_region(shm_fd); \
	shm = mmap(NULL, shm_size, PROT_READ|PROT_WRITE, MAP_SHARED, shm_fd, 0); \
	if (shm == MAP_FAILED) { \
		printf("Client failed to map shm.\n"); \
		goto cleanup; \
	} \
\
	const EGLint pbufferAttribs[] = { \
	        EGL_WIDTH, width, \
	        EGL_HEIGHT, height, \
	        EGL_NONE \
	}; \
	surface = eglCreatePbufferSurface(d, config, pbufferAttribs); \
	if (surface == EGL_NO_SURFACE) { \
	    printf("eglCreatePbufferSurface: 0x%x\n", eglGetError()); \
	    goto cleanup; \
	} \
\
	if (!eglMakeCurrent(d, surface, surface, gles2)) { \
	    printf("eglMakeCurrent: 0x%x\n", eglGetError()); \
	    goto cleanup; \
	} \
\
	glClearColor(0.0, 0.5, 0.5, 1); \
	CHECK_GL_ERROR("glClearColor"); \
	glViewport(0, 0, width, height); \
	CHECK_GL_ERROR("glViewport"); \
\
	prog = glCreateProgram(); \
	CHECK_GL_ERROR("glCreateProgram"); \
\
	vert = createShader(GL_VERTEX_SHADER, "#version 100\n" \
	                                             "attribute vec2 pos;\n" \
	                                             "void main() {\n" \
	                                             "  gl_Position = vec4(pos, 0.0, 1.0);\n" \
	                                             "}\n"); \
\
	frag = createShader(GL_FRAGMENT_SHADER, "#version 100\n" \
	                                               "precision mediump float;\n" \
	                                               "void main() {\n" \
	                                               "  gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);\n" \
	                                               "}\n"); \
\
	glAttachShader(prog, vert); \
	CHECK_GL_ERROR("glAttachShader"); \
	glAttachShader(prog, frag); \
	CHECK_GL_ERROR("glAttachShader"); \
\
	glLinkProgram(prog); \
	GLint linked = GL_FALSE; \
	glGetProgramiv(prog, GL_LINK_STATUS, &linked); \
	CHECK_GL_ERROR("glGetProgramiv"); \
	if (linked != GL_TRUE) { \
	    GLint len; \
	    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &len); \
	    CHECK_GL_ERROR("glGetProgramiv"); \
	    char* log = (char *)calloc(len, 1); \
	    glGetProgramInfoLog(prog, len, NULL, log); \
	    CHECK_GL_ERROR("glGetProgramInfoLog"); \
	    printf("Program linking error:\nLinking log:\n%s\n", log); \
	    goto cleanup; \
	} \
\
	glUseProgram(prog); \
	CHECK_GL_ERROR("glUseProgram"); \
\
	posI = glGetAttribLocation(prog, "pos"); \
	CHECK_GL_ERROR("glGetAttribLocation"); \
	glEnableVertexAttribArray(posI); \
	CHECK_GL_ERROR("glEnableVertexAttribArray"); \
\
	ready = 1; \
} while (0)

#define DESTROY do { \
	ready = 0; \
	progress = 0; \
	if (shm != NULL) { \
		munmap(shm, shm_size); \
		shm = NULL; \
	} \
	if (shm_fd > 0) { \
		close(shm_fd); \
		shm_fd = -1; \
	} \
	if (surface != EGL_NO_SURFACE) { \
		eglDestroySurface(d, surface); \
		CHECK_GL_ERROR("eglDestroySurface"); \
		surface = EGL_NO_SURFACE; \
	} \
	if (vert != 0) { \
		glDeleteShader(vert); \
		CHECK_GL_ERROR("glDeleteShader"); \
		vert = 0; \
	} \
	if (frag != 0) { \
		glDeleteShader(frag); \
		CHECK_GL_ERROR("glDeleteShader"); \
		frag = 0; \
	} \
	if (prog != 0) { \
		glDeleteProgram(prog); \
		CHECK_GL_ERROR("glDeleteProgram"); \
		prog = 0; \
	} \
} while (0)

	while (true) {
		rc = read(events_server, &cmd, sizeof(cmd));
		if (rc == 0) goto cleanup;
		if (rc < 0 && errno != EAGAIN && errno != EWOULDBLOCK) goto cleanup;

		// No events, render
		if (rc < 0) {
		  	if (!ready) {
				printf("Trying to get buffer...\n");
				rc = get_buffer(canvas_server);
				if (rc != SUCCESS_RESP) {
                    			usleep(100000);
					continue;
		  		}
				INIT;
			}

            		float x = -1.0f + ((float)progress)/500.0f;
            		float y = 1.0f - ((float)progress)/500.0f;
            		const GLfloat vertices[] = {
            		        x, y,
            		        x + 0.2f, y,
            		        x, y - 0.2f,
            		        x + 0.2f, y - 0.2f
            		};
            		glClear(GL_COLOR_BUFFER_BIT);
            		CHECK_GL_ERROR("glClear");
            		glVertexAttribPointer(posI, 2, GL_FLOAT, false, 0, vertices);
            		CHECK_GL_ERROR("glVertexAttribPointer");
            		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
            		CHECK_GL_ERROR("glDrawArrays");

	    		glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, shm);

            		glFlush();
            		CHECK_GL_ERROR("glFlush");

            		rc = render(canvas_server);

            		if (rc < 0) {
            		    printf("Failed to render.\n");
                    	    usleep(100000);
			    continue;
            		}

			if (rc > 0) {
			    DESTROY;
			}

            		progress++;
            		if (progress > 1000) {
            		    progress = 1;
            		}
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

static int create_socket(const char *path)
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

int main(int argc, char* argv[])
{
  	int rc = -1;
	int canvas_server, events_server;

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

	rc = renderProcess(canvas_server, events_server);
close:
	if (canvas_server > 0) close(canvas_server);
	if (events_server > 0) close(events_server);
	return rc;
}
