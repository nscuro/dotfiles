---
name: java-profile
description: >-
  Find out *where* a Java workload spends CPU or allocates memory, using async-profiler.
  Use when asked to profile Java code, find a hot method, find what allocates, explain why a
  test/benchmark/app is slow. Not for "did my change make it faster".
---

Answers "where does it go", never "how fast is it".

For before/after numbers, **count operations, not milliseconds**: queries, round trips, rows
written, objects allocated. Counters are exact and reproducible. Wall-clock timings drift enough
between runs to hide the effect you are chasing, worst of all on I/O-bound or container-backed
workloads.

## 0. Locate the agent

```sh
# 1. Tarball, any OS. asprof is on PATH and the lib sits beside it.
command -v asprof >/dev/null &&
  ASPROF_LIB="$(dirname "$(readlink -f "$(command -v asprof)")")/../lib/libasyncProfiler.so"

# 2. Homebrew, only if brew is actually installed.
[ -f "${ASPROF_LIB:-}" ] || { command -v brew >/dev/null &&
  ASPROF_LIB=$(ls "$(brew --prefix async-profiler 2>/dev/null)"/lib/libasyncProfiler.* 2>/dev/null | head -1); }

[ -f "${ASPROF_LIB:-}" ] || echo "async-profiler not found"
```

Those two checks are the whole search. **Never sweep the filesystem with `find`**, and do not guess
at paths like `/opt/async-profiler`.

If neither check hits, **stop and ask the user to install or configure async-profiler**, then wait.
**Never install it yourself**, not with `brew install async-profiler`, not from
https://github.com/async-profiler/async-profiler/releases. If they already have it somewhere
unusual, ask them for the path to `libasyncProfiler.so` and use that.

## 1. Pick the event

| Goal | Options |
| --- | --- |
| CPU, Linux | `event=cpu,interval=1ms` |
| CPU, macOS | `event=itimer,interval=1ms,cstack=dwarf`, the only engine, see caveat 5 |
| Allocation | `event=alloc,alloc=64k,total`, where `total` makes the counter **bytes** |
| Leaks | add `live` to the alloc options |
| Blocked, not busy | `event=wall,interval=5ms`, read caveat 7 before quoting its numbers |
| Lock contention | `event=lock,lock=1ms` |
| Native/off-heap allocation | `event=nativemem,nativemem=1m`, for JNI and direct buffers |

`event=cpu` uses `perf_events`. When the kernel blocks it, async-profiler falls back to `ctimer`
on its own, so there is nothing to do, but you lose kernel stacks. It also opens one file
descriptor per thread, which exhausts the limit on thread-heavy apps, and it silently truncates
stacks deeper than `kernel.perf_event_max_stack`, 127 by default.

Canonical option string, with event-specific bits from the table appended:

```
start,collapsed,dot,norm,loglevel=none,file=/tmp/prof-%p.txt,<event opts>
```

| Flag | Why |
| --- | --- |
| `collapsed` | one line per stack plus counter, diffable and greppable |
| `dot` | readable class names |
| `norm` | strips unstable lambda suffixes, required to diff two runs |
| `loglevel=none` | required under surefire, the startup banner corrupts the fork channel |
| `%p` | forked JVMs would otherwise clobber each other |

async-profiler writes the file on JVM exit, once per fork, so a reused surefire fork yields
one file.

**Both events in one run.** Swap `collapsed` for `jfr`, list both events, split afterwards. Worth
it whenever the workload is slow to set up, but **the CPU half is then wrong**. The allocation
sampler runs on the sampled thread, so its own work is charged to the CPU profile. It surfaces as
a native leaf, `thread_self_trap` on macOS, whose `HOT_DEPTH=2` caller is
`ObjectSampler::recordAllocation`. The share grows with allocation rate and reaches tens of
percent of a busy thread. The alloc half is unaffected. Use the combined run to find what
allocates, then re-run CPU-only before quoting a CPU number.

```
start,jfr,event=itimer,interval=1ms,alloc=64k,cstack=dwarf,loglevel=none,file=/tmp/prof-%p.jfr
```

```sh
jfrconv --cpu   --dot --norm --total -o collapsed /tmp/prof-1234.jfr cpu.txt
jfrconv --alloc --dot --norm --total -o collapsed /tmp/prof-1234.jfr alloc.txt
```

`jfrconv` ships next to `asprof`. Both outputs are ordinary `collapsed` files.

## 2. Run the workload

**Isolate the behavior in its own driver first.** Profile something that runs only the code in
question, in a loop, with setup hoisted out of the loop. Point the profiler at the nearest
existing test instead and its fixtures, its assertions and the framework land in the profile too,
where they usually outweigh what you came for.

A single-file source program is the cheapest driver, and on **Java 25 there is no `javac` step**,
`java ProfDriver.java` compiles and runs it in one command. Give it a `main` that loads the input
once, then loops the call under test. `com.sun.tools.javac.launcher.SourceLauncher` frames in the
result confirm you profiled the driver and not something else.

