# CSE 148 - Advanced Processor Architecture Design Class#
## Class Goals ##

In this class, you will design an advanced general-purpose processor that executes the MIPS ISA.  Your goal is to create a processor that executes a few target benchmarks as quickly as possible.  Everyone will start with the same baseline design (which executes the MIPS ISA correctly).  Because the benchmarks are fixed, instruction count is relatively fixed.  Therefore, your primary domains for improvement are CPI and cycle time.  CPI mostly.

You will work in groups of two.  You will be expected to implement a minimum of 4 architectural optimizations;  beyond that, you will be judged primarily on the design's novelty, and performance, as well as your analysis of the design.  We expect your choices to be driven more by performance than ease of implementation.

In addition, each group may also do at least one service project, possibly in lieu of one optimization. We'll discuss that further in class, and as service projects present themselves. Each group will do one topic presentation.  The presentation should be completed during the first half of the quarter, and the service project (if we do it) preferably earlier rather than later.

## Optimizations ##

The following optimizations are candidates for implementation in your design project:
0.  Caches (both instruction and data, or a unified).  This year, basic instruction and data caches are part of the baseline design, but you will be expected to fiddle with associativity, size, blocksize, etc. to optimize performance. However, this is not one of your 4 optimizations. You could also do an off-chip cache, I suppose, since the DE2 board has SRAM. That would be an optimziation.

1.  Cache optimizations (victim cache, pseudo-associative, …)

2.  A lockup-free cache can service hits (and possible misses) while waiting for a miss to return from memory.  With a lockup-free cache, the pipeline should stall on the use of data, not on a load miss.

3.  Superscalar execution.  Fetch, decode, execute multiple instructions per cycle.

4.  Superpipelining.  Run the clock at a rate that is roughly half the cycle time of the baseline (e.g., half of the ALU stage delay).

5.  Branch prediction.  

6.  Speculative execution.  Allow the pipeline to execute well beyond unresolved branches.  This  requires checkpointing (at least some) processor state at each branch, and a two-phase commit (write intermediate results to a buffer or pseudo register file).

7.  Register renaming.  Is this useful without out-of-order execution?

8.  Out-of-order execution.  Instructions issue to the execution units in an order different than they are fetched.

9.  Multithreading.  One pipeline with multiple program counters.  Instructions from multiple threads are mixed or interleaved on the pipeline.

10.  Multicore.  Multiple CPUs (pipelines) connected via a bus or interconnection network.

11.  Hardware prefetching (stream buffer).  Build a support hardware unit that observes the cache miss stream, recognizes patterns, and begins prefetching future misses.  

12.  Multi-path execution.  On some low-confidence branches, execute both targets of the branch.

13.  Runahead execution.  On a load miss, keep executing the instruction stream (just dropping stalled instructions).  This may cause a future miss to be initiated.  When the original load completes, you must recover back to the state following the load (similar to a branch mispredict recovery).

14.  Value prediction.  Identify instructions with predictable outcomes.  If the instruction is stalled, provide the predicted outcome and proceed.  Must be able to recover.  A similar technique is instruction reuse – if an instruction executes with the same inputs as a previous instance, provide the same output as before.  The latter is non-speculative, but only helps with multiple-cycle operations.

15.  Other ideas: feel free to ask us or do something unquestionably cool. 