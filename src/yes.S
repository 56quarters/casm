/********************************************************************
 * Casm - some core utilities implemented in GNU assembly.
 *
 * Copyright 2020 Nick Pillitteri
 *
 * Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
 * http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
 * <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
 * option. This file may not be copied, modified, or distributed
 * except according to those terms.
 *******************************************************************/

    /* "yes" implementation */

    .data

/* 4K buffer for arguments */
input_buf:
    .space 1024 * 4, 0x0
    input_buf_len = . - input_buf

/* 16K buffer for output */
output_buf:
    .space 1024 * 16, 0x0
    output_buf_len = . - output_buf

help_msg:
    .ascii "Usage: yes [OPTION]... [STRING]\n"
    .ascii "\n"
    .ascii "Output a STRING (or 'y' if omitted) repeatedly until killed.\n"
    .ascii "\n"
    .ascii "Options:\n"
    .ascii "\t--help\tShow this help\n"
    .byte  0

help_long:
    .asciz "--help"

default_str:
    .asciz "y"

error_msg_bad_write:
    .asciz "yes: write error\n"

    .text

    .global _start

/**
 * Entry point - repeatedly print 'y' or another string until killed.
 */
_start:
    /*
     * (rsp) = argc
     * (rsp + 8 + 8 * n ) = argv[n]
     *
     * r12 = argc
     * r13 = n loop variable
     * r14 = input buffer address + offset
     * r15 = buffered string length
     */
    movq (%rsp), %r12
    movq $1, %r13 /* start at 1, skip argv[0] */
    movq $input_buf, %r14

    cmp $1, %r12
     /* if there are no args, use the default string */
    je .use_default_str

.parse_cli_flags:
    /* check for a "--help" flag */
    movq %rsp, %rdi
    movq $help_long, %rsi
    call cli_flag_exists

    cmp $1, %rax
    jge .show_help
    jmp .use_argv_str

.use_argv_str_space:
    movb $' ', (%r14)
    inc %r14
    /* fall through to read the next argument */

.use_argv_str:
    /* copy argv[n] into our buffer then add a space or start printing it out */
    movq 8(%rsp, %r13, 8), %rdi
    movq %r14, %rsi
    call c_str_copy
    add %rax, %r14

    inc %r13
    cmp %r12, %r13
    jl .use_argv_str_space
    jmp .add_newline

.use_default_str:
    movq $default_str, %rdi
    movq %r14, %rsi
    call c_str_copy
    add %rax, %r14
    /* fall through to add a newline */

.add_newline:
    movb $'\n', (%r14)
    inc %r14
    /* fall through to fill the output buffer */

.fill_buffer:
    movq $input_buf, %rdi
    movq $output_buf, %rsi
    movq $output_buf_len, %rdx
    call fill_buffer

    movq $output_buf, %rdi
    call c_str_len
    movq %rax, %r15

    /* fall through to print the output buffer */

.print_buffer:
    movq $output_buf, %rdi
    movq $1, %rsi
    movq %r15, %rdx
    call c_str_write_len

    /* if we couldn't print to stdout, print to stderr and exit */
    cmp $0, %rax
    jl .error_write
    jmp .print_buffer

.show_help:
    movq $help_msg, %rdi
    call c_str_print
    jmp .exit_success

.error_write:
    movq $error_msg_bad_write, %rdi
    call c_str_eprint
    jmp .exit_error

.exit_error:
    call close_std_fds
    call exit_error

.exit_success:
    call close_std_fds
    call exit_success

/**
 * Copy the contents of a given string into a buffer, repeatedly until the buffer is full
 *
 * rdi = c string (null terminated) to fill buffer with, including a newline
 * rsi = buffer address
 * rdx = buffer size
 */
fill_buffer:
    /*
     * r12 = input string
     * r13 = buffer address
     * r14 = buffer length / space left
     * r15 = string length
     */
    push %r12
    push %r13
    push %r14
    push %r15

    movq %rdi, %r12
    movq %rsi, %r13
    movq %rdx, %r14

    call c_str_len
    movq %rax, %r15

.copy_bytes_to_buffer:
    cmp %r15, %r14
    jle .end_fill_buffer

    movq %r12, %rdi
    movq %r13, %rsi
    call c_str_copy
    add %rax, %r13
    sub %rax, %r14
    jmp .copy_bytes_to_buffer

.end_fill_buffer:
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    ret
