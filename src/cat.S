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

    /* cat implementation */

    .data

/* 128K buffer for reads */
buf:
    .space 1024 * 128, 0x0
    buf_len = . - buf

help_msg:
    .ascii "Usage: cat [OPTION]... [FILE]...\n"
    .ascii "\n"
    .ascii "Concatenate FILE(s) to standard output.\n"
    .ascii "\n"
    .ascii "When no FILE is provided or when FILE is -, read from standard input.\n"
    .ascii "\n"
    .ascii "Options:\n"
    .ascii "\t--help\tShow this help\n"
    .byte  0

help_long:
    .asciz "--help"

stdin_file:
    .asciz "-"

error_msg_bad_open:
    .asciz "cat: could not open file\n"

error_msg_bad_write:
    .asciz "cat: read/write error\n"

    .text

    .global _start

/**
 * Entry point - read from stdin or several files and write to stdout.
 *
 * Exit when EOF is recieved on stdin or when all files (passed via argv) have
 * been read. If any file cannot be read, this program with exit with an error
 * (non-zero) status.
 */
_start:
    /*
     * (rsp) = argc
     * (rsp + 8 + 8 * n ) = argv[n]
     *
     * r12 = argc
     * r13 = n loop variable
     * r14 = current file descriptor
     */
    movq (%rsp), %r12
    movq $1, %r13 /* start at 1, skip argv[0] */

    cmp $1, %r12
    jg .parse_cli_flags /* more than one arg, parse CLI flags and read files */

.read_from_stdin:
    /* default to using fd 0 (stdin) for reads, fd 1 (stdout) for writes */
    movq $0, %rdi
    movq $1, %rsi
    call read_write_buf
    cmp $0, %rax
    jne .error_write
    jmp .exit_success

.parse_cli_flags:
    /* check for a "--help" flag */
    movq %rsp, %rdi
    lea help_long, %rsi
    call cli_flag_exists

    cmp $1, %rax
    jge .show_help

.read_from_argv:
    /* try to open() argv[n] as a file or stdin for the name "-" */
    movq 8(%rsp, %r13, 8), %rdi
    call open_file

    /* save opened file descriptor */
    movq %rax, %r14
    cmp $0, %r14
    /* exit with an error if the fd is < 0 */
    jl .error_bad_open

    /* read just opened file descriptor, write to stdout */
    movq %r14, %rdi
    movq $1, %rsi
    call read_write_buf
    cmp $0, %rax
    jne .error_write

    /* close file descriptor */
    movq %r14, %rdi
    call close_file

    /* if n is less than argc, open the next file */
    inc %r13
    cmp %r12, %r13
    jl .read_from_argv

    /* otherwise, exit successfully since we've read all files */
    jmp .exit_success

.show_help:
    lea help_msg, %rdi
    call c_str_print
    jmp .exit_success

.error_bad_open:
    lea error_msg_bad_open, %rdi
    call c_str_eprint
    jmp .exit_error

.error_write:
    lea error_msg_bad_write, %rdi
    call c_str_eprint
    jmp .exit_error

.exit_success:
    call close_std_fds
    call exit_success

.exit_error:
    call close_std_fds
    call exit_error

/**
 * Open a file of the given name or stdin if the file is "-"
 *
 * rdi = pointer to file name
 * rax = return, file descriptor
 */
open_file:
    /*
     * r12 = pointer to file name
     */
    push %r12
    movq %rdi, %r12

    /* compare the given file name to "-" to see if we should read from stdin */
    lea stdin_file, %rsi
    call c_str_eq
    cmp $0, %rax
    jne .open_name

.open_stdin:
    movq $0, %rax
    jmp .end_open_file

.open_name:
    movq $2, %rax
    movq %r12, %rdi
    movq $0, %rsi
    syscall

.end_open_file:
    pop %r12
    ret

/**
 * Close the given file descriptor if it isn't stdin (fd 0)
 *
 * rdi = file descriptor
 */
close_file:
    /* if the fd is stdin, don't close it */
    cmp $0, %rdi
    je .end_close_file

    /* otherwise, try to close it */
    movq $3, %rax
    syscall

.end_close_file:
    ret

/**
 * Read a file descriptor and write to another file descriptor until EOF
 *
 * rdi = read file descriptor
 * rsi = write file descriptor
 * rax = return 0 for success, 1 for error
 */
read_write_buf:
    /*
     * r12 = read file descriptor
     * r13 = write file descriptor
     * r14 = bytes read
     * r15 = buffer address + offset
     */
    push %r12
    push %r13
    push %r14
    push %r15

    movq %rdi, %r12
    movq %rsi, %r13

.read_buf:
    /* read() syscall from input file descriptor */
    movq $0, %rax
    movq %r12, %rdi
    movq $buf, %rsi
    movq $buf_len, %rdx
    syscall

    movq %rax, %r14 /* number of bytes read */
    movq $buf, %r15 /* address of the buffer to write */

    cmp $0, %r14
    jl .end_error   /* if bytes read is < 0, error */
    je .end_success /* if bytes read = 0, end */
    /* otherwise, attempt to write the results */

.write_buf:
    /* write() syscall to output file descriptor from buf */
    movq $1, %rax
    movq %r13, %rdi
    movq %r15, %rsi
    movq %r14, %rdx
    syscall

    cmp $0, %rax
    jl .end_error /* if bytes written < 0, error */

    sub %rax, %r14 /* subtract bytes written from bytes to write */
    add %rax, %r15 /* add bytes written to the buffer offset */
    cmp $0, %r14
    jg .write_buf /* write again if we didn't write everything we read before */
    jmp .read_buf /* otherwise, attempt another read + write */

.end_success:
    movq $0, %rax
    jmp .end_read_buf

.end_error:
    movq $1, %rax
    jmp .end_read_buf

.end_read_buf:
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    ret
