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

    /* echo implementation */

    .data

/* 8K buffer for arguments */
buf:
    .space 1024 * 8, 0x0
    buf_len = . - buf

help_msg:
    .asciz "\
Usage: echo [OPTION]... [STRING]...\n\
\n\
Echo STRING(s) to standard output.\n\
\n\
Options:\n\
\t--help\tShow this help\n\
"

help_long:
    .asciz "--help"

newline:
    .asciz "\n"

space:
    .asciz " "

hello:
    .asciz "echo: hello from echo\n"

    .text

    .global _start

/**
 * Entry point - print any arguments provided to stdout.
 */
_start:
    /*
     * (rsp) = argc
     * (rsp + 8 + 8 * n ) = argv[n]
     *
     * r12 = argc
     * r13 = n loop variable
     * r14 = buffer address + offset
     */
    movq (%rsp), %r12
    movq $1, %r13 /* start at 1, skip argv[0] */
    lea buf, %r14

    cmp $1, %r12
     /* if there are no args, jump to the end which just prints a newline */
    je .print_buffer
    jmp .parse_cli_flags

.parse_cli_flags:
    /* compare argv[n] to "--help" */
    movq 8(%rsp, %r13, 8), %rdi
    lea help_long, %rsi
    call c_str_eq
    cmp $0, %rax
    je .show_help

    /* if n is less than argc, try the next argument */
    inc %r13
    cmp %r12, %r13
    jl .parse_cli_flags

    /* we've parsed all CLI flags looking for "--help", try printing things */
    movq $1, %r13 /* reset n */
    jmp .read_from_argv

.read_from_argv_space:
    /* add a space to the buffer, only needed when n > 2 */
    lea space, %rdi
    movq %r14, %rsi
    call copy_c_str
    add %rax, %r14
    /* fall through to print the next argument */
.read_from_argv:
    /* copy argv[n] into our buffer then add a space or print it out */
    movq 8(%rsp, %r13, 8), %rdi
    movq %r14, %rsi
    call copy_c_str
    add %rax, %r14

    inc %r13
    cmp %r12, %r13
    jl .read_from_argv_space
    jmp .print_buffer

.print_buffer:
    /* Note that we haven't been copying the null bytes at the ends of strings
       into the buffer and we don't add one here before trying to print. This
       works because we initialize the entire buffer with 0x0 (null byte) so
       as soon as we get to the end of bytes we've written, it's null */
    lea buf, %rdi
    call print_c_str

    lea newline, %rdi
    call print_c_str

    jmp .exit_success

.show_help:
    lea help_msg, %rdi
    call eprint_c_str
    jmp .exit_success

.exit_success:
    call close_std_fds
    call exit_success
