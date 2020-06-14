/********************************************************************
 * Casm - simplified implementation of `cat` in GCC assembly.
 *
 * Copyright 2020 TSH Labs
 *
 * Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
 * http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
 * <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
 * option. This file may not be copied, modified, or distributed
 * except according to those terms.
 *******************************************************************/

    /** ************ **/
    /** data section **/
    /** ************ **/
    .data

/* 128K buffer for reads */
buf:
    .space 1024 * 128, 0x0
    buf_len = . - buf

nl:
    .asciz "\n"
    nl_len = . - nl

help:
    .asciz "Help text!\n"
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
    /*
     * r12 = argc
     * r13 = n loop variable
     * r14 = current file descriptor
     */
    movq (%rsp), %r12
    movq $1, %r13 /* start at 1, skip argv[0] */

.argv_loop:
    movq $2, %rax
    movq 8(%rsp, %r13, 8), %rdi
    movq $0, %rsi
    syscall

    /* save opened file descriptor */
    movq %rax, %r14
    cmp $0, %r14
    jl exit_error

    /* read just opened file descriptor, write to stdout */
    movq %r14, %rdi
    movq $1, %rsi
    call read_write_buf

    /* close file descriptor */
    movq $3, %rax
    movq %r14, %rdi
    syscall

    inc %r13
    cmp %r12, %r13
    jl .argv_loop

    /* default to using fd 0 (stdin) for reads, fd 1 (stdout) for writes */
    #movq $0, %rdi
    #movq $1, %rsi
    #call read_write_buf

    /* clean up and exit */
    call close_fds
    call exit_success

close_fds:
    /* close() syscall for stdin, stdout, stderr */
    movq $3, %rax
    movq $0, %rdi
    syscall

    movq $3, %rax
    movq $1, %rdi
    syscall

    movq $3, %rax
    movq $2, %rdi
    syscall

/*
 * Exit the current process with status 0, killing all threads
 */
exit_success:
    /* exit_group() syscall with status 0 */
    movq $231, %rax
    movq $0, %rdi
    syscall

/*
 * Exit the current process with status 1, killing all threads
 */
exit_error:
    /* exit_group() syscall with status 1 */
    movq $231, %rax
    movq $1, %rdi
    syscall

/*
 * Read a file descriptor and write to another file descriptor until EOF
 *
 * rdi = read file descriptor
 * rsi = write file descriptor
 */
read_write_buf:
    /*
     * r12 = read file descriptor
     * r13 = write file descriptor
     * r14 = bytes read
    */
    push %r12
    push %r13
    push %r14

    movq %rdi, %r12
    movq %rsi, %r13

.read_buf:
    /* read() syscall from stdin */
    movq $0, %rax
    movq %r12, %rdi
    movq $buf, %rsi
    movq $buf_len, %rdx
    syscall

    /* store number of bytes read */
    movq %rax, %r14

    /* if we read 0 bytes, exit */
    movq $0, %rax
    cmp %r14, %rax
    je .end_read_buf

    /* write() syscall to stdout from buf */
    movq $1, %rax
    movq %r13, %rdi
    movq $buf, %rsi
    movq %r14, %rdx
    syscall
    jmp .read_buf

.end_read_buf:
    pop %r14
    pop %r13
    pop %r12
    ret

/*
 * Return 0 if two c strings (null terminated) are equal, 1 otherwise
 *
 * rdi = pointer to first c string
 * rsi = pointer to second c string
 * rax = return
 */
c_str_eq:
    /*
     * r12 = pointer to first string
     * r13 = pointer to second string
     * r14b = scratch for char pointed to by r12
    */
    push %r12
    push %r13
    push %r14

    movq %rdi, %r12
    movq %rsi, %r13

.cmp_byte:
    /* if the current char isn't the same, not equal */
    mov (%r12), %r14b
    cmp %r14b, (%r13)
    jne .end_not_eq

    /* if the current char is null (we already know this holds for both strings), equal */
    cmpb $0, (%r12)
    je .end_eq

    /* otherwise, try the next byte */
    inc %r12
    inc %r13
    jmp .cmp_byte

.end_not_eq:
    movq $1, %rax
    jmp .end

.end_eq:
    movq $0, %rax
    jmp .end

.end:
    pop %r14
    pop %r13
    pop %r12
    ret

/*
 * Print the contents of a c string (null terminated) to stderr
 *
 * rdi = pointer to c string to print
 */
eprint_c_str:
    /*
     * r12 = pointer to string to print
    */
    push %r12
    movq %rdi, %r12

.find_null:
    /* compare where r12 is pointing to null byte, end if equal */
    cmpb $0, (%r12)
    je .end_find_null
    /* otherwise, advance the pointer and check the next byte */
    inc %r12
    jmp .find_null

.end_find_null:
    /* length is r12 - rdi, stored in r12 */
    sub %rdi, %r12
    /* write() syscall to print the string. note that these instructions don't
    match the order of arguments to write() in order to avoid clobbering registers
    that we're still using */
    movq $1, %rax               /* syscall */
    movq %rdi, %rsi             /* buffer pointed to by rdi into rsi before we need to use rdi */
    movq $2, %rdi               /* file descriptor 0 into rdi */
    movq %r12, %rdx             /* computed string length into rdx */
    syscall

    pop %r12
    ret
