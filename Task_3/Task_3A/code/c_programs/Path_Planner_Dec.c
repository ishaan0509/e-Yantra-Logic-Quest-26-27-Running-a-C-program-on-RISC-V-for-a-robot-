/*
* Logic Quest (LQ): Task 3A Path Planner with Decryption
*
* Computes the shortest path on the Logic Quest arena (nodes N1..N36), with the
* line weights of Figure 1 on the Task 3A page: straight line 5, ring arcs
* 7 / 11 / 15 / 19 (inner ring to outermost ring), wavy line N1-N36 100.
*
* Inputs : current_node, next_node, is_encrypted
*   current_node     : where the bot is, 1..36. The path starts here.
*                      At the first location the bot is in the start box, N35.
*   is_encrypted = 0 : next_node is a node number.
*                      Path: current_node -> next_node.
*   is_encrypted = 1 : next_node is the 8-byte encrypted code, encrypted with
*                      PRESENT-80.
*                      Path: current_node -> the drop node in the block.
*
* Decrypted code (8 bytes, byte 0 first):
*   byte 0     : done flag (1 = last block: no pick-up after this drop)
*   byte 1..5  : message, 5 ASCII characters (0x00 = no character)
*   byte 6     : next pick-up node 1..36 (not used when the done flag is 1)
*   byte 7     : drop node 1..36 for this block
*   e.g. message "HELLO", drop at N26, then pick up at N12
*        -> 00 48 45 4C 4C 4F 0C 1A = 0048454C4C4F0C1A
*
* Outputs:
*   is_encrypted = 0 : the path from current_node to next_node.
*   is_encrypted = 1 : the message (message[]) and the path from current_node
*                      to the drop node. When the done flag is 0, the inputs
*                      for the next run are written too:
*                          IS_ENCRYPTED = 0
*                          CURRENT_NODE = the drop node
*                          NEXT_NODE    = the next pick-up node
*                      When the done flag is 1, the inputs are left as they are.
*
* Output (PC), read by test.sh line by line:
*   is_encrypted = 0     is_encrypted = 1, done = 0     is_encrypted = 1, done = 1
*   35                   Message : HELLO                Message : BYE
*   ...                  7                              7
*   7                    ...                            ...
*                        26                             26
*                        Next current_node : 26         Done
*                        Next next_node : 12
*   The path is one node per line, first node first. The message line shows
*   the non-zero message bytes as characters. The code at the end of main
*   prints all of this from message[], path_planned[], idx and the inputs
*   written for the next run.
*
* Debug prints: start every debug line with "dbg:" (see Functions Usage
*   below). test.sh and the evaluator skip the lines that start with "dbg:".
*   Any other extra line counts as part of your output and makes it wrong.
*
* PRESENT-80 (the cipher used for the encrypted codes):
*   block 64 bits, key 80 bits = A1 B2 C3 D4 E5 F6 07 18 29 3A (PRESENT_KEY_* below),
*   31 rounds. See the Task 3A page for the full description of the encryption;
*   your program has to do the reverse.
*
* Data memory ranges (used on the RISC-V CPU, Task 3B):
*   0x02000000 .. 0x0200000F : inputs
*   0x02000010 .. 0x0200001F : outputs (0x0200001C = CPU_DONE)
*   0x02000020 and up        : working memory, stack at the top
*
* Inputs  : ENCRYPTED_HI (0x02000000)  encrypted block, bytes 0..3 (first 8 hex digits)
*           ENCRYPTED_LO (0x02000004)  encrypted block, bytes 4..7 (last 8 hex digits)
*           IS_ENCRYPTED (0x02000008)  0 or 1                            } written for
*           NEXT_NODE    (0x0200000C)  next node, when IS_ENCRYPTED = 0   } the next run
*           CURRENT_NODE (0x0200000D)  current node (where the bot is)    } when done = 0
* Outputs : MESSAGE_0..4 (0x02000010 .. 0x02000014)  message, block bytes 1..5
*           NODE_POINT   (0x02000018)  every node of the path, written in order
*           CPU_DONE     (0x0200001C)  = 1 when finished
*
* Make sure you don't change anything outside the "Add your code here" sections.
*/

#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <limits.h>

// PRESENT-80 key: A1 B2 C3 D4 E5 F6 07 18 29 3A
#define PRESENT_KEY_HI  0xA1B2C3D4   // key bits 79..48
#define PRESENT_KEY_MID 0xE5F60718   // key bits 47..16
#define PRESENT_KEY_LO  0x293A       // key bits 15..0