**Size the loop for ~2000 samples on the method under test**, not on its thread and not on the
JVM. Attribute with `tree.sh` before reading anything else, and raise the iteration count when
the method's own count falls short.

When the code needs the application's wiring, write a test that exercises that one path and
nothing else. **Set its configuration defaults to the production ones.** Test wiring commonly
leaves pooling, caching and batching off, and each one turns work the production path amortises
into per-call setup that outranks the code under test. Read the defaults, do not assume them.

**Add `-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints` alongside the agent**, in the same
`JAVA_TOOL_OPTIONS` string. Without them the JVM only records safepoint-accurate locations, so
samples land on the wrong line and inlined frames go missing. Costs nothing, and the profile is
wrong in ways you cannot detect without it.

**Maven.** Inject through `JAVA_TOOL_OPTIONS`, not `-DargLine`. It leaves the pom's own argLine
intact, so there is nothing to copy across. It also carries `-D` system properties into the fork,
so a driver's iteration count is a flag rather than an edit.

**`MAVEN_ARGS` carries Maven's own flags**, so a wrapper that hardcodes its goals still takes
`-Djacoco.skip=true` and `-pl`. Use it instead of abandoning the project's build script.

```sh
MAVEN_ARGS="-Djacoco.skip=true" JAVA_TOOL_OPTIONS="-agentpath:..." make test-single TEST=FooTest
```

**`JAVA_TOOL_OPTIONS` does not reach `mvnd`.** The daemon JVM is already running and the surefire
fork inherits the daemon's environment, not your shell's. The build goes green and writes no
profile file, the same symptom as the argLine trap below. Run plain `mvn`, and override the
wrapper when one picks the daemon for you, `make test-single MVND=mvn`.

```sh
JAVA_TOOL_OPTIONS="-agentpath:$ASPROF_LIB=start,event=alloc,alloc=64k,total,collapsed,dot,norm,loglevel=none,file=/tmp/prof-%p.txt" \
  mvn test -Dtest=FooTest#bar -Djacoco.skip=true
```

`-DargLine` loses to an explicit `<argLine>` element, and jacoco owns the `argLine` property, which
`-Djacoco.skip=true` sets to empty. **Symptom: build succeeds, test runs, no profile file**, and
nothing warns you. `-Djacoco.propertyName=...` is not a fix, it leaves `@{argLine}` unresolved and
the fork dies on a literal `@{argLine}` argument.

In a multi-module reactor, add `-pl <module> -am`. Without it Maven fails on sibling modules that
were never installed to the local repository, before the profiler runs at all.

`JAVA_TOOL_OPTIONS` reaches every JVM the build starts: Maven itself, codegen plugin forks, the
surefire fork, and with `-am` the forks of every upstream module too. Keep `%p` and pick the right
file by content, not by size.

```sh
grep -lF 'YourTestClass' /tmp/prof-*.txt
```

**In `jfr` mode that grep finds nothing**, the recording is binary. Convert each candidate with
`jfrconv --cpu -o collapsed`, then grep the output.

**Gradle.** No CLI flag for test JVM args, so inject an init script instead of editing the build.

```sh
cat > /tmp/prof.init.gradle <<EOF
allprojects { tasks.withType(Test).configureEach {
  jvmArgs "-agentpath:$ASPROF_LIB=start,event=alloc,alloc=64k,total,collapsed,dot,norm,loglevel=none,file=/tmp/prof-%p.txt"
  extensions.findByName('jacoco')?.enabled = false
} }
EOF
./gradlew test --tests 'FooTest' -I /tmp/prof.init.gradle
```

**Plain JVM.** `java -agentpath:$ASPROF_LIB=start,... -cp ... Main`, and the same flag works
ahead of a `.java` file: `java -agentpath:... -cp app.jar ProfDriver.java`.

**Already-running JVM.** No restart, profile the real symptom while it happens.

```sh
asprof -e alloc --alloc 64k --total -o collapsed -d 20 -f /tmp/prof.txt $(jcmd -l | grep MyApp | cut -d' ' -f1)
```

## 3. Read it

```sh
./hot.sh /tmp/prof.txt 25                 # top 25 self frames, what is hot
TREE_PKG=org.foo ./tree.sh /tmp/prof.txt  # who owns the cost, your code only
./tree.sh /tmp/prof.txt processBom        # where processBom's total went, by direct child
HOT_DEPTH=2 ./hot.sh /tmp/alloc.txt       # aggregate by caller, not leaf
./hot.sh before.txt after.txt             # what changed, by share of each total
grep -c . /tmp/prof.txt                   # distinct stacks
```

`hot.sh` answers which frame burns the samples. That is rarely the question. **`tree.sh` answers
which part of your code owns the cost.** Start at the entry point and walk down child by child until the
number stops moving. Two or three steps usually land on the answer.

