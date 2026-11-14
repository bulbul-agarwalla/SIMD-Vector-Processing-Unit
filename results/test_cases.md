# SIMD Verification – Test Cases Reference

## Architecture Under Test

| Parameter | Value |
|-----------|-------|
| Number of lanes | 8 |
| Data width per lane | 8 bits |
| Total vector width | 64 bits |
| Opcode width | 3 bits |
| Implementation style | Combinational (no clock) |

## Opcode Encoding

| Opcode | Binary | Operation |
|--------|--------|-----------|
| ADD | 3'b000 | result = A + B (mod 256) |
| SUB | 3'b001 | result = A - B (mod 256) |
| AND | 3'b010 | result = A & B |
| OR | 3'b011 | result = A \| B |
| LT | 3'b100 | result = (A < B) ? 1 : 0 |

> **Note:** Lane indexing — Lane 0 occupies bits [7:0] (LSB), Lane 7 occupies bits [63:56] (MSB).

---

## Test 1 – Vector Addition

**Opcode:** ADD (3'b000)  
**Purpose:** Verify all 8 lanes compute correct sum.

| Lane | A | B | Expected | Notes |
|------|---|---|----------|-------|
| 0 | 80 | 8 | 88 | Simple sum |
| 1 | 70 | 7 | 77 | Simple sum |
| 2 | 60 | 6 | 66 | Simple sum |
| 3 | 50 | 5 | 55 | Simple sum |
| 4 | 40 | 4 | 44 | Simple sum |
| 5 | 30 | 3 | 33 | Simple sum |
| 6 | 20 | 2 | 22 | Simple sum |
| 7 | 10 | 1 | 11 | Simple sum |

---

## Test 2 – Vector Subtraction

**Opcode:** SUB (3'b001)

### Case 2a – Positive Results

| Lane | A | B | Expected | Notes |
|------|---|---|----------|-------|
| 0 | 30 | 3 | 27 | A > B, positive |
| 1 | 40 | 4 | 36 | A > B, positive |
| 2 | 50 | 5 | 45 | A > B, positive |
| 3 | 60 | 6 | 54 | A > B, positive |
| 4 | 70 | 7 | 63 | A > B, positive |
| 5 | 80 | 8 | 72 | A > B, positive |
| 6 | 90 | 9 | 81 | A > B, positive |
| 7 | 100 | 10 | 90 | A > B, positive |

### Case 2b – Zero Results

| Lane | A | B | Expected | Notes |
|------|---|---|----------|-------|
| 0–7 | Same as B | Same as A | 0 | A == B → result = 0 |

Values: {128, 64, 32, 16, 8, 4, 2, 1} for each of A and B.

### Case 2c – Underflow / 8-bit Wraparound

| Lane | A | B | Expected | Notes |
|------|---|---|----------|-------|
| 0 | 200 | 201 | 255 | -1 wraps to 255 |
| 1 | 100 | 101 | 255 | -1 wraps to 255 |
| 2 | 50 | 51 | 255 | -1 wraps to 255 |
| 3 | 10 | 11 | 255 | -1 wraps to 255 |
| 4 | 3 | 4 | 255 | -1 wraps to 255 |
| 5 | 2 | 3 | 255 | -1 wraps to 255 |
| 6 | 1 | 2 | 255 | -1 wraps to 255 |
| 7 | 0 | 1 | 255 | -1 wraps to 255 |

---

## Test 3 – Bitwise AND

**Opcode:** AND (3'b010)

### Sub-case 3a – Complementary patterns

| Lane | A (hex) | B (hex) | Expected (hex) | Notes |
|------|---------|---------|----------------|-------|
| 0 | 0x00 | 0xFF | 0x00 | No overlap |
| 1 | 0x33 | 0xCC | 0x00 | No overlap |
| 2 | 0xCC | 0x33 | 0x00 | No overlap |
| 3 | 0x0F | 0xF0 | 0x00 | No overlap |
| 4 | 0xF0 | 0x0F | 0x00 | No overlap |
| 5 | 0x55 | 0xAA | 0x00 | No overlap |
| 6 | 0xAA | 0x55 | 0x00 | No overlap |
| 7 | 0xFF | 0xFF | 0xFF | Full overlap |

### Sub-case 3b – Partial overlap

| Lane | A (hex) | B (hex) | Expected (hex) | Notes |
|------|---------|---------|----------------|-------|
| 0 | 0x7F | 0x80 | 0x00 | No overlap |
| 1 | 0xE1 | 0x1E | 0x00 | No overlap |
| 2 | 0x5A | 0xA5 | 0x00 | No overlap |
| 3 | 0x3C | 0xC3 | 0x00 | No overlap |
| 4 | 0x96 | 0x69 | 0x00 | No overlap |
| 5 | 0xAA | 0x55 | 0x00 | No overlap |
| 6 | 0xCC | 0xCC | 0xCC | Identical |
| 7 | 0xF0 | 0xFF | 0xF0 | Subset |

---

## Test 4 – Bitwise OR

**Opcode:** OR (3'b011)

### Sub-case 4a – Complementary patterns → all 0xFF

| Lanes | A (hex) | B (hex) | Expected (hex) |
|-------|---------|---------|----------------|
| 0 | 0x00 | 0xFF | 0xFF |
| 1 | 0x33 | 0xCC | 0xFF |
| 2 | 0xCC | 0x33 | 0xFF |
| 3 | 0x0F | 0xF0 | 0xFF |
| 4 | 0xF0 | 0x0F | 0xFF |
| 5 | 0x55 | 0xAA | 0xFF |
| 6 | 0xAA | 0x55 | 0xFF |
| 7 | 0xFF | 0x00 | 0xFF |

### Sub-case 4b – Identity (A = 0, result = B)

A = all zeros, B = {0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE}.  
Expected: each lane output equals B[lane].

---

## Test 5 – Less-Than Comparison

**Opcode:** LT (3'b100)

| Case | A values | B values | Expected | Rationale |
|------|----------|----------|----------|-----------|
| 5a | {0,1,10,50,100,127,200,254} | {1,2,11,51,101,128,201,255} | All lanes = 1 | A < B for every lane |
| 5b | All 42 | All 42 | All lanes = 0 | A == B → not less than |
| 5c | {2,5,10,25,50,100,200,255} | {1,2,5,10,25,50,100,100} | All lanes = 0 | A > B for every lane |
| 5d | Alternating 10/200 | Alternating 200/10 | Alternating 1/0 | Mixed per-lane result |

---

## Test 6 – Boundary / Edge Cases

| Case | Opcode | A | B | Expected | Rationale |
|------|--------|---|---|----------|-----------|
| 6a | ADD | 0 (all) | 0 (all) | 0 | Zero identity |
| 6b | ADD | 255 (all) | 1 (all) | 0 | Overflow wraparound |
| 6c | AND | 255 (all) | 255 (all) | 255 | All-ones AND |
| 6d | OR | 0 (all) | 0 (all) | 0 | Zero OR zero |
| 6e | ADD | Alternating 255/0 | Alternating 0/255 | 255 (all) | Complement addition |
| 6f | LT | {254,255,253,0,1,127,128,129} | {255,255,254,1,0,128,127,128} | {1,0,1,1,0,1,0,0} | Near-255 boundary |

---

## Test 7 – Rapid Opcode Switching

**Fixed inputs:** A = {100,200,150,50,75,25,180,90}, B = {50,100,50,50,25,75,80,90}

Opcode switches every 2 ns to verify combinational update latency.

| Opcode | Expected Lane[7:0] |
|--------|--------------------|
| ADD | {150,44,200,100,100,100,4,180} |
| SUB | {50,100,100,0,50,206,100,0} |
| AND | {32,64,18,50,9,9,16,90} |
| OR | {118,236,182,50,91,91,244,90} |
| LT | {0,0,0,0,0,1,0,0} |

> ADD: 200+100=300 → 44 (mod 256); 180+80=260 → 4 (mod 256)  
> SUB: 25-75 = -50 → 206 (mod 256)  
> LT: Only lane 2 (25 < 75) produces 1

---

## Coverage Summary

| Feature | Test Cases |
|---------|------------|
| All 5 opcodes | ✅ |
| All 8 lanes individually | ✅ |
| Addition overflow/wraparound | ✅ (Test 6b) |
| Subtraction underflow/wraparound | ✅ (Test 2c) |
| Bitwise AND – zero result | ✅ (Test 3a) |
| Bitwise AND – non-zero result | ✅ (Test 3b) |
| Bitwise OR – max result | ✅ (Test 4a) |
| Bitwise OR – identity property | ✅ (Test 4b) |
| LT: A < B | ✅ (Tests 5a, 5d) |
| LT: A == B | ✅ (Test 5b) |
| LT: A > B | ✅ (Tests 5c, 5d) |
| Boundary: 0, 255, near-255 | ✅ (Test 6) |
| Mixed lane patterns | ✅ (Tests 5d, 6e, 6f) |
| Combinational propagation latency | ✅ (Test 7) |