#ifdef __linux__ // for host pc

    #include <stdio.h>

    void _put_byte(char c) { putchar(c); }

    void _put_str(char *str) {
        while (*str) {
            _put_byte(*str++);
        }
    }

    void print_output(uint8_t num) {
        if (num == 0) {
            putchar('0'); // if the number is 0, directly print '0'
            _put_byte('\n');
            return;
        }

        // convert the integer to a string
        char buffer[20];
        uint8_t index = 0;

        while (num > 0) {
            buffer[index++] = '0' + num % 10; // convert the last digit to its character representation
            num /= 10;                        // move to the next digit
        }
        // print the characters in reverse order (from right to left)
        while (index > 0) { putchar(buffer[--index]); }
        _put_byte('\n');
    }

    void _put_value(uint8_t val) { print_output(val); }

    // print a 32-bit value as 8 hex digits and a newline (e.g. the decrypted block)
    void _put_hex(uint32_t val) { printf("%08X\n", (unsigned int)val); }

    // read 16 hex digits into two 32-bit words, returns 0 if the text is not 16 hex digits
    int read_block(const char *hex, uint32_t *hi, uint32_t *lo) {
        uint32_t word[2] = { 0, 0 };
        if (hex[0] == '0' && (hex[1] == 'x' || hex[1] == 'X')) hex += 2;
        for (int n = 0; n < 16; n++) {
            char c = hex[n];
            uint32_t d;
            if      (c >= '0' && c <= '9') d = c - '0';
            else if (c >= 'a' && c <= 'f') d = c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') d = c - 'A' + 10;
            else return 0;
            word[n >> 3] = (word[n >> 3] << 4) | d;
        }
        if (hex[16] != '\0') return 0;
        *hi = word[0];
        *lo = word[1];
        return 1;
    }

    /*
     * On the PC there is no data memory at 0x02000000, so MEM32(address) is a
     * normal array (one entry per 32-bit word). On the CPU it is the real
     * data memory. Either way, MEM32(0x02000020) reads the same place.
     */
    static uint32_t pc_data_mem[128];
    #define MEM32(addr)  (pc_data_mem[((addr) - 0x02000000u) >> 2])

#else  // for the test device

    void _put_byte(char c) { }
    void _put_value(uint8_t val) { }
    void _put_hex(uint32_t val) { }
    void _put_str(char *str) { }

    #define MEM32(addr)  (*(volatile uint32_t *)(addr))

#endif

/*
Functions Usage

To print while debugging, use the functions below, not printf().
On the PC they print. On the CPU they are empty, so they cost nothing there
and the same file still builds with generatehex.sh.

for a character: _put_byte('A');                        (putchar() on the PC)
for newline:     _put_byte('\n');
for string:      _put_str("your string here");
for number:      _put_value(your_number_here);           0 to 255, then a newline
for 32 bits:     _put_hex(your_32_bit_value_here);       8 hex digits, then a newline

Start every debug line with "dbg:" and end it with a newline (_put_value
and _put_hex end the line for you). test.sh and the evaluator skip the
lines that start with "dbg:", so these prints can stay in the file you
submit. Any other line you print counts as part of your output (see
"Output (PC)" at the top) and makes it wrong.

Examples:
        _put_str("dbg: start_point = ");     _put_value(start_point);
        _put_str("dbg: end_point = ");       _put_value(end_point);
        _put_str("dbg: ENCRYPTED_HI = ");    _put_hex(ENCRYPTED_HI);    // encrypted block, bytes 0..3
        _put_str("dbg: ENCRYPTED_LO = ");    _put_hex(ENCRYPTED_LO);    // encrypted block, bytes 4..7
        _put_str("dbg: first character = "); _put_byte(message[0]); _put_byte('\n');
        _put_str("dbg: Hello World!\n");

*/

// Custom Functions

// ############# Add your code here #############

// add your own #defines and functions here
// (e.g. the PRESENT-80 decryption and the path planner)

// Notes for the Task 3B CPU (Table 9):
//   - no tables or initialised arrays: the arena is written as code (lq_nodes),
//     and the two S-boxes are packed into 32-bit constants (immediates)
//   - no multiply, divide or remainder: only shifts, masks, add and subtract
//   - no globals, and no arrays of our own
//   - nothing is kept from an earlier run: every value is set before it is read
// RAM (data memory): the program writes only what the boilerplate needs (the path,
// the outputs and the next move's inputs) plus two saved registers in main:
//   - no distance table: the arena's shape gives the next step directly (see below)
//   - all of the planner's state fits in one 64-bit value that is passed through
//     the calls in registers, so nothing else is saved on the stack
//   - the encrypted code is decrypted twice (for the path, then for the message)
//     rather than kept in registers while planning
//   - the code avoids large constants in loops and functions called from several
//     places, which would make the compiler keep values in saved registers

