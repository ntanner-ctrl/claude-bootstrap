---
description: You MUST use this when creating ANY new module or component. Generates files matching project conventions instead of guessing structure.
allowed-tools:
  - Read
  - Write
  - Glob
  - Bash
  - AskUserQuestion
---

# Module Scaffolder

Generate new modules, components, or features following project conventions.

## Arguments

Parse `$ARGUMENTS` for:
- Module type (if provided): `service`, `component`, `handler`, `model`, etc.
- Module name (if provided): Name of the new module

If not provided, use AskUserQuestion to gather interactively.

## Scaffolding Process

### Step 1: Detect Project Type

Identify the project's language and framework to determine scaffolding templates:

| Indicator | Project Type | Scaffold Templates |
|-----------|--------------|-------------------|
| `pyproject.toml`, `setup.py` | Python | service, model, handler, test |
| `package.json` + React | React | component, hook, context, test |
| `package.json` + Express | Node API | router, controller, middleware, model |
| `Cargo.toml` | Rust | module, struct, trait |
| `go.mod` | Go | package, handler, model |

### Step 2: Analyze Existing Patterns

Before generating, examine existing code to match patterns:

1. **Find similar modules:**
   ```bash
   # Find existing services/components/handlers
   find . -name "*_service.py" -o -name "*Service.ts" | head -5
   ```

2. **Analyze structure:**
   - File naming convention (snake_case, PascalCase, kebab-case)
   - Import patterns
   - Class vs function-based
   - Typing/annotation style

3. **Check for base classes or interfaces:**
   ```bash
   grep -r "class Base\|interface I" --include="*.py" --include="*.ts"
   ```

### Step 3: Gather Information

If not provided in arguments, ask:

```
What type of module do you want to create?
- [ ] Service (business logic)
- [ ] Component (UI element)
- [ ] Handler (request handler)
- [ ] Model (data model)
- [ ] Other (custom)

What should it be called? [name]
```

### Step 4: Generate Files

Based on project type and module type, generate appropriate files.

#### Python Service Template

**File:** `services/{name}_service.py`
```python
"""
{Name} service module.

Handles {description}.
"""
from dataclasses import dataclass
from typing import Optional

from .base_service import BaseService


@dataclass
class {Name}Config:
    """Configuration for {Name}Service."""
    # Add configuration fields here
    pass


class {Name}Service(BaseService):
    """
    {Description of what this service does}.

    Usage:
        service = {Name}Service(config)
        result = service.process(data)
    """

    def __init__(self, config: {Name}Config):
        self.config = config

    def process(self, data: dict) -> dict:
        """
        Process the input data.

        Args:
            data: Input data to process

        Returns:
            Processed result

        Raises:
            ValueError: If data is invalid
        """
        # TODO: Implement processing logic
        raise NotImplementedError()
```

**File:** `tests/test_{name}_service.py`
```python
"""Tests for {Name}Service."""
import pytest

from services.{name}_service import {Name}Service, {Name}Config


class Test{Name}Service:
    """Test cases for {Name}Service."""

    @pytest.fixture
    def service(self):
        """Create a service instance for testing."""
        config = {Name}Config()
        return {Name}Service(config)

    def test_process_valid_data(self, service):
        """Test processing with valid data."""
        # TODO: Implement test
        pass

    def test_process_invalid_data(self, service):
        """Test processing with invalid data raises ValueError."""
        # TODO: Implement test
        pass
```

#### React Component Template

**File:** `components/{Name}/{Name}.tsx`
```typescript
import React from 'react';
import styles from './{Name}.module.css';

export interface {Name}Props {
  /** Description of prop */
  // Add props here
}

/**
 * {Description of component}
 *
 * @example
 * <{Name} />
 */
export const {Name}: React.FC<{Name}Props> = (props) => {
  return (
    <div className={styles.container}>
      {/* TODO: Implement component */}
    </div>
  );
};

export default {Name};
```

**File:** `components/{Name}/{Name}.module.css`
```css
.container {
  /* TODO: Add styles */
}
```

**File:** `components/{Name}/{Name}.test.tsx`
```typescript
import { render, screen } from '@testing-library/react';
import { {Name} } from './{Name}';

describe('{Name}', () => {
  it('renders without crashing', () => {
    render(<{Name} />);
    // TODO: Add assertions
  });
});
```

**File:** `components/{Name}/index.ts`
```typescript
export { {Name} } from './{Name}';
export type { {Name}Props } from './{Name}';
```

#### Node Handler Template

**File:** `handlers/{name}.handler.ts`
```typescript
import { Request, Response, NextFunction } from 'express';

/**
 * Handle {name} requests.
 */
export const {name}Handler = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    // TODO: Implement handler logic
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
};
```

### Step 5: Update Imports/Exports

After generating files, update barrel exports if the project uses them:

```bash
# Check for index files that need updating
[ -f "services/index.py" ] && echo "Update services/index.py"
[ -f "components/index.ts" ] && echo "Update components/index.ts"
```

### Step 6: Report Results

```
## Scaffolding Complete

Created the following files:
- services/payment_service.py
- tests/test_payment_service.py

### Next Steps
1. Implement the TODO sections in the generated files
2. Add necessary imports to services/__init__.py
3. Write additional test cases

### Related Files
- services/base_service.py (base class)
- services/user_service.py (similar service for reference)
```

## Customization

When installed in a project, customize by:

1. **Add project-specific templates:**
   - Custom service patterns
   - Project-specific imports
   - Required boilerplate

2. **Configure naming conventions:**
   - File naming (snake_case vs PascalCase)
   - Class/function naming
   - Test file location

3. **Add post-generation hooks:**
   - Auto-format generated files
   - Run linting
   - Update import maps

---

$ARGUMENTS
