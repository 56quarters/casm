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

help:
    .ascii "Help text!"
    help_len = . - help

help_long:
    .ascii "--help"
    help_long_len = . - help_long

help_short:
    .ascii "-h"
    help_short_len = . - help_short

    /** ************ **/
    /** text section **/
    /** ************ **/

    .text

    .global _start

_start:
    /* default to using fd 0 (stdin) for reads */
    movq $0, %r12
    jmp read_buf

exit_success:
    /* exit() syscall with status 0 */
    movq $60, %rax
    movq $0, %rdi
    syscall

read_buf:
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

    /* if we read more than 0 bytes, write and try another read */
    movq $0, %rax
    cmp %r13, %rax
    jne write_buf

    /* exit with success if we didn't jump */
    jmp exit_success


write_buf:
    /*
    r13 = bytes read from stdin
    */

    /* write() syscall to stdout from buf */
    movq $1, %rax
    movq $1, %rdi
    movq $buf, %rsi
    movq %r13, %rdx
    syscall

    /* attempt another read after writing */
    jmp read_buf