#define LQ_NODES   36       // nodes N1..N36

// PRESENT S-box, nibble x at bits 4x..4x+3:  S = C 5 6 B 9 0 A D 3 E F 8 4 7 1 2
#define LQ_S_LO    0xDA09B65Cu  // S[7..0]
#define LQ_S_HI    0x21748FE3u  // S[15..8]
// inverse S-box:                             5 E F 8 C 1 2 D B 4 6 3 0 7 9 A
#define LQ_SI_LO   0xD21C8FE5u  // Sinv[7..0]
#define LQ_SI_HI   0xA970364Bu  // Sinv[15..8]

// one S-box lookup: x is a nibble 0..15, the table is packed in (tlo, thi)
// (a macro, so the decryption makes no calls and keeps its values in registers)
#define LQ_NIB(x, tlo, thi)                                     \
    (((x) & 8) ? (((thi) >> (((x) & 7) << 2)) & 0xF)            \
               : (((tlo) >> ((x) << 2)) & 0xF))

// rotate the 80-bit key register by one bit. a = key bits 79..48, b = bits 47..16,
// and bits 15..0 sit in the top half of c (its low half stays 0)
#define LQ_KEY_ROTL1()                          \
    do {                                        \
        t = a >> 31;                            \
        a = (a << 1) | (b >> 31);               \
        b = (b << 1) | (c >> 31);               \
        c = (c << 1) | (t << 16);               \
    } while (0)
#define LQ_KEY_ROTR1()                          \
    do {                                        \
        t = (c >> 16) & 1;                      \
        c = ((c >> 17) << 16) | (b << 31);      \
        b = (b >> 1) | (a << 31);               \
        a = (a >> 1) | (t << 31);               \
    } while (0)

// PRESENT-80 decryption of one 64-bit block, in place: hi = bits 63..32 (bytes 0..3),
// lo = bits 31..0 (bytes 4..7).
// Encryption, round i = 1..31: state ^= Ki, S-box, permutation, then the key
// register is updated with i; at the end state ^= K32.
// Decryption undoes it from the end:
//   1. run the key schedule forward 31 times: the key register then holds K32
//      (each update: rotate left by 61 (done as right by 19), S-box on bits 79..76,
//      XOR i into bits 19..15; key bits 19..16 are bits 3..0 of b, key bit 15 is
//      bit 31 of c)
//   2. state ^= K32 (K = key bits 79..16 = a, b)
//   3. for i = 31..1:
//      - inverse permutation and inverse S-box, one output nibble at a time.
//        Encryption moved bit j to P(j) = 16j mod 63 = ((j & 3) << 4) | (j >> 2), so
//        output nibble m (bits 4m..4m+3) is bit m of each 16-bit quarter of the
//        state: bits m, 16 + m, 32 + m, 48 + m. Going from m = 15 down to 0, the state
//        is shifted left by one each time, so those bits are always at 15 and 31 of
//        lo and hi; each nibble goes through the inverse S-box and is shifted in at
//        the bottom of (nhi, nlo)
//      - undo key update i: XOR i, inverse S-box on bits 79..76, rotate right by 61
//        (= left by 19); the register then holds Ki
//      - state ^= Ki
// It is a macro (no comments can go inside it) because main uses it twice: once to
// plan the move and once more for the message, instead of keeping the decrypted
// code in registers while planning (that would take two saved registers on the
// stack). Written with few values alive at once, so it fits in scratch registers.
#define LQ_DECRYPT(hi, lo)                                              \
    do {                                                                \
        uint32_t a = PRESENT_KEY_HI;                                    \
        uint32_t b = PRESENT_KEY_MID;                                   \
        uint32_t c = (uint32_t)PRESENT_KEY_LO << 16;                    \
        uint32_t t, nhi, nlo, i, k, round;                              \
        for (round = 1; round < 32; round++) {                          \
            for (k = 0; k < 19; k++) {                                  \
                LQ_KEY_ROTR1();                                         \
            }                                                           \
            t = a >> 28;                                                \
            a ^= (LQ_NIB(t, LQ_S_LO, LQ_S_HI) ^ t) << 28;               \
            b ^= round >> 1;                                            \
            c ^= round << 31;                                           \
        }                                                               \
        hi ^= a;                                                        \
        lo ^= b;                                                        \
        for (round = 31; round > 0; round--) {                          \
            nhi = 0;                                                    \
            nlo = 0;                                                    \
            for (i = 0; i < 16; i++) {                                  \
                t = ((lo >> 15) & 1) | ((lo >> 30) & 2)                 \
                  | ((hi >> 13) & 4) | ((hi >> 28) & 8);                \
                lo <<= 1;                                               \
                hi <<= 1;                                               \
                t = LQ_NIB(t, LQ_SI_LO, LQ_SI_HI);                      \
                nhi = (nhi << 4) | (nlo >> 28);                         \
                nlo = (nlo << 4) | t;                                   \
            }                                                           \
            hi = nhi;                                                   \
            lo = nlo;                                                   \
            b ^= round >> 1;                                            \
            c ^= round << 31;                                           \
            t = a >> 28;                                                \
            a ^= (LQ_NIB(t, LQ_SI_LO, LQ_SI_HI) ^ t) << 28;             \
            for (k = 0; k < 19; k++) {                                  \
                LQ_KEY_ROTL1();                                         \
            }                                                           \
            hi ^= a;                                                    \
            lo ^= b;                                                    \
        }                                                               \
    } while (0)