Inclusive mode ranks framework and wrapper frames at the top by construction, since every `main`,
`Thread.run` and reflection hop encloses everything. **Always pass `TREE_PKG`.** It keeps only
frames containing that string and leaves the percentages relative to the whole profile. Bare
`tree.sh FILE N` is for when you do not yet know which packages are in play.

`tree.sh FILE FRAME` matches a whole frame or its trailing `.method`, so `processBom` will not
answer with `processBomAsync`'s children. When nothing matches that way it falls back to a
substring match and says so on stderr, your cue that the number is about something else.

One method can occupy several consecutive frames in a stack, `Foo.bar_[i]` sitting above
`Foo.bar_[j]`, when the JIT inlined it into itself. Both views collapse those, so a hot method
never reports itself as its own child or splits across two rows by annotation. The row keeps the
first annotation it was seen with, which is enough for the `_[0]` warmup check in caveat 2.

To restrict any view to one subtree, filter first. Both scripts read `/dev/stdin`.

```sh
grep -F 'processComponents' /tmp/alloc.txt | HOT_DEPTH=2 ./hot.sh /dev/stdin
```

**Split by thread before trusting any total.** A cold JVM routinely spends more CPU in JIT compiler
threads than in the workload, and a JVM total blends them silently.

```sh
jfrconv --cpu --dot --norm --total -t -o collapsed /tmp/prof-1234.jfr cpu-t.txt
./threads.sh cpu-t.txt                   # per-thread totals, biggest first
./threads.sh cpu-t.txt main > main.txt   # that thread's stacks, prefix stripped
./threads.sh cpu-t.txt '[main]'          # the label the totals view prints also works
```

Totals roll up by name, so a nine-thread GC pool is one row instead of nine that each look
negligible, and the filter matches by name too. The tid changes every run. `main.txt` is an
ordinary `collapsed` file. If the compiler threads are the ones burning CPU, `-F comptask` names
the method each one is compiling.

**In an `alloc` profile the leaf frame is the allocated type**, `byte[]` or `java.lang.String`, not
the allocation site. The default view tells you what is allocated, `HOT_DEPTH=2` tells you who
allocates it. The second is the one you can act on.

`[no_Java_frame]` and `[unknown_Java]` mean the sample landed in the JVM itself (GC, class loading,
JIT) or in native code with no walkable Java stack. A few percent is normal. A majority means the
stacks are context-free, not that the work is unattributable. Fix the unwinder first, see caveat 5.

For **who calls the hot frame**, grep the raw file. Callers are the frames to its left.

```sh
grep 'HashMap.resize' /tmp/prof.txt | sort -t' ' -k2 -rn | head
```

## 4. Before believing the profile

1. **Under ~2000 samples is noise.** Count them on the thread you care about, not the JVM total.
   Lower the interval, or loop the workload.
2. **A 200ms unit test profiles class loading, not your code.** To confirm the JVM warmed up,
   add `ann`. Many `_[0]` frames means interpreted, so you profiled the
   wrong thing. With persistent state (a database, a cache, a filesystem) a naive loop profiles a
   *different* code path, since iteration 2 updates what iteration 1 inserted. Give each iteration
   fresh state, expect drift as the datastore grows, and report steady-state iterations only.
3. **`alloc` counts allocation, not retention.** High churn is not a leak. Use `live` for leaks.
4. **Coverage and mocking agents dominate profiles.** Turn jacoco off, and be suspicious of
   `net.bytebuddy` or `org.mockito` frames near the top.
5. **macOS CPU needs `cstack=dwarf`.** `itimer` is the only engine, and with `cstack=no` a
   syscall-heavy workload puts 60%+ of samples in `[no_Java_frame]`. `cstack=dwarf` recovers the
   native frames and keeps every Java frame, and those native leaves are often the finding. It is
   costlier and can be fragile on deeply mixed stacks, so fall back only if it misbehaves. `wall`
   is not a substitute, it adds idle GC and reference-handler threads. If `[no_Java_frame]` still
   dominates, use `alloc`, accurate everywhere, or re-run on Linux with `event=cpu`.
6. **When you do profile a test, the harness is in there with it.** Attribute against the method
   under test with `tree.sh`, never against the JVM total, and say which share was harness when
   reporting.
7. **A `wall` profile distorts what it measures and never sizes a fix.** Sampling every thread at
   5ms slows the workload, so its absolute numbers do not compare to an unprofiled run.
   An inclusive wall percentage is not a saving either. "56% of wall" does not mean removing it
   returns 56%. Use `wall` to find where it blocks, a socket, a lock, a disk, then size the fix by
   counting operations.
8. **The profiler's own unwinding shows up as hot frames.** `vframe::sender`,
   `RegisterMap::RegisterMap`, `Method::jmethod_id` and `InstanceKlass::get_jmethod_id` near the
   top of a `hot.sh` list are async-profiler walking interpreted frames, 5-10% on a cold or
   loop-free run. Discount them. A large share means warm the JVM up (caveat 2), not optimize them.
