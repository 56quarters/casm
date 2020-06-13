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
    /* print notice to stderr */
    lea notice, %rdi
    call eprint_c_str

    /* default to using fd 0 (stdin) for reads, fd 1 (stdout) for writes */
    movq $0, %rdi
    movq $1, %rsi
    call read_write_buf

    /* clean up and exit */
    call close_fds
    call exit_success

close_fds:
    /* close() syscall for stdin, stdout, stderr */
    mov $3, %rax
    mov $0, %rdi
    syscall

    mov $3, %rax
    mov $1, %rdi
    syscall

    mov $3, %rax
    mov $2, %rdi
    syscall

exit_success:
    /* exit_group() syscall with status 0 */
    movq $231, %rax
    movq $0, %rdi
    syscall

/*
 * rdi = read file descriptor
 * rsi = write file descriptor
 */
read_write_buf:
    /*
     * r12 = read file descriptor
     * r13 = write file descriptor
     * r14 = bytes read
     */
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
    je .end

    /* write() syscall to stdout from buf */
    movq $1, %rax
    movq %r13, %rdi
    movq $buf, %rsi
    movq %r14, %rdx
    syscall
    jmp .read_buf

.end:
    ret

/*
 * rdi = pointer to c string to print
 */
eprint_c_str:
    /*
     * r12 = pointer to string to print
     */
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
    ret