// ---------------------------------------------------------------------------------
// The arena of Figure 1, and how the planner uses its shape
//
// The arena is a "theta" with small trees hanging off it:
//   - 16 nodes form three routes between N5 and N14:
//       route 1: N5 - N1 - N4 - N14                                        length  35
//       route 2: N5 - N7 - N15 - N14                                       length  27
//       route 3: N5 - N8 - N20 - N27 - N29 - N32 - N28 - N31 - N35 - N30
//                   - N13 - N14                                            length 131
//   - the other 20 nodes are in trees hanging off those routes (one way in and out),
//     e.g. N11 hangs off N8, with N9, N12, N19 and N18 below it.
// Every theta node, followed by the tree hanging off it, gets ids in depth-first
// order, so "node g is below tree node v" is just: id(v) <= id(g) <= last id below v.
//
// The next step from node c towards the goal g:
//   - c is in a tree:  if g is below c, go down to the child that has g below it,
//                      otherwise go up to c's parent
//   - c is on the theta and g hangs below c (or is c): go down the same way
//   - otherwise c is on the theta and g's tree hangs off another theta node a:
//     follow the shortest way to a along the theta. A theta node x on route i at
//     offset t (distance from N5 along the route) is
//       D5(x)  = min(t, L(i) - t + L(m))  from N5 and
//       D14(x) = min(L(i) - t, t + L(m))  from N14,
//     where m is the shortest other route. The shortest way from c to a is the
//     smallest of: along the route (same route only), via N5 (D5(c) + D5(a)) and
//     via N14 (D14(c) + D14(a)); the first step goes the matching way.
//
// Node constants (one 32-bit number k per node):
//   all nodes:   bits 0..5 = id
//   tree nodes:  bits 6..11 = last id below the node, bits 12..17 = parent
//   theta nodes: bit 28 set; bits 6..11 = previous node and bits 12..17 = next node
//                along its route (0 for the branch nodes N5 and N14), bits 18..25 =
//                offset, bits 26..27 = route (N5 and N14 count as route 2)
// ---------------------------------------------------------------------------------
#define LQ_ID(k)     ((k) & 63)
#define LQ_END(k)    (((k) >> 6) & 63)  // tree node: last id below it
#define LQ_PARENT(k) (((k) >> 12) & 63) // tree node: parent
#define LQ_PREV(k)   (((k) >> 6) & 63)  // theta node: previous node on its route
#define LQ_NEXT(k)   (((k) >> 12) & 63) // theta node: next node on its route
#define LQ_OFF(k)    (((k) >> 18) & 255)// theta node: offset along the route
#define LQ_ROUTE(k)  (((k) >> 26) & 3)  // theta node: route 1..3
#define LQ_THETA(k)  ((k) >> 28)        // 1 for a theta node (bit 28)

// route lengths, and the shortest other route for each
#define LQ_L1      35
#define LQ_L2      27
#define LQ_L3      131

// The planner's state x and question/answer r. Both travel together as one 64-bit
// value q = (r << 32) | x, which lives in the register pair a0/a1 through every
// lq_node call (taking x or r out is just taking one of the two registers), so
// nothing has to be kept on the stack. All fields are reached with shifts and small
// masks only, so the compiler needs no large constants kept in registers either.
//   x: bits 0..3 = nodes in the path so far, bits 4..9 = c (the node asked about),
//      bits 10..15 = id of the goal g, bits 16..21 = id of the theta node a that
//      g's tree hangs off, bits 22..23 = a's route, bits 24..31 = a's offset
//   r: question "about c" = 0, answer = c's constant (always 4096 or more);
//      question "which child of c has g below it" = LQ_WHICH, answer = that child;
//      LQ_UP while going up from the goal (see lq_node)
#define LQ_WHICH   0xFFFFFFFFu
#define LQ_UP      1u
#define LQ_X(q)    ((uint32_t)(q))
#define LQ_R(q)    ((uint32_t)((q) >> 32))
#define LQ_Q(x, r) (((uint64_t)(r) << 32) | (uint32_t)(x))
#define LQ_N(x)    ((x) & 15)
#define LQ_C(x)    (((x) >> 4) & 63)
#define LQ_GID(x)  (((x) >> 10) & 63)
#define LQ_AID(x)  (((x) >> 16) & 63)
#define LQ_AROUTE(x) (((x) >> 22) & 3)
#define LQ_AOFF(x) ((x) >> 24)

