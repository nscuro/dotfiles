---
name: java-style
description: >-
  My default Java coding conventions. Use when writing, reviewing, or refactoring Java code,
  unless the repo you're working on defines its own style.
---

## Imports

Never use wildcard imports, not even for `static` imports. No exceptions.

Order:
  1. 3rd party libraries (sorted alphabetically)
  2. blank line
  3. `java.*`, `javax.*`, `jakarta.*` (sorted alphabetically)
  4. blank line
  5. static imports (sorted alphabetically)

## `var`

Only use the `var` keyword when the full type of the variable is obvious:

Do: `final var foo = new Foo();`, `final var foo = new ArrayList<String>();`

Don't: `final var foo = doStuff();`

## Immutability

Use `final` as default, and apply extensively to:
  * Classes that are not intended to be extended
  * Class fields (for fields that are never re-assigned after construction)
  * Local variables (including those using `var`, i.e. use `final var`)

Only omit `final` when there's a hard requirement to do so.

Do NOT use `final` for:
  * Methods
  * Method parameters

Return `List.copyOf(...)` / `Set.copyOf(...)` when handing out a collection backed by internal state.

## Control Flow

Prefer early returns to nesting. Handle the absent, invalid, and exceptional cases first, then let the main path run unindented at the method's base level.

* Guard at the top of the method, not around the body.
* In loops, `continue` on the skip condition instead of wrapping the body in an `if`.
* Never `else` after a block that returns or throws.
* Aim for at most two levels of nesting inside a method. A third is a signal to extract a method.
  
## Nullability

Use JSpecify annotations to declare nullability, if JSpecify is available in the project.
Suggest adding JSpecify if it's not yet available.

Every package must have a `package-info.java` file with `@NullMarked` annotation.
Never annotate with `@NonNull` (it's implied by package-level `@NullMarked`).

Indicate nullability by annotating fields and method parameters with `@Nullable`.

Prefer `@Nullable` over `Optional` for method parameters and return types.

Use `requireNonNull` to assert non-nullness in constructors and record compact constructors.
Always provide a message following the `<name> must not be null` pattern, e.g. `requireNonNull(foo, "foo must not be null");`.
Import statically from `java.util.Objects`.

## String Formatting

Use `"...".formatted(args)` over String concatenation and `String.format`.

String concatenation is only acceptable when the added value appears at the very beginning or very end, e.g. `"Hello, " + name` / `name + " says hello"`.

## Comments

Omit trivial comments that explain WHAT something does.
Use comments to explain WHY something is done.

## Javadoc

Only add Javadoc for public classes and methods, never private or package-private.

When the project uses Java 25 or newer, use the Markdown notation.

Use `@since` on public types and methods to indicate the version in which they were introduced.
If the project's current version is `5.1.0-SNAPSHOT`, `@since` should carry `5.1.0`.

## Exceptions

Throw `IllegalArgumentException` for bad input.
Throw `IllegalStateException` for bad state.

Always provide a message naming the offending value, or explaining the expected and actual state.

## Interruption

Never swallow `InterruptedException`. Never wrap-and-rethrow as unchecked exception. Suppressing interruptions is a correctness concern, not just a style preference.

Either restore interrupt flag via `Thread.currentThread().interrupt()`, optionally log, and return, OR let it bubble up.

## Testing

Use JUnit 5 (Jupiter) or later for new tests. Do not migrate existing tests using older JUnit versions or different testing frameworks.

### Test Naming

Test method names should follow the `<subject>Should<behavior>` format, where `subject` is the method being tested, e.g. `sayHelloShouldPrintHello`.
`<subject>` may be omitted when it's obvious, e.g. when the tested class only has one public method, or the test method is in a `@Nested` class that already states the subject.

### Assertions

Use AssertJ for fluent assertions with `assertThat`. Never use JUnit's `assertEquals` etc.

Use `assertThatExceptionOfType` over `assertThatThrownBy` to assert thrown exceptions.

### Asserting JSON

Use json-unit (`assertThatJson`) together with Java text blocks for JSON assertions.
Annotate JSON text blocks with `/* language=JSON */` for proper IDE syntax highlighting:

```java
assertThatJson(someJson).isEqualTo(/* language=JSON */ """
    {
      "foo": "bar"
    }
    """);
```

### Testing Async Code

Async tests must be deterministic under contention. Prefer, in order:

1. Drive the loop from the test. Package-private `processOnce()` / `drain()` instead of starting the background thread.
2. Inject `java.time.Clock`. Never `Instant.now()` in logic under test. Public constructor defaults to `Clock.systemUTC()`, package-private overload takes the clock. Tests advance a mutable `Clock` seeded with a fixed instant.
3. `CountDownLatch` for handoff. A gate latch to hold work, a signal latch to observe it. Always assert the result: `assertThat(started.await(5, TimeUnit.SECONDS)).isTrue()`. A bare `await` passes silently on timeout.
4. Awaitility, only for state you cannot observe directly: DB rows, meters, other threads.

Never `Thread.sleep` to wait. Only to deliberately park a thread inside a stub.

Awaitility:

* Always name the condition: `await("Workflow run to complete")`.
* Always bound with `atMost`: 5s, up to 30s with a real database or container.
* Prefer `untilAsserted(() -> assertThat(...))` over `until(booleanSupplier)`. Reports the actual value on timeout.
* Use `failFast(...)` when a wrong terminal state is detectable.
* Use `during(...)` + `atMost(...)` to assert something does not happen.
* Use `ignoreException(...)` for lookups that throw before the resource exists.

### Mocking

DO NOT USE MOCKING UNLESS ABSOLUTELY NECESSARY.
Mocking is a sign of code that was written without testing in mind. If you find yourself reaching for mocks, ask yourself how the code could be improved to remove the need for mocking entirely.

Prefer real implementations and in-memory providers. Use WireMock for HTTP boundaries and Testcontainers for databases, message brokers, and object storage, rather than mocking the client.
