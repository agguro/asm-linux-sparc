
/*
 * agguro NAS Monitor
 * File: arch/sparc/syscall.S
 *
 * Target: Linux/SPARC 32-bit
 * ABI: SPARC V8
 *
 * Legacy socket operations use socketcall().
 * Return values: >= 0 on success, negative errno on failure.
 */

#include "syscalls.h"

    .section ".text"
    .align 4

    .global sys_socket
    .type sys_socket, #function

sys_socket:
    save %sp, -96, %sp

    st %i0, [%fp - 12]
    st %i1, [%fp - 8]
    st %i2, [%fp - 4]

    mov __NR_socketcall, %g1
    mov SYS_SOCKET, %o0
    add %fp, -12, %o1
    ta 0x10

    bcc 1f
     nop
    neg %o0, %o0
1:
    mov %o0, %i0
    ret
     restore

    .size sys_socket, .-sys_socket


    .global sys_bind
    .type sys_bind, #function

sys_bind:
    save %sp, -96, %sp

    st %i0, [%fp - 12]
    st %i1, [%fp - 8]
    st %i2, [%fp - 4]

    mov __NR_socketcall, %g1
    mov SYS_BIND, %o0
    add %fp, -12, %o1
    ta 0x10

    bcc 1f
     nop
    neg %o0, %o0
1:
    mov %o0, %i0
    ret
     restore

    .size sys_bind, .-sys_bind


    .global sys_listen
    .type sys_listen, #function

/*
 * int sys_listen(int fd, int backlog);
 */
sys_listen:
    save %sp, -96, %sp

    st %i0, [%fp - 8]       ! Socket descriptor
    st %i1, [%fp - 4]       ! Connection backlog

    mov __NR_socketcall, %g1
    mov SYS_LISTEN, %o0
    add %fp, -8, %o1
    ta 0x10

    bcc 1f
     nop
    neg %o0, %o0
1:
    mov %o0, %i0
    ret
     restore

    .size sys_listen, .-sys_listen


    .global sys_accept
    .type sys_accept, #function

/*
 * int sys_accept(int fd, void *addr, unsigned int *addrlen);
 *
 * A null address and length are permitted.
 */
sys_accept:
    save %sp, -96, %sp

    st %i0, [%fp - 12]      ! Listening socket
    st %i1, [%fp - 8]       ! Client address pointer
    st %i2, [%fp - 4]       ! Client address length pointer

    mov __NR_socketcall, %g1
    mov SYS_ACCEPT, %o0
    add %fp, -12, %o1
    ta 0x10

    bcc 1f
     nop
    neg %o0, %o0
1:
    mov %o0, %i0
    ret
     restore

    .size sys_accept, .-sys_accept

    .global sys_read
    .type sys_read, #function

/*
 * int sys_read(int fd, void *buffer, unsigned int count);
 *
 * Arguments:
 *   %o0 = file descriptor
 *   %o1 = buffer
 *   %o2 = byte count
 *
 * Returns:
 *   >= 0 = bytes read
 *   < 0  = negative errno
 */
sys_read:
    mov __NR_read, %g1
    ta 0x10

    bcc 1f
     nop

    neg %o0, %o0

1:
    retl
     nop

    .size sys_read, .-sys_read



    .global sys_close
    .type sys_close, #function

sys_close:
    mov __NR_close, %g1
    ta 0x10

    bcc 1f
     nop
    neg %o0, %o0
1:
    retl
     nop

    .size sys_close, .-sys_close