// one node v; its constant k is put together from small numbers (each one fits in a
// single instruction, so the compiler keeps nothing between the calls):
//   question "about c" (r = 0):     if v is c, the answer is k
//   question "which child of c":    if v is a tree node whose parent is c and the goal
//                                   is below v, the answer is v
//   going up from the goal (r = LQ_UP; x: bits 4..9 = c, bits 10..15 = the goal's id
//   once known, bits 16..21 = the start node): if v is c, note the goal's id (the
//   first such node is the goal itself), then move c up to its parent; at the theta
//   node a, set up the walk instead: x gets a's id, route and offset, c = the start,
//   1 node in the path, and the next question is "about c"
static uint64_t lq_node(uint64_t q, uint32_t v, uint32_t id, uint32_t a, uint32_t b, uint32_t ro)
{
    uint32_t k = id | (a << 6) | (b << 12) | (ro << 18);   // the node's constant
    uint32_t x = LQ_X(q);
    uint32_t r = LQ_R(q);
    uint32_t c = LQ_C(x);
    uint32_t gid = LQ_GID(x);

    if (r == LQ_WHICH) {
        if (!LQ_THETA(k) && LQ_PARENT(k) == c && LQ_ID(k) <= gid && gid <= LQ_END(k)) {
            r = v;
        }
    } else if (v == c) {
        if (r == 0) {
            r = k;
        } else if (r == LQ_UP) {
            if (gid == 0) {
                gid = id;                   // the goal's id
            }
            if (!LQ_THETA(k)) {
                x = (x & ~0xFFFu) | (gid << 10) | (b << 4);         // up to the parent b
            } else {
                x = 1 | (LQ_AID(x) << 4) | (gid << 10) | (id << 16)
                  | (LQ_ROUTE(k) << 22) | (LQ_OFF(k) << 24);        // start the walk
                r = 0;
            }
        }
    }
    return LQ_Q(x, r);
}

