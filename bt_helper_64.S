.text

#define SP 29
#define BP 27

#ifdef __APPLE__
#define _(x) _##x
#else
#define _(x) x
#endif

.globl _(bt_interp_one)
.globl _(bt_continue)
.globl _(bt_continue_chain)
.globl _(bt_continue_ic)
.globl _(bt_enter)
.globl _(bt_interrupt)

.macro LOAD_CPU pc=1
.if \pc
        mov 128(%rbp), %eax
.endif
        mov (4*SP)(%rbp), %ebx
        mov (4*BP)(%rbp), %edx
        mov (4*0)(%rbp),  %esi
        mov (32*4 + 8)(%rbp), %rdi
//        mov (4*1)(%rbp),  %edi
.endm

.macro SAVE_CPU pc=1
.if \pc
        mov %eax, 128(%rbp)
.endif
        mov %ebx, (4*SP)(%rbp)
        mov %edx, (4*BP)(%rbp)
        mov %esi, (4*0)(%rbp)
//        mov %edi, (4*1)(%rbp)
.endm

_(bt_interp_one):
        SAVE_CPU 0
        movq %rbp, %rdi
        pushq $0             // fix stack alignment
        call _(bt_step_one)
        popq %rax
        LOAD_CPU
        ret

_(bt_interrupt):
        SAVE_CPU
        movq _(bt_stack_base)(%rip), %rsp
        movq %rbp, %rdi
        call _(bt_process_interrupt)
        xorl %edx, %edx
        xorl %ecx, %ecx
        movl %ebp, %eax
        call _(bt_translate_and_run)

_(bt_continue):
        mov %eax, %ecx

        /* Try a fast-path lookup of PC in the frag hash table. */
        andl  $0x3fb, %ecx
        leaq _(bt_frag_hash)(%rip), %r10
        movq  (%r10, %rcx, 1), %rcx
        testq %rcx, %rcx                /* non-NULL frag */
        jz miss
        cmpl  %eax, (%rcx)              /* Compare PC */
        jne miss
        movq 16(%rcx), %rcx

        cmpl $0, 132(%ebp)              /* Check CPU.halt */
        jnz miss

        jmp *%rcx

miss:
        pushq $0
_(bt_continue_chain):
        SAVE_CPU
        popq %rdx
        movl $1, %esi
        movq %rbp, %rdi
        call _(bt_translate_and_run)

_(bt_continue_ic):
        SAVE_CPU
        popq %rdx
        xorl %esi, %esi
        movq %rbp, %rdi
        call _(bt_translate_and_run)

_(bt_enter):
        mov %rdi, %rcx
        movq _(bt_stack_base)(%rip), %rsp
        leaq _(CPU)(%rip), %rbp
        LOAD_CPU
        jmp *%rcx
