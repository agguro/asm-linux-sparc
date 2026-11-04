
#ifndef AGGURO_NASMON_H
#define AGGURO_NASMON_H

typedef unsigned int u32;
typedef unsigned short u16;
typedef unsigned char u8;

#define AF_INET 2
#define SOCK_STREAM 1
#define NASMON_PORT 5555
#define HTTP_BUFFER_SIZE 4096

struct sockaddr_in {
    u16 family;
    u16 port;
    u32 address;
    u8 zero[8];
};

/* Linux/SPARC syscall wrappers */
extern int sys_socket(int domain, int type, int protocol);
extern int sys_bind(int fd, const void *addr, unsigned int length);
extern int sys_listen(int fd, int backlog);
extern int sys_accept(int fd, void *addr, unsigned int *length);
extern int sys_close(int fd);
extern int sys_read(int fd, void *buffer, unsigned int count);

/* Runtime helpers */
int nas_write(int fd, const void *buffer, unsigned int length);
void nas_exit(int status);
unsigned int nas_strlen(const char *text);
void nas_print(const char *text);
void nas_print_number(int number);

/* HTTP */
void http_handle(int client_fd);

/* Hardware */
int hardware_read_file(const char *path, char *buffer,
                       unsigned int capacity);

#endif