// one pass over all 36 nodes: lq_node(q, node, id, a, b, route/offset)
//   tree node:  a = last id below it, b = parent, route/offset = 0
//   theta node: a = previous node, b = next node on its route (0 for the branch nodes),
//               route/offset = offset | route << 8 | 1 << 10
static uint64_t lq_nodes(uint64_t q)
{
    q = lq_node(q,  1,  1,  5,  4, 1285);  // N1  theta: route 1, offset 5
    q = lq_node(q,  2,  6,  6,  4,    0);  // N2  tree: below it ids 6..6, parent N4
    q = lq_node(q,  3,  3,  3,  6,    0);  // N3  tree: below it ids 3..3, parent N6
    q = lq_node(q,  4,  5,  1, 14, 1300);  // N4  theta: route 1, offset 20
    q = lq_node(q,  5,  7,  0,  0, 1536);  // N5  theta: branch node N5, offset 0
    q = lq_node(q,  6,  2,  3,  1,    0);  // N6  tree: below it ids 2..3, parent N1
    q = lq_node(q,  7,  8,  5, 15, 1547);  // N7  theta: route 2, offset 11
    q = lq_node(q,  8, 10,  5, 20, 1803);  // N8  theta: route 3, offset 11
    q = lq_node(q,  9, 12, 13, 11,    0);  // N9  tree: below it ids 12..13, parent N11
    q = lq_node(q, 10,  9,  9,  7,    0);  // N10 tree: below it ids 9..9, parent N7
    q = lq_node(q, 11, 11, 15,  8,    0);  // N11 tree: below it ids 11..15, parent N8
    q = lq_node(q, 12, 13, 13,  9,    0);  // N12 tree: below it ids 13..13, parent N9
    q = lq_node(q, 13, 16, 30, 14, 1918);  // N13 theta: route 3, offset 126
    q = lq_node(q, 14, 17,  0,  0, 1563);  // N14 theta: branch node N14, offset 27
    q = lq_node(q, 15, 18,  7, 14, 1558);  // N15 theta: route 2, offset 22
    q = lq_node(q, 16, 27, 28, 23,    0);  // N16 tree: below it ids 27..28, parent N23
    q = lq_node(q, 17, 28, 28, 16,    0);  // N17 tree: below it ids 28..28, parent N16
    q = lq_node(q, 18, 15, 15, 19,    0);  // N18 tree: below it ids 15..15, parent N19
    q = lq_node(q, 19, 14, 15, 11,    0);  // N19 tree: below it ids 14..15, parent N11
    q = lq_node(q, 20, 19,  8, 27, 1814);  // N20 theta: route 3, offset 22
    q = lq_node(q, 21, 20, 20, 20,    0);  // N21 tree: below it ids 20..20, parent N20
    q = lq_node(q, 22, 30, 30, 25,    0);  // N22 tree: below it ids 30..30, parent N25
    q = lq_node(q, 23, 26, 30, 26,    0);  // N23 tree: below it ids 26..30, parent N26
    q = lq_node(q, 24, 22, 22, 27,    0);  // N24 tree: below it ids 22..22, parent N27
    q = lq_node(q, 25, 29, 30, 23,    0);  // N25 tree: below it ids 29..30, parent N23
    q = lq_node(q, 26, 25, 30, 29,    0);  // N26 tree: below it ids 25..30, parent N29
    q = lq_node(q, 27, 21, 20, 29, 1825);  // N27 theta: route 3, offset 33
    q = lq_node(q, 28, 23, 32, 31, 1856);  // N28 theta: route 3, offset 64
    q = lq_node(q, 29, 24, 27, 32, 1836);  // N29 theta: route 3, offset 44
    q = lq_node(q, 30, 31, 35, 13, 1899);  // N30 theta: route 3, offset 107
    q = lq_node(q, 31, 33, 28, 35, 1861);  // N31 theta: route 3, offset 69
    q = lq_node(q, 32, 35, 29, 28, 1841);  // N32 theta: route 3, offset 49
    q = lq_node(q, 33, 32, 32, 30,    0);  // N33 tree: below it ids 32..32, parent N30
    q = lq_node(q, 34, 34, 34, 31,    0);  // N34 tree: below it ids 34..34, parent N31
    q = lq_node(q, 35, 36, 31, 30, 1880);  // N35 theta: route 3, offset 88
    q = lq_node(q, 36,  4,  4,  1,    0);  // N36 tree: below it ids 4..4, parent N1
    return q;
}

// Routes are 1 = binary 01, 2 = 10, 3 = 11, and are told apart with bit tests (i & 1,
// i & 2) rather than "i == 1": a compare with a number would make the compiler keep
// that number in a saved register.
//   length:               route 1 = 35, route 2 = 27, route 3 = 131
//   shortest other route: route 2 -> route 1 (35), routes 1 and 3 -> route 2 (27)
#define LQ_LEN(i)    (((i) & 2) ? (((i) & 1) ? LQ_L3 : LQ_L2) : LQ_L1)
#define LQ_OTHER(i)  (((i) & 1) ? LQ_L2 : LQ_L1)
// first and last node of route j (next to N5 and next to N14), and of its other route
#define LQ_FIRST(j)        (((j) & 2) ? (((j) & 1) ? 8 : 7) : 1)
#define LQ_LAST(j)         (((j) & 2) ? (((j) & 1) ? 13 : 15) : 4)
#define LQ_OTHER_FIRST(j)  (((j) & 1) ? 7 : 1)
#define LQ_OTHER_LAST(j)   (((j) & 1) ? 15 : 4)

// the first step from theta node c (constant k) towards theta node a (route j,
// offset ty), a != c
static uint32_t lq_theta_step(uint32_t k, uint32_t j, uint32_t ty)
{
    uint32_t i = LQ_ROUTE(k);
    uint32_t t = LQ_OFF(k);
    uint32_t li = LQ_LEN(i), lj = LQ_LEN(j);
    uint32_t mi = LQ_OTHER(i), mj = LQ_OTHER(j);
    uint32_t d5c, d14c, d5a, d14a, via5, via14, direct;

    if (LQ_PREV(k) == 0) {
        // c is a branch node: take a's route, or the shortest other route when going
        // round through the other branch node is shorter
        if (t == 0) {                       // N5
            return (ty <= mj + lj - ty) ? LQ_FIRST(j) : LQ_OTHER_FIRST(j);
        }
        return (lj - ty <= mj + ty) ? LQ_LAST(j) : LQ_OTHER_LAST(j);    // N14
    }

    d5c  = (t <= li - t + mi) ? t : li - t + mi;
    d14c = (li - t <= t + mi) ? li - t : t + mi;
    d5a  = (ty <= lj - ty + mj) ? ty : lj - ty + mj;
    d14a = (lj - ty <= ty + mj) ? lj - ty : ty + mj;
    via5  = d5c + d5a;
    via14 = d14c + d14a;

    if (i == j) {
        direct = (t < ty) ? ty - t : t - ty;
        if (direct <= via5 && direct <= via14) {
            return (t < ty) ? LQ_NEXT(k) : LQ_PREV(k);  // along the route
        }
    }
    if (via5 <= via14) {
        return (d5c == t) ? LQ_PREV(k) : LQ_NEXT(k);    // towards N5
    }
    return (d14c == li - t) ? LQ_NEXT(k) : LQ_PREV(k);  // towards N14
}

