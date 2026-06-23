This is a from-scratch Verilog implementation of an asynchronous FIFO that safely transfers data between two independent, unrelated clock domains. Built and verified entirely in simulation (Icarus Verilog via EDA Playground), with a self-checking testbench and a real debugged race condition.
Overview

A FIFO (First-In-First-Out buffer) is straightforward to design when both the write side and the read side share a single clock. It becomes a genuinely hard problem the moment the write side and read side run on two separate, unrelated clocks, which is the normal situation in real systems (e.g. a sensor running at its own clock feeding data into a processor running at a completely different frequency).

This project implements that harder version: an asynchronous FIFO with explicit Clock Domain Crossing (CDC) handling, using the two techniques that make it safe:- Gray-code pointers and 2-flop synchronizers and verifies it with a testbench.
Specifications:
Data width: 8 bits (parameterizable)
Depth: 16 entries (parameterizable, must be a power of 2)
Write clock: 6 ns period
Read clock: 10 ns period (deliberately different from the write clock, to exercise CDC)
Synchronizer depth: 2 flip-flop stages

#Top level Modules:
1. dual_port_ram: the actual data storage written on wr_clk read on rd_clk.
2. gray_counter: instantiated twice (write pointer, read pointer); produces both a normal binary value (for memory addressing) and a Gray-coded value (for safely crossing clock domains)
3. synchronizer: instantiated twice (write pointer into the read domain, read pointer into the write domain); the 2-flop CDC mechanism
4. async_fifo: top-level module wiring everything together and generating full/empty

#Theory and Concepts:
1. Clock Domain Crossing and Metastability:- When a signal generated in one clock domain is sampled by a flip-flop in a different, unrelated clock domain, there's no guaranteed timing relationship between when the signal changes and when the sampling clock ticks. Occasionally, the signal will change during the flip-flop's setup/hold window.
When that happens, the flip-flop's output can enter a metastable state- neither a clean 0 nor a clean 1- for an unpredictable amount of time before settling to one value or the other. This isn't a design flaw; it's a fundamental property of sampling an asynchronous signal, and it cannot be "fixed" by clever logic, only managed.
The fix: a 2-flop synchronizer. Instead of using the sampled value immediately, it's passed through a second flip-flop on the same destination clock. stage1 absorbs the risky sample and is never read by anything else. By the time sync_out samples stage1, a full clock period has passed for any metastability to have resolved. This costs exactly 2 destination-clock cycles of latency, which the rest of the FIFO is designed around.

2. Gray Code Pointers:- A 2-flop synchronizer protects a single bit from metastability. The write and read pointers, however, are multi-bit values. A plain binary counter can change multiple bits at once between consecutive values- for example, 3 -> 4 is 011 -> 100, all three bits flipping simultaneously.
If a multi-bit signal like that is sampled mid-transition by an unrelated clock, different bits can be caught on different sides of the transition, producing a sampled value that doesn't resemble either the old or new value.
The fix: A Gray-coded counter is sequenced so that only one bit ever changes per increment. Because only one bit changes at a time, the worst a bad sample can produce is either the old value or the new value and never anything in between. This guarantees the synchronized pointer is always a valid pointer value, even if it's momentarily one step behind.


#Bug Found and Fixed

During the self-checking random testbench phase, the scoreboard reported reads exceeding writes- a physical impossibility for a FIFO (Total reads: 97 vs. Total writes: 88), along with Errors: 88.

Diagnosis: the mismatch pattern showed the same got/expected pair printed twice in a row on consecutive read cycles- a strong signal that the reference model and the DUT had briefly disagreed about whether a given clock edge counted as a real read. The root cause was a zero-delay race condition: stimulus was assigned immediately after @(posedge clk) with a blocking assignment, at the exact same simulation time step as the DUT's internal logic and the scoreboard's own clocked blocks. Verilog does not guarantee evaluation order between blocks triggered by the same edge, so some edges had the DUT sampling the old enable value while the reference model sampled the new one (or vice versa).

Adding a 1-time-unit delay ensures the new stimulus value only becomes visible after the current edge has been fully processed by every block triggered by it, removing the ambiguity entirely. After this fix, the testbench passed cleanly with zero mismatches across repeated runs.
