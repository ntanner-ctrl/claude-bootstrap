# Investigation: Maturity Assessment vs. Greenfield/Iteration

## Background

We already have a maturity assessment in `/bootstrap-project`:
- **Nascent** (0-3): New project, install full starter kit
- **Growing** (4-6): Established patterns, selective installation
- **Mature** (7-10): Complex project, suggest rather than install

Turkey-Build has two modes:
- **Greenfield**: Building new applications from scratch
- **Iteration**: Adding features to existing codebases

Both approaches try to solve the same problem: **"I don't know where your project is at."**

## Comparison

| Aspect | Our Maturity Assessment | Turkey-Build Modes |
|--------|------------------------|-------------------|
| **Dimensions** | 10-point scale based on signals | Binary: new vs existing |
| **Signals** | File count, commits, tests, CI, docs | Not specified |
| **Output** | Installation depth varies | Workflow mode changes |
| **Scope** | What to install | How to work |

## Analysis

### What We Do Better

**Nuanced Assessment**
Our 3-tier system (nascent/growing/mature) with 10-point scoring captures more nuance than a binary switch. A project with 50 commits but no tests is different from one with 5 commits and full test coverage.

**Signal-Based**
We look at concrete signals:
- File count
- Commit count
- Test presence
- CI presence
- Documentation quality
- Existing Claude setup

Turkey-Build doesn't specify how it determines greenfield vs. iteration.

**Installation Adaptation**
We adjust *what we install* based on maturity - nascent projects get full starter kits, mature projects get suggestions only.

### What Turkey-Build Does Better

**Workflow Mode**
Turkey-Build adjusts *how work happens*, not just what's installed:
- Greenfield: Build from scratch, full architecture design
- Iteration: Work within existing patterns, incremental changes

We don't change our *workflow* based on maturity. A nascent project and a mature project get the same `/plan` → `/spec-change` → `/implement` flow.

**Explicit Mode Setting**
Users can explicitly choose greenfield vs. iteration. Our assessment is automatic (which is good!) but not overridable (which is limiting).

### Gap: Workflow Adaptation

**The insight:** Maturity should affect not just what tools are available, but how those tools behave.

Example workflows that should differ:

| Activity | Nascent/Greenfield | Mature/Iteration |
|----------|-------------------|------------------|
| **Planning** | Full architecture exploration | Fit within existing patterns |
| **Design** | Create new patterns | Follow established patterns |
| **Review** | Validate fundamentals | Check for regression |
| **Testing** | Establish test patterns | Match existing test style |
| **Docs** | Generate comprehensive | Update incremental |

## Synthesis Opportunity

We could combine our signal-based assessment with workflow adaptation:

### Enhanced Maturity Modes

```
Mode 1: GREENFIELD (maturity 0-3)
  - Full architecture exploration expected
  - /plan asks about patterns to establish
  - /spec-change includes "precedent" section for decisions
  - More brainstorming, less pattern-following

Mode 2: ITERATION (maturity 4-7)
  - Work within established patterns
  - /plan references existing architecture
  - /spec-change asks "how does this fit existing patterns?"
  - Pattern compliance checking enabled

Mode 3: SURGICAL (maturity 8-10)
  - Minimal footprint changes
  - /plan emphasizes "what must NOT change"
  - /spec-change requires explicit scope bounding
  - Extra caution flags on broad changes
```

### Implementation Ideas

**1. Mode Detection**
Enhance `/bootstrap-project` to set a `project_mode` in manifest:

```json
{
  "maturity_score": 5,
  "project_mode": "iteration",
  "mode_overrides": {
    "user_selected": null,
    "reasons": ["50+ commits", "established test patterns"]
  }
}
```

**2. Mode-Aware Commands**
Commands read the mode and adapt prompts:

```markdown
# In /spec-change, add mode-aware section

## Mode: {{PROJECT_MODE}}

{{if mode == "greenfield"}}
### Precedent Establishment
This change may establish patterns for future development.
- Pattern being established: [describe]
- Rationale for this pattern: [explain]
- How future code should follow: [guidance]
{{endif}}

{{if mode == "iteration"}}
### Pattern Compliance
This change should fit existing patterns.
- Existing pattern followed: [reference]
- Any deviations: [explain if necessary]
- Pattern-breaking changes: [flag for extra review]
{{endif}}

{{if mode == "surgical"}}
### Scope Constraint
This change must be minimal and bounded.
- Explicit scope: [bounded description]
- What must NOT change: [critical invariants]
- Regression risks: [what to watch]
{{endif}}
```

**3. User Override**
Allow explicit mode selection:

```bash
/plan feature-auth --mode greenfield  # Override detected mode
```

**4. Per-Task Mode**
Even in mature codebases, some tasks are greenfield (new feature area). Allow task-level mode:

```bash
/describe-change "Add new analytics system" --mode greenfield
```

## Recommendation

**Short-term (Quick Win):**
- Add `project_mode` to bootstrap manifest
- Start with simple binary: `greenfield` vs `iteration`
- No workflow changes yet, just detection

**Medium-term (Priority 2-4 timeframe):**
- Add mode-aware sections to key commands
- Focus on `/spec-change` and `/plan` first
- Allow user override

**Long-term:**
- Full mode-adaptive workflows
- Per-task mode selection
- Pattern compliance checking for iteration mode

## Action Items

1. [ ] Add `project_mode` field to bootstrap manifest
2. [ ] Update `/bootstrap-project` to set mode based on maturity
3. [ ] Document mode definitions
4. [ ] Create mode-aware sections in `/spec-change` (as pilot)
5. [ ] Add `--mode` flag to planning commands
6. [ ] Test with actual greenfield vs iteration projects

## Conclusion

Our maturity assessment and Turkey-Build's modes are solving the same problem from different angles:
- We detect maturity well (signals)
- They adapt workflow well (modes)

The synthesis is: **Use our signals to determine their modes, then adapt our workflows.**

This becomes a Priority 1.5 - can be bundled with the Quick Wins since it's mostly metadata enhancement with gradual workflow integration.