// Shortest path from start to goal (both 1..36), written to path[] as node numbers,
// start first. Returns the number of nodes.
// Each pass over the nodes (lq_nodes) answers one question: first the passes go up
// from the goal to the theta (inside lq_node), then the walk asks "about c" for the
// next step (or "which child of c" when going down a tree).
// (lq_nodes is called from one place only, so it is built into main.)
static uint8_t lq_plan(uint8_t path[], uint32_t start, uint32_t goal)
{
    uint64_t q;
    uint32_t x, k, nxt;

    path[0] = (uint8_t)start;
    if (start < 1 || start > LQ_NODES || goal < 1 || goal > LQ_NODES || start == goal) {
        return 1;                           // not a node number, or already there
    }

    q = LQ_Q((goal << 4) | (start << 16), LQ_UP);
    for (;;) {
        q = lq_nodes(q);
        x = LQ_X(q);
        k = LQ_R(q);

        if ((k >> 1) == 0) {
            continue;                       // k = LQ_UP or 0: no answer yet, ask again
        }
        if ((k >> 6) == 0) {
            nxt = k;                        // the child that has the goal below it
        } else if (LQ_ID(k) == LQ_GID(x)) {
            break;                          // c is the goal
        } else if (!LQ_THETA(k)) {
            // c is in a tree: down if the goal is below c, otherwise up
            if (LQ_ID(k) <= LQ_GID(x) && LQ_GID(x) <= LQ_END(k)) {
                q = LQ_Q(x, LQ_WHICH);
                continue;
            }
            nxt = LQ_PARENT(k);
        } else if (LQ_ID(k) == LQ_AID(x)) {
            q = LQ_Q(x, LQ_WHICH);          // the goal hangs below this theta node
            continue;
        } else {
            nxt = lq_theta_step(k, LQ_AROUTE(x), LQ_AOFF(x));
        }

        // one step: add nxt to the path and ask about it next
        path[LQ_N(x)] = (uint8_t)nxt;
        q = LQ_Q(x + ((nxt - LQ_C(x)) << 4) + 1, 0);
    }
    return (uint8_t)LQ_N(x);
}

// ##############################################

