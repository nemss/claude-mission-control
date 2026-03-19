# Conventions

## Naming

- **Files**: kebab-case (`user-service.ts`, `api-handler.js`)
- **Directories**: kebab-case (`data-models/`, `api-routes/`)
- **Variables/functions**: camelCase (`getUserById`, `isValid`)
- **Classes/types**: PascalCase (`UserService`, `ApiResponse`)
- **Constants**: UPPER_SNAKE_CASE (`MAX_RETRIES`, `API_BASE_URL`)
- **Environment variables**: UPPER_SNAKE_CASE with project prefix

## File Organization

- Group by feature/domain, not by type
- Keep files focused — one primary export per file
- Tests live next to the code they test (`foo.ts` → `foo.test.ts`)
- Shared utilities go in `src/utils/` or `lib/`

## Commit Messages

Use conventional commits:

```
<type>(<scope>): <description>

[optional body]
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`

Rules:
- Subject line under 72 characters
- Use imperative mood ("add feature" not "added feature")
- Reference issue numbers when applicable
- One logical change per commit

## Code Style

- Prefer explicit over clever
- Early returns over deep nesting
- Named constants over magic numbers
- Small, focused functions (under 40 lines)
- No dead code — delete it, don't comment it out

## Error Handling

- Handle errors at the appropriate level
- Provide context in error messages
- Never swallow errors silently
- Use typed errors where the language supports it

## Dependencies

- Minimize external dependencies
- Pin versions in lock files
- Review new dependencies for security and maintenance status
