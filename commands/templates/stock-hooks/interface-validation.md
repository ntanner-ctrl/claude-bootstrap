---
name: interface-validation
description: Template hook for validating that modules follow a consistent interface pattern
hooks:
  - event: PostToolUse
    tools:
      - Write
      - Edit
    pattern: "**/*.py"
---

# Interface Validation Hook (Template)

This is a **template hook** - customize it for your project's specific interface patterns.

## How to Use This Template

1. Copy this file to your project's `.claude/hooks/` directory
2. Rename it to match your interface (e.g., `service-interface.md`, `handler-interface.md`)
3. Update the `pattern` to match your files
4. Define your required interface below

## Example: Service Interface

If your project has service classes that should follow a pattern:

```python
# Required interface for *_service.py files

class BaseService:
    def __init__(self, config: Config):
        """All services must accept a Config object."""
        pass

    async def initialize(self) -> None:
        """Called on service startup."""
        pass

    async def shutdown(self) -> None:
        """Called on service shutdown."""
        pass

    def health_check(self) -> dict:
        """Return health status."""
        return {"status": "healthy"}
```

## Example: Handler Interface

If your project has request handlers:

```python
# Required interface for *_handler.py files

def handle(request: Request) -> Response:
    """
    Args:
        request: The incoming request object

    Returns:
        Response object with status and body

    Raises:
        ValidationError: If request is invalid
        NotFoundError: If resource not found
    """
    pass
```

## Example: Processor Interface

If your project processes data through pipelines:

```python
# Required interface for *_processor.py files

def process_<tool>_output(input_file: str) -> dict:
    """
    Process tool output and return normalized data.

    Args:
        input_file: Path to raw tool output

    Returns:
        Dict with keys: 'tool', 'timestamp', 'results', 'metadata'
    """
    pass
```

## Validation Checklist

When this hook triggers, verify:

- [ ] Required function/class exists
- [ ] Function signature matches expected pattern
- [ ] Return type is correct
- [ ] Required methods are implemented (for classes)
- [ ] Error handling follows project conventions

## Customization Instructions

1. **Update the pattern**: Change `**/*.py` to match your specific files
   ```yaml
   pattern: "**/services/*_service.py"
   ```

2. **Define your interface**: Replace the examples with your actual required interface

3. **Add validation rules**: Specify what to check (function names, parameters, return types)

4. **Set severity**: Decide if violations should warn or block

## Real-World Examples

See these project-specific implementations for inspiration:
- Scanner interface validation
- API endpoint handler validation
- Database model interface validation
- Event handler interface validation
