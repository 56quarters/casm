/*
 *
 *
 */

    /** ************ **/
    /** data section **/
    /** ************ **/
    .data

msg:
    .ascii "Hi there stranger!\n"
    msg_len = . - msg

err:
    .ascii "Oh noes!\n"
    err_len = . - err

file:
    .ascii "/tmp\0"

    /** ************ **/
    /** text section **/
    /** ************ **/

    .text

    .global _start

_start:
    /* write() syscall to stdout */
    movq $1, %rax
    movq $1, %rdi
    movq $msg, %rsi
    movq $msg_len, %rdx
    syscall

    /* write() syscall to stderr */
    movq $1, %rax
    movq $2, %rdi
    movq $err, %rsi
    movq $err_len, %rdx
    syscall

    /* access() syscall */
    movq $21, %rax
    movq $file, %rdi
    movq $0, %rsi
    syscall

    /* store return of access() in r10 */
    movq %rax, %r10

    /* exit() syscall with return from access */
    movq $60, %rax
    movq %r10, %rdi
    syscall
