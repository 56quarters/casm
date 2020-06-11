/*
 *
 *
 */

    /** ************ **/
    /** data section **/
    /** ************ **/
    .data

buf_sz = 1024 * 1024

    /** ************ **/
    /** text section **/
    /** ************ **/

    .text

    .global _start

_start:
    /* malloc() a 1MB buffer */
    movq $buf_sz, %rdi
    call malloc
    movq %rax, %r12

    jmp read_write_buf

exit_success:
    /* exit() syscall with status 0 */
    movq $60, %rax
    movq $0, %rdi
    syscall

exit_error:
    /* exit() syscall with status 1 */
    movq $60, %rax
    movq $1, %rdi
    syscall

read_write_buf:
    /*
    r12 = buffer address
    r13 = bytes read from stdin
    */

    /* read() syscall from stdin */
    movq $0, %rax
    movq $0, %rdi
    movq %r12, %rsi
    movq $buf_sz, %rdx
    syscall

    /* store number of bytes read in r13 */
    movq %rax, %r13

    /* write() syscall to stdout from buf */
    movq $1, %rax
    movq $1, %rdi
    movq %r12, %rsi
    movq %r13, %rdx
    syscall

    /* if we read the max number of bytes, try another read */
    movq $buf_sz, %rax
    cmp %r13, %rax
    je read_write_buf

    /* exit with success if we didn't jump */
    jmp exit_success
