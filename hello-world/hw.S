/*
 *
 *
 */

    /** ************ **/
    /** data section **/
    /** ************ **/
    .data

buf_sz = 1024 * 8

    /** ************ **/
    /** text section **/
    /** ************ **/

    .text

    .global _start

_start:
    /* malloc() a 1MB buffer into r12 */
    movq $buf_sz, %rdi
    call malloc
    movq %rax, %r12

    jmp read_buf

exit_success:
    /* free() call for buffer in r12 */
    movq %r12, %rdi
    call free

    /* exit() syscall with status 0 */
    movq $60, %rax
    movq $0, %rdi
    syscall

read_buf:
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

    /* if we read more than 0 bytes, write and try another read */
    movq $0, %rax
    cmp %r13, %rax
    jne write_buf

    /* exit with success if we didn't jump */
    jmp exit_success


write_buf:
    /*
    r12 = buffer address
    r13 = bytes read from stdin
    */

    /* write() syscall to stdout from buf */
    movq $1, %rax
    movq $1, %rdi
    movq %r12, %rsi
    movq %r13, %rdx
    syscall

    /* attempt another read after writing */
    jmp read_buf
