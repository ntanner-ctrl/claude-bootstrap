# Enforcement Patterns

How command descriptions are written to maximize Claude compliance.

---

## The Problem: The Description Trap

Claude reads skill descriptions and improvises based on them. If a description summarizes *what* a command does, Claude may attempt the workflow without actually invoking the command.

**Bad** (summary — Claude wings it):
```yaml
description: Full planning workflow wizard - walks through all stages
```

**Good** (trigger condition — Claude invokes the command):
```yaml
description: You MUST use this for ANY non-trivial implementation task. Skipping planning leads to confident mistakes.
```

Descriptions must contain ONLY trigger conditions. The actual workflow lives in the command body.

---

## Enforcement Tiers

| Tier | Pattern | When to Use | Example Opener |
|------|---------|-------------|----------------|
| **Safety-Critical** | `STOP. You MUST...` | Irreversible actions, deployments, pushes | `STOP. You MUST run this before ANY git push.` |
| **Process-Critical** | `You MUST use this for...` | Planning, specs, testing, quality gates | `You MUST use this for ANY non-trivial implementation.` |
| **Adversarial** | `REQUIRED after...` | Review stages, challenges, edge case probing | `REQUIRED after completing ANY spec or plan.` |
| **Specification** | `You MUST create this before...` | Agent/hook/component specs | `You MUST create this before implementing ANY new agent.` |
| **Utility** | `Use when...` | Tools, setup, documentation, info | `Use when setting up ANY new project.` |
| **Deprecated** | `DEPRECATED: Use X instead.` | Superseded commands | `DEPRECATED: Use /bootstrap-project instead.` |

---

## Rules

### 1. Description = Trigger Only

Descriptions state WHEN to use the command. Never summarize the workflow.

### 2. Opening Line Creates Obligation

The first word/phrase must signal urgency:
- `STOP.` — for safety-critical
- `You MUST` — for process-critical
- `REQUIRED` — for adversarial/review
- `Use when` — for utility

### 3. Consequence Statements

For MUST-level commands, state what happens if skipped:
```yaml
description: You MUST run this before ANY deployment. Security gaps caught here prevent breaches.
```

### 4. No Escape Hatches

Never use language that permits skipping:
- `consider using...`
- `you might want to...`
- `optionally...`
- `if you'd like...`

### 5. Scope Quantifiers

Use ALL-CAPS quantifiers to prevent narrow interpretation:
- `ANY` — covers all cases
- `ALWAYS` — no exceptions
- `BEFORE/AFTER` — sequence enforcement

---

## Validation

Run these checks on any new or modified command:

```bash
# No escape hatches in descriptions
grep -rn "^description:.*\(consider\|might\|optionally\)" commands/

# Enforcement coverage
grep -rn "^description:" commands/ | grep -ic "MUST\|REQUIRED\|STOP\|ALWAYS"
```

| Check | Pass Criteria |
|-------|---------------|
| Trigger-only | No workflow summary in description |
| MUST language | Present for process/safety/adversarial/spec tiers |
| No escape hatches | Zero matches for consider/might/optional |
| Consequence stated | Present for safety-critical commands |
| Scope quantifier | ANY/ALWAYS/BEFORE/AFTER present |

---

## Background

These patterns are informed by Cialdini's persuasion principles applied to LLM behavior:

| Principle | Application |
|-----------|-------------|
| **Authority** | MUST/REQUIRED language |
| **Commitment** | Announce skill usage before executing |
| **Social Proof** | "ALWAYS" implies universal practice |
| **Scarcity/Urgency** | STOP language for safety-critical |

See: [Jesse Vincent's analysis](https://blog.fsck.com/2025/10/09/superpowers/) of how Opus 4.5 processes descriptions.
