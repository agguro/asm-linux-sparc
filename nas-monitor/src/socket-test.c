
/*
 * agguro NAS Monitor
 * File: src/socket-test.c
 *
 * Build:
 *   make
 *
 * Deploy and run:
 *   make remote-test
 *
 * Target: Linux/SPARC 32-bit, SPARC V8
 * No libc or dynamic linker.
 */

typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;

extern int sys_socket(int domain, int type, int protocol);
extern int sys_bind(int fd, const void *addr, unsigned int addrlen);
extern int sys_listen(int fd, int backlog);
extern int sys_accept(int fd, void *addr, unsigned int *addrlen);
extern int sys_close(int fd);
extern int sys_read(int fd, void *buffer, unsigned int count);

#define AF_INET      2
#define SOCK_STREAM  1
#define PORT         5555

struct sockaddr_in {
    u16 family;
    u16 port;
    u32 address;
    u8 zero[8];
};


/*
 * Read an HTTP request header.
 *
 * Stop at CRLF CRLF, the end of the HTTP headers.
 * Limit the request to 4096 bytes.
 *
 * Returns:
 *    0 = complete request headers
 *   -1 = connection closed prematurely
 *   -2 = request headers too large
 *   <0 = negative syscall errno (other than -1/-2)
 */
static int read_http_request(int fd)
{
    char c;
    unsigned int count = 0;
    unsigned int matched = 0;
    static const char terminator[] = "\r\n\r\n";

    while (count < 4096) {
        int result = sys_read(fd, &c, 1);

        if (result < 0)
            return result;

        if (result == 0)
            return -1;

        count++;

        if (c == terminator[matched]) {
            matched++;

            if (matched == 4)
                return 0;
        } else {
            matched = (c == '\r') ? 1 : 0;
        }
    }

    return -2;
}


static int sys_write(int fd, const void *buf, unsigned int len)
{
    register int g1 __asm__("g1") = 4;
    register int o0 __asm__("o0") = fd;
    register const void *o1 __asm__("o1") = buf;
    register unsigned int o2 __asm__("o2") = len;

    __asm__ volatile(
        "ta 0x10\n\t"
        "bcc 1f\n\t"
        "nop\n\t"
        "neg %%o0, %%o0\n"
        "1:"
        : "+r"(o0)
        : "r"(g1), "r"(o1), "r"(o2)
        : "cc", "memory"
    );

    return o0;
}

static void sys_exit(int status)
{
    register int g1 __asm__("g1") = 1;
    register int o0 __asm__("o0") = status;

    __asm__ volatile(
        "ta 0x10"
        :
        : "r"(g1), "r"(o0)
        : "cc", "memory"
    );

    for (;;) {}
}

static unsigned int string_length(const char *s)
{
    unsigned int n = 0;

    while (s[n])
        n++;

    return n;
}

static void print_string(const char *s)
{
    sys_write(1, s, string_length(s));
}

static void print_number(int n)
{
    char buf[12];
    unsigned int value;
    int pos = 11;

    buf[pos] = '\0';

    if (n < 0)
        value = (unsigned int)(-(n + 1)) + 1;
    else
        value = (unsigned int)n;

    do {
        buf[--pos] = '0' + (value % 10);
        value /= 10;
    } while (value);

    if (n < 0)
        buf[--pos] = '-';

    print_string(&buf[pos]);
}

static void print_result(const char *operation, int result)
{
    print_string(operation);
    print_string(" returned: ");
    print_number(result);
    print_string("\n");
}

static int write_all(int fd, const char *buf, unsigned int len)
{
    unsigned int sent = 0;

    while (sent < len) {
        int result = sys_write(fd, buf + sent, len - sent);

        if (result <= 0)
            return result < 0 ? result : -1;

        sent += (unsigned int)result;
    }

    return 0;
}

static const char response[] =
    "HTTP/1.0 200 OK\r\n"
    "Content-Type: text/html; charset=UTF-8\r\n"
    "Connection: close\r\n"
    "\r\n"
    "<!DOCTYPE html>\n"
    "<html lang=\"en\">\n"
    "<head>\n"
    "<meta charset=\"UTF-8\">\n"
    "<title>agguro NAS Monitor</title>\n"
    "</head>\n"
    "<body style=\"background:#101820;color:#e5e7eb;"
    "font-family:monospace;padding:40px\">\n"
    "<h1>agguro NAS Monitor</h1>\n"
    "<p>Hello from Linux/SPARC!</p>\n"
    "<p>Netgear ReadyNAS Duo - Infrant Neon</p>\n"
    "<p>HTTP server running without libc.</p>\n"
    "</body>\n"
    "</html>\n";


void _start(void)
{
    int server_fd;
    int client_fd;
    int result;
    unsigned int connections = 0;

    struct sockaddr_in addr = {
        .family = AF_INET,
        .port = 0x15B3,       /* Port 5555, network byte order */
        .address = 0,         /* INADDR_ANY: 0.0.0.0 */
        .zero = {0}
    };

    print_string("agguro NAS Monitor starting...\n");

    server_fd = sys_socket(AF_INET, SOCK_STREAM, 0);
    print_result("socket()", server_fd);

    if (server_fd < 0)
        sys_exit(1);

    result = sys_bind(server_fd, &addr, sizeof(addr));
    print_result("bind()", result);

    if (result < 0) {
        sys_close(server_fd);
        sys_exit(1);
    }

    result = sys_listen(server_fd, 5);
    print_result("listen()", result);

    if (result < 0) {
        sys_close(server_fd);
        sys_exit(1);
    }

    print_string("Listening on 0.0.0.0:5555\n");

    /*
     * Main server loop.
     * Handle one client at a time.
     */
    for (;;) {
        print_string("Waiting for connection...\n");

        client_fd = sys_accept(server_fd, (void *)0, (void *)0);

        if (client_fd < 0) {
            print_result("accept() failed", client_fd);
            break;
        }

        connections++;

        print_string("Connection #");
        print_number((int)connections);
        print_string("\n");

        result = read_http_request(client_fd);
        print_result("read_http_request()", result);

        if (result == 0) {
            result = write_all(
                client_fd,
                response,
                sizeof(response) - 1
            );

            print_result("write_all()", result);
        }

        sys_close(client_fd);

        print_string("Client connection closed.\n");
    }

    sys_close(server_fd);
    print_string("Server stopped.\n");
    sys_exit(1);
}
