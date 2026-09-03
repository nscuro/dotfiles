---
name: standards-research
description: >-
  Use before claiming industry standard, common practice, or spec/standards-body backing,
  before comparing a design against how other projects handle a similar problem,
  and whenever the user pushes back asking for more evidence or sources.
---

# Standards & prior-art research

Do this before the first draft of a recommendation or the first line of code, not after being asked to dig deeper.
Primary text, multiple independent implementations, and verbatim citations resolve this every time, so start there.

## 1. Classify the claim before researching

State explicitly which of these you're answering. Don't blur them.

- Normative spec or RFC text: a MUST or SHALL in the actual standard.
- Authoritative guidance that isn't a formal standard: a government agency's document,
  a vetted cheat sheet from a subject-matter organization, an official style guide.
  Check who actually published it, an official-sounding name doesn't mean it came from a standards body.
- De facto or real-world practice: what real tools and implementations actually do,
  which may diverge from or exceed the formal spec.

A blog post by a spec author, maintainer, or contributor, however credible, is a lead to verify, not any of the above.
Treat it as unverified until checked against a primary source, and note its age. An old post may predate a later spec revision.

## 2. Go to the primary source first, every time

Fetch the actual spec, schema, RFC, or standards-body text yourself.
Quote the specific clause verbatim with a link or anchor. **Don't paraphrase from memory and check later**.

For a data or wire format, check the schema or grammar itself, not just prose docs.

If the artifact defines an algorithm or decision procedure, extract it as pseudocode or a direct quote before
writing or reviewing any implementation against it. If a second question keeps invalidating the first answer,
that's the signal you skipped this step. Stop patching and get the algorithm.

## 3. Weigh implementations by standing, not convenience

Read the actual source of two or three independent implementations, not their docs and not your memory of them.
Each one must be either well-known and widely used, or an official or reference implementation of the spec in question.
A random unmaintained repo, however convenient to find, is not evidence of anything; drop it rather than cite it.

If the implementations disagree, say so and explain why. Convergence across independent,
qualifying implementations is stronger evidence than any single one, and often stronger than an ambiguous spec passage.

For "how do people actually use this" questions, as opposed to "what does the format allow" questions,
pull a real sample large enough to be representative: actual documents, records, or configs. State the sample size and source.

When comparing a design against how other projects handle a similar problem, they don't need to be competitors,
adjacent or entirely unrelated projects count as long as they solve the same underlying problem
(e.g. Keycloak for an auth question, a build tool for a caching question). Read the actual source, config defaults,
or commit history, not the marketing page. Rule out non-comparable designs explicitly and say why.

If you can't find real-world precedent for a design you're about to recommend or already built, say so plainly.
Absence of precedent in an ecosystem that would otherwise document and imitate a working pattern is itself a signal,
not a formality to note and move past.

Citing the user's own implementation as industry precedent is **not valid**.

## 4. Check how it actually worked out

An implementation existing is not proof the approach is sound; it may be there because nobody has hit its edge cases yet,
or because it was already fixed once and quietly regressed. Before treating an implementation as evidence for a design,
check its issue tracker for bug reports against the behavior you're citing, its commit history for fixes, reverts,
or rewrites of that logic, and any discussion threads (RFC comments, design docs, mailing lists) where the approach itself was debated.
A design that shipped, broke, and got patched twice is weaker evidence than one nobody has ever filed a bug against,
even if both currently produce the same output.

## 5. Check currency

A cited repo or doc may be stale or archived while the current or commercial product has diverged.
Check the last commit date or version before treating something as representative of current behavior,
and flag it explicitly when you can't rule this out.

## 6. Cite inline, every claim, no exceptions

A spec claim gets a URL and the quoted clause. A source-code claim gets file:line, from code opened this turn.
A real-world claim gets its sample size and source. Never name a specific tool or company as doing something without
a citation fetched this turn; if you can't find one, say "recalled but unverified" instead of asserting it as fact.

## 7. Report format

Use this structure every time, so a skipped pillar is visible instead of buried in prose.
Keep a section even when it's empty, and say why: "no formal spec covers this" is a finding, not a gap to hide.

```
## Spec
[verbatim clause + link, or "no formal spec covers this"]

## Real-world practice
[implementation]: [what it does] — [well-known/reference | recalled, unverified]
[implementation]: ...
[agreement / disagreement across them]

## How it held up
[bugs/reverts/discussion found against the cited behavior, or "none found"]

## Divergence
[where spec and practice disagree, if they do]

## Recommendation
[the call, and which section above it rests on]
```

## 8. Self-check before presenting a verdict as final

- Did I rely on a single example to generalize? Find two more.
- Did I cite an implementation just because it was easy to find? Replace it with a well-known or authoritative one.
- Did I cite an implementation without checking whether its approach ever broke or got reworked? Check its issues and commit history before relying on it.
- Did I answer anything from memory? Fetch the current primary source instead.
- Would "you didn't check what other tools actually do" be a fair criticism of this answer right now? If yes, it's not done.
