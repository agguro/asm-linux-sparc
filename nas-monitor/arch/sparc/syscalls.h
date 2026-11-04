#ifndef AGGURO_SPARC_SYSCALLS_H
#define AGGURO_SPARC_SYSCALLS_H

/* Linux SPARC 32-bit syscall numbers */
#include <asm/unistd_32.h>

/* Legacy Linux socketcall operation numbers */
#define SYS_SOCKET  1
#define SYS_BIND    2
#define SYS_CONNECT 3
#define SYS_LISTEN  4
#define SYS_ACCEPT  5

#endif
