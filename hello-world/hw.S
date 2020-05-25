.data

msg:
    .ascii "Hi there stranger!\n"
    msg_len = . - msg

err:
    .ascii "Oh noes!\n"
    err_len = . - err

.text
    .global _start

_start:
    movq $1, %rax
    movq $1, %rdi
    movq $msg, %rsi
    movq $msg_len, %rdx
    syscall

    movq $1, %rax
    movq $2, %rdi
    movq $err, %rsi
    movq $err_len, %rdx
    syscall

    movq $60, %rax
    movq $0, %rdi
    syscall
