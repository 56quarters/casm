/********************************************************************
 * Casm - bare bones implementation of `cat` in GNU assembly.
 *
 * Copyright 2020 Nick Pillitteri
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

help_msg:
    .asciz "\
Usage: cat [OPTION]... [FILE]...\n\
\n\
Concatenate FILE(s) to standard output.\n\
\n\
When no FILE is provided or when FILE is -, read from standard input.\n\
\n\
Options:\n\
\t--help\tShow this help\n\
"

help_long:
    .asciz "--help"

stdin_file:
    .asciz "-"

error_msg_bad_file:
    .asciz "error: could not open file. try `--help`\n"

    /** ************ **/
    /** text section **/
    /** ************ **/

    .text

    .global _start

/*
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

    /* if there's only one argv value, read from stdin */
    cmp $1, %r12
    je .read_from_stdin
    /* otherwise, try to parse CLI flags or just open each argv[n] value as a file */
    jmp .parse_cli_flags

.read_from_stdin:
    /* default to using fd 0 (stdin) for reads, fd 1 (stdout) for writes */
    movq $0, %rdi
    movq $1, %rsi
    call read_write_buf
    jmp .exit_success

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

    /* we've parsed all CLI flags looking for "--help", try opening files */
    movq $1, %r13 /* reset n */
    jmp .read_from_argv

.read_from_argv:
    /* try to open() argv[n] as a file or stdin for the name "-" */
    movq 8(%rsp, %r13, 8), %rdi
    call open_file

    /* save opened file descriptor */
    movq %rax, %r14
    cmp $0, %r14
    /* exit with an error if the fd is < 0 */
    jl .error_bad_file

    /* read just opened file descriptor, write to stdout */
    movq %r14, %rdi
    movq $1, %rsi
    call read_write_buf

    /* close file descriptor */
    movq $3, %rax
    movq %r14, %rdi
    syscall

    /* if n is less than argc, open the next file */
    inc %r13
    cmp %r12, %r13
    jl .read_from_argv

    /* otherwise, exit successfully since we've read all files */
    jmp .exit_success

.show_help:
    lea help_msg, %rdi
    call eprint_c_str
    jmp .exit_success

.error_bad_file:
    lea error_msg_bad_file, %rdi
    call eprint_c_str
    jmp .exit_error

.exit_success:
    call close_fds
    call exit_success

.exit_error:
    call close_fds
    call exit_error

/*
 * Open a file of the given name or stdin if the file is "-"
 *
 * rdi = pointer to file name
 * rax = file descriptor
 */
open_file:
    push %r12
    movq %rdi, %r12

    /* compare the given file name to "-" to see if we should read from stdin */
    lea stdin_file, %rsi
    call c_str_eq
    cmp $0, %rax
    je .open_stdin

    /* otherwise try to open it as a normal file name */
    jmp .open_name

.open_name:
    movq $2, %rax
    movq %r12, %rdi
    movq $0, %rsi
    syscall /* let the return here (rax) persist until we return */
    jmp .end_open_file

.open_stdin:
    movq $0, %rax
    jmp .end_open_file

.end_open_file:
    pop %r12
    ret

/*
 * Close stdin, stdout, and stderr
 */
close_fds:
    movq $3, %rax
    movq $0, %rdi
    syscall

    movq $3, %rax
    movq $1, %rdi
    syscall

    movq $3, %rax
    movq $2, %rdi
    syscall
    ret

/*
 * Exit the current process with status 0, killing all threads
 */
exit_success:
    /* exit_group() syscall with status 0 */
    movq $231, %rax
    movq $0, %rdi
    syscall
    ret

/*
 * Exit the current process with status 1, killing all threads
 */
exit_error:
    /* exit_group() syscall with status 1 */
    movq $231, %rax
    movq $1, %rdi
    syscall
    ret

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
    movq $2, %rdi               /* stderr file descriptor into rdi */
    movq %r12, %rdx             /* computed string length into rdx */
    syscall

    pop %r12
    ret
