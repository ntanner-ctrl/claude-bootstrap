---
description: Use BEFORE implementing any feature with unclear boundaries. Catches missing prerequisites.
arguments:
  - name: feature
    description: Feature or task to check prerequisites for
    required: false
---

# Pre-Implementation Design Check

Verify prerequisites are met BEFORE writing code. Catches the gaps that lead to mid-implementation rewrites.

## When to Use

- Starting a new feature (especially if requirements came verbally)
- Requirements feel "obvious" but haven't been written down
- Multiple components will be involved
- You're about to say "I'll figure it out as I go"

## Checklist

Run through each item. If ANY answer is "unclear" or "not decided", STOP and resolve before coding.

### 1. Requirements Clear?

```
Can you state the acceptance criteria as testable assertions?

  [ ] I can write "Given X, when Y, then Z" for each behavior
  [ ] Edge cases are identified (empty, null, max, concurrent)
  [ ] Error cases are defined (what happens when things fail?)
  [ ] "Done" is unambiguous (no "and also..." after implementation)
```

If unclear: Write acceptance criteria now, or ask the user.

### 2. Architecture Decided?

```
Which components are involved and how do they interact?

  [ ] Components identified (which modules/services touched)
  [ ] Data flow mapped (where does data enter, transform, exit?)
  [ ] Dependencies clear (what does this depend on? what depends on this?)
  [ ] No circular dependencies introduced
```

If unclear: Sketch the component diagram before proceeding.

### 3. Interfaces Defined?

```
What are the inputs, outputs, and errors for each boundary?

  [ ] Function signatures decided (params, return types)
  [ ] API contracts defined (request/response shapes)
  [ ] Error types enumerated (what can go wrong, what caller sees)
  [ ] Validation rules stated (what's valid input?)
```

If unclear: Define interfaces first — implementation follows from interfaces.

### 4. Error Strategy?

```
What happens when things fail?

  [ ] Failure modes identified (network, auth, validation, data)
  [ ] Recovery strategy per mode (retry, fallback, propagate, abort)
  [ ] User-facing messages defined (not stack traces)
  [ ] Partial failure handling (what if step 3 of 5 fails?)
```

If unclear: Decide error strategy before implementing the happy path.

### 5. Data Structures?

```
What represents the domain?

  [ ] Core entities identified (what are the "nouns"?)
  [ ] Relationships mapped (one-to-many, ownership, references)
  [ ] Mutability decided (what changes? what's immutable?)
  [ ] Serialization considered (how does it persist/transmit?)
```

If unclear: Model the data before writing logic.

### 6. Key Algorithms?

```
Is the core logic identified?

  [ ] Main algorithm sketched (not code — just the approach)
  [ ] Performance characteristics known (O(n)? O(n²)? acceptable?)
  [ ] Concurrency needs identified (parallel? sequential? locked?)
  [ ] Existing solutions checked (library? built-in? pattern?)
```

If unclear: Pseudocode the algorithm before implementing.

## Output

Display results:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DESIGN CHECK │ [feature]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. Requirements:  [CLEAR / GAPS: list]
  2. Architecture:  [CLEAR / GAPS: list]
  3. Interfaces:    [CLEAR / GAPS: list]
  4. Error Strategy: [CLEAR / GAPS: list]
  5. Data Structures: [CLEAR / GAPS: list]
  6. Algorithms:    [CLEAR / GAPS: list]

  Verdict: [READY / BLOCKED on items N, N]

  [If BLOCKED:]
  Resolve these before implementing:
    - [gap 1]: [suggested action]
    - [gap 2]: [suggested action]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Integration

- Use `/blueprint` for full planning workflow (includes this as a phase check)
- Use `/spec-change` to formalize requirements identified here
- Use `/edge-cases` to probe boundaries identified in step 1
