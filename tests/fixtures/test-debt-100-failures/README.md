# test-debt-100-failures fixture

Synthetic pytest fixture used to verify AC11 of the test-debt-in-prism blueprint:
the `test-debt-classifier` subagent's return-message must be ≤ 2K tokens
(≈ 1500-word proxy) regardless of test suite size.

## Layout

```
tests/fixtures/test-debt-100-failures/
├── README.md          (this file)
├── generate.sh        (deterministic regeneration script)
├── pytest.ini         (minimal pytest config; triggers runner detection)
└── test_synthetic.py  (100 failing test functions across 5 categories)
```

## How AC11 uses it

The verification flow:

1. Dispatch `test-debt-classifier` against this fixture
2. Capture the agent's final return-message
3. `wc -w` the message body
4. Assert: word count ≤ 1500

This is a measurable approximation of the 2K-token bound. If the bound becomes
contested, swap in a token counter. For AC11 verification, word-count is sufficient.

## Why 100 failures across 5 categories

The fixture exercises the prompt-level prioritization rule in the agent
(top-50 + count-summary line if total exceeds the bound). With 100 failures
spread across 5 categories of 20 each, the agent must:

- classify each failure into exactly one category
- order findings by severity
- truncate within the 2K-token bound
- emit a `truncated: true` count-summary if it had to drop findings

If the agent's output exceeds 1500 words, the prompt's truncation logic is broken —
that's exactly what AC11 catches.

## Regeneration

```bash
cd tests/fixtures/test-debt-100-failures
bash generate.sh
```

The generator is deterministic — running it produces byte-identical output every time.
The committed `pytest.ini` and `test_synthetic.py` are the canonical state.
