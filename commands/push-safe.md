# Safe Push with Secret Scanning

Stage, commit, and push with comprehensive safety checks.

## Instructions

### Step 1: Analyze Changes (parallel)
```bash
git status
git diff --stat
git log -1 --oneline
```

### Step 2: Safety Checks - STOP if any detected

**Secrets & Credentials:**
- `.env*` files (except `.env.example`)
- `*.key`, `*.pem`, `*.p12`, `*.pfx`, `*.cer`
- `credentials.json`, `secrets.yaml`, `id_rsa*`
- Files containing `API_KEY=`, `SECRET=`, `PASSWORD=` with real values
- AWS credentials, tokens, or connection strings

**Large/Binary Files:**
- Files >10MB without Git LFS configured
- Binary files that shouldn't be versioned

**Build Artifacts:**
- `node_modules/`, `dist/`, `build/`, `.next/`
- `__pycache__/`, `*.pyc`, `.venv/`, `venv/`
- `target/` (Rust/Java), `bin/`, `obj/`

**Temp/System Files:**
- `.DS_Store`, `Thumbs.db`, `*.swp`, `*.tmp`

**Other Warnings:**
- Pushing to `main`/`master` directly (warn, don't block)
- Merge conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)

### Step 3: Present Summary

```
## Changes to Commit
[List files with +/- stats]

## Safety Check Results
[Pass/Fail for each category]

## Proposed Commit Message
[type]: [description]

Proceed? (yes/no)
```

### Step 4: Execute (only after explicit "yes")

```bash
git add .
git commit -m "[Generated conventional commit message]"
git push
git log -1 --oneline --decorate
```

### Step 5: Confirm Success

Display commit hash, branch, and summary.

---

$ARGUMENTS
