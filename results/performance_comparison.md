# Scalar vs SIMD Performance Analysis

## 1. Introduction

This document compares a scalar processing model with the 8-lane SIMD (Single Instruction, Multiple Data) Vector Processing Unit.

The objective is to understand how parallel processing improves the number of data elements processed at the same time.

Both models use the same 64-bit input vectors and support the same operations.

## 2. SIMD Architecture

The SIMD design consists of eight parallel 8-bit ALU lanes.

- Input A: 64 bits
- Input B: 64 bits
- Number of ALU lanes: 8
- Width of each lane: 8 bits
- Shared opcode: 3 bits
- Combined output: 64 bits

The 64-bit input vectors are divided into eight 8-bit elements. Each ALU lane processes one corresponding pair of elements.

All eight lanes receive the same opcode and operate in parallel.

### Supported Operations

| Opcode | Operation |
|--------|-----------|
| 000 | Addition |
| 001 | Subtraction |
| 010 | Bitwise AND |
| 011 | Bitwise OR |
| 100 | Less-than comparison |

## 3. Scalar Architecture

The scalar performance model uses one 8-bit ALU.

It processes the eight elements one after another. Each element is processed on a separate rising clock edge in the testbench.

Therefore, the illustrative scalar model requires eight clock cycles to process one complete 8-element vector.

## 4. Scalar vs SIMD Comparison

| Parameter | Scalar Model | SIMD Design |
|-----------|--------------|-------------|
| Number of ALUs | 1 | 8 |
| ALU width | 8 bits | 8 bits per lane |
| Input vector width | 64 bits | 64 bits |
| Elements processed per step | 1 | 8 |
| Execution model | Clocked sequential model | Combinational parallel datapath |
| Steps for 8 elements | 8 clock cycles | One combinational evaluation |
| Parallel processing | No | Yes |

**Note:** The scalar clock cycles are measured in the illustrative scalar testbench. The existing SIMD RTL is combinational and has no clock input. Therefore, the table does not represent a direct clock-cycle or hardware latency comparison.

## 5. Performance Analysis

### 5.1 Parallelism

The SIMD design contains eight ALU lanes. It can process eight 8-bit element pairs in parallel using one shared instruction.

The scalar model contains one ALU and processes one element pair at a time.

The SIMD architecture therefore provides 8-way data parallelism.

### 5.2 Theoretical Processing Capacity

- Scalar model: 1 element per modelled clock cycle.
- SIMD design: 8 elements per combinational evaluation.

The ratio of the number of parallel processing lanes is:

8 / 1 = 8

This represents an 8-way parallel processing capacity, not a measured 8x hardware speed-up.

### 5.3 Throughput and Latency

The scalar model completes eight sequential operations in eight clock cycles.

The SIMD datapath evaluates all eight lanes in parallel. However, it does not currently contain a clocked execution pipeline.

Actual hardware throughput, clock frequency, and latency cannot be calculated from the current RTL alone.

A fair hardware speed-up comparison would require equivalent clocked implementations and timing measurements.

## 6. Verification Results

### 6.1 Existing SIMD Verification

The existing SIMD verification testbench completed:

- Total checks: 184
- Passed: 184
- Failed: 0

### 6.2 Scalar vs SIMD Verification

The scalar comparison testbench checked six opcodes:

- Addition
- Subtraction
- Bitwise AND
- Bitwise OR
- Less-than comparison
- Invalid opcode

Results:

| Metric | Result |
|--------|--------|
| Total tests | 6 |
| Passed | 6 |
| Failed | 0 |
| Final status | PASS |

The scalar and SIMD models produced identical 64-bit results for all six test cases.

### 6.3 Clocked Scalar Model

The clocked scalar performance test processed all eight elements sequentially.

- Scalar ALUs: 1
- Scalar clock cycles: 8
- SIMD ALUs: 8
- Verification: PASSED

Both models produced the same result:

`0b16212c37424d58`

## 7. Advantages of SIMD

1. Parallel Processing: Multiple data elements are processed simultaneously.
2. Higher Data Throughput Potential: Eight ALU lanes can process eight elements in parallel.
3. Shared Control: All lanes use the same opcode.
4. Efficient Repeated Operations: Useful for vector arithmetic and data processing tasks.

## 8. Limitations

1. The current SIMD datapath is combinational and has no clocked pipeline.
2. All lanes execute the same operation, which limits independent instruction control.
3. The design uses fixed 8-bit elements and supports a limited set of operations.
4. Eight ALU lanes require more hardware resources than one scalar ALU.
5. Actual frequency, power, area, and hardware speed-up have not been measured.

## 9. Conclusion

The comparison demonstrates the main advantage of SIMD processing: data parallelism.

The scalar model processes one element at a time, while the 8-lane SIMD design evaluates eight elements in parallel.

Both models passed the output comparison tests and produced identical results.

The design demonstrates 8-way parallel processing capacity. However, actual hardware speed-up requires further evaluation using clocked implementations and hardware timing analysis.