// main function
int main(int argc, char const *argv[]) {

    #ifdef __linux__

        if (argc < 4) {
            _put_str("usage: ./Path_Planner_Dec <current_node> <next_node> <is_encrypted>\n");
            _put_str("       current_node     : where the bot is, e.g. 35 (the start box)\n");
            _put_str("       is_encrypted = 0 : next_node is a node number, e.g. 7\n");
            _put_str("       is_encrypted = 1 : next_node is the encrypted code, 16 hex digits\n");
            return 1;
        }
        uint8_t  CURRENT_NODE        = atoi(argv[1]);
        uint8_t  IS_ENCRYPTED        = atoi(argv[3]);
        uint8_t  NEXT_NODE           = 0;
        uint32_t ENCRYPTED_HI        = 0;
        uint32_t ENCRYPTED_LO        = 0;
        if (IS_ENCRYPTED) {
            if (!read_block(argv[2], &ENCRYPTED_HI, &ENCRYPTED_LO)) {
                _put_str("with is_encrypted = 1, next_node must be exactly 16 hex digits\n");
                return 1;
            }
        }
        else {
            NEXT_NODE = atoi(argv[2]);
        }
        uint8_t MESSAGE_0           = 0;
        uint8_t MESSAGE_1           = 0;
        uint8_t MESSAGE_2           = 0;
        uint8_t MESSAGE_3           = 0;
        uint8_t MESSAGE_4           = 0;
        uint8_t NODE_POINT          = 0;
        uint8_t CPU_DONE            = 0;

    #else
        // Address value of variables are updated for RISC-V Implementation
        // inputs: 0x02000000 .. 0x0200000F
        #define ENCRYPTED_HI        (* (volatile uint32_t * ) 0x02000000)
        #define ENCRYPTED_LO        (* (volatile uint32_t * ) 0x02000004)
        #define IS_ENCRYPTED        (* (volatile uint8_t  * ) 0x02000008)
        #define NEXT_NODE           (* (volatile uint8_t  * ) 0x0200000c)
        #define CURRENT_NODE        (* (volatile uint8_t  * ) 0x0200000d)
        // outputs: 0x02000010 .. 0x0200001F
        #define MESSAGE_0           (* (volatile uint8_t  * ) 0x02000010)
        #define MESSAGE_1           (* (volatile uint8_t  * ) 0x02000011)
        #define MESSAGE_2           (* (volatile uint8_t  * ) 0x02000012)
        #define MESSAGE_3           (* (volatile uint8_t  * ) 0x02000013)
        #define MESSAGE_4           (* (volatile uint8_t  * ) 0x02000014)
        #define NODE_POINT          (* (volatile uint8_t  * ) 0x02000018)
        #define CPU_DONE            (* (volatile uint8_t  * ) 0x0200001c)

    #endif

    // read once here: for the next run, the program may write IS_ENCRYPTED = 0
    uint8_t is_encrypted = IS_ENCRYPTED;

    // the message: bytes 1..5 of the decrypted block (0x00 = no character)
    uint8_t message[5] = { 0, 0, 0, 0, 0 };

    // array to store the planned path
    uint8_t path_planned[40];
    // index to keep track of the path_planned array
    uint8_t idx = 0;

    uint8_t start_point = CURRENT_NODE;   // where the bot is
    uint8_t end_point   = 0;              // where the bot goes

    // ############# Add your code here #############

    // set path_planned[] and idx, message[] when is_encrypted = 1, and the
    // inputs for the next run (see Outputs at the top of this file)

    uint32_t lq_hi, lq_lo;                  // the decrypted code: bytes 0..3 and 4..7

    if (is_encrypted) {
        // decrypted code: byte 0 done flag, bytes 1..5 message, byte 6 next pick-up,
        // byte 7 drop
        lq_hi = ENCRYPTED_HI;
        lq_lo = ENCRYPTED_LO;
        LQ_DECRYPT(lq_hi, lq_lo);
        end_point = (uint8_t)(lq_lo);               // byte 7: drop node

        // start_point already holds this move's start, so the inputs for the
        // next move can be written now
        if ((uint8_t)(lq_hi >> 24) == 0) {          // byte 0: done flag 0, so write the next move
            IS_ENCRYPTED = 0;
            CURRENT_NODE = end_point;                   // the next move starts at the drop node
            NEXT_NODE    = (uint8_t)(lq_lo >> 8);       // byte 6: next pick-up node
        }
        // done flag 1: the inputs are left as they are
    }
    else {
        end_point = NEXT_NODE;                      // the inputs are left as they are
    }

    // the path from start_point to end_point
    idx = lq_plan(path_planned, start_point, end_point);

    // the message: decrypt again (see LQ_DECRYPT) instead of keeping the decrypted
    // code during the planning
    if (is_encrypted) {
        lq_hi = ENCRYPTED_HI;
        lq_lo = ENCRYPTED_LO;
        LQ_DECRYPT(lq_hi, lq_lo);
        message[0] = (uint8_t)(lq_hi >> 16);        // byte 1
        message[1] = (uint8_t)(lq_hi >> 8);         // byte 2
        message[2] = (uint8_t)(lq_hi);              // byte 3
        message[3] = (uint8_t)(lq_lo >> 24);        // byte 4
        message[4] = (uint8_t)(lq_lo >> 16);        // byte 5
    }

    // ##############################################

    // the message bytes are written into data memory (encrypted block only).
    if (is_encrypted) {
        MESSAGE_0 = message[0];
        MESSAGE_1 = message[1];
        MESSAGE_2 = message[2];
        MESSAGE_3 = message[3];
        MESSAGE_4 = message[4];
    }
    // the node values are written into data memory sequentially.
    for (int i = 0; i < idx; ++i) {
        NODE_POINT = path_planned[i];
    }
    // Path Planning Computation Done Flag
    CPU_DONE = 1;

    #ifdef __linux__    // for host pc: the output test.sh reads (see "Output (PC)" at the top)

        if (is_encrypted) {
            _put_str("Message : ");
            for (int i = 0; i < 5; ++i) {
                if (message[i]) _put_byte(message[i]);
            }
            _put_byte('\n');
        }
        for (int i = 0; i < idx; ++i) {
            _put_value(path_planned[i]);
        }
        if (is_encrypted) {
            if (IS_ENCRYPTED == 0) {            // the inputs written for the next run
                _put_str("Next current_node : ");
                _put_value(CURRENT_NODE);
                _put_str("Next next_node : ");
                _put_value(NEXT_NODE);
            }
            else {
                _put_str("Done\n");
            }
        }

    #endif

    return 0;
}