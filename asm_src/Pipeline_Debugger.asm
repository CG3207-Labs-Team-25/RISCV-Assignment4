.text
.globl main
main:
    addi s11, zero, 0
    lui s0, 0xffff0
    lui s1, 0x10010
    lw t0, 100(s0)
    andi t0, t0, 3
    addi t0, t0, 3
    addi t2, zero, 0
    addi s2, zero, 2
round:
    addi t1, zero, 1
sum_loop:
    add t2, t2, t1
    addi t1, t1, 1
    bge t0, t1, sum_loop
    addi s2, s2, -1
    bne s2, zero, round
    sw t2, 0(s1)
    addi t3, zero, -128
    sb t3, 8(s1)
    lb t4, 8(s1)
    lbu t5, 8(s1)
    sh t3, 10(s1)
    lh t6, 10(s1)
    lhu a1, 10(s1)
    lw a2, 0(s1)
    addi a2, a2, 1
    mul a3, t0, t0
    div a4, a3, t0
    rem a5, a3, t0
    jal zero, publish
    sw zero, 4(s1)
    sw zero, 96(s0)
publish:
    add a6, t2, a3
    sw a6, 96(s0)
    sw a6, 128(s0)
    addi s11, zero, 1
park:
    jal zero, park

.data
.align 2
    .word 0, 0xcafebabe, 0, 0
