/*
 *
 *
 */

    /** ************ **/
    /** data section **/
    /** ************ **/
    .data

buf:
    .space 8192, 0x0
    buf_len = . - buf

notice:
    .asciz "Reading from stdin\n"
    notice_len = . - notice

nl:
    .asciz "\n"
    nl_len = . - nl

help:
    .asciz "Help text!"
    help_len = . - help

help_long:
    .asciz "--help"
    help_long_len = . - help_long

help_short:
    .asciz "-h"
    help_short_len = . - help_short

    /** ************ **/
    /** text section **/
    /** ************ **/

    .text

    .global _start

_start:
    lea notice, %rdi
    call eprint_c_str

    /* default to using fd 0 (stdin) for reads */
    movq $0, %r12
    jmp read_write_buf

exit_success:
    /* exit() syscall with status 0 */
    movq $60, %rax
    movq $0, %rdi
    syscall

read_write_buf:
    /*
    r12 = read file descriptor
    r13 = bytes read from stdin
    */

    /* read() syscall from stdin */
    movq $0, %rax
    movq %r12, %rdi
    movq $buf, %rsi
    movq $buf_len, %rdx
    syscall

    /* store number of bytes read */
    movq %rax, %r13

    /* if we read 0 bytes, exit */
    movq $0, %rax
    cmp %r13, %rax
    je exit_success

    /* write() syscall to stdout from buf */
    movq $1, %rax
    movq $1, %rdi
    movq $buf, %rsi
    movq %r13, %rdx
    syscall

    /* attempt another read after writing */
    jmp read_write_buf


eprint_c_str:
    /* pointer to the string to check */
    movq %rdi, %r10

    .find_null:
    /* compare where r10 is pointing to null byte, end if equal */
    cmpb $0, (%r10)
    je .end_find_null
    /* otherwise, advance the pointer and check the next byte */
    inc %r10
    jmp .find_null

    .end_find_null:
    /* length is r10 - rdi, stored in r10 */
    sub %rdi, %r10
    /* write() syscall to print the string. note that these instructions don't
    match the order of arguments to write() in order to avoid clobbering registers
    that we're still using */
    movq $1, %rax               /* syscall */
    movq %rdi, %rsi             /* buffer pointed to by rdi into rsi before we need to use rdi */
    movq $2, %rdi               /* file descriptor 0 into rdi */
    movq %r10, %rdx             /* computed string length into rdx */
    syscall
    ret
