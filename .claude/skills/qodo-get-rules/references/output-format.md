# Formatting and Outputting Rules

## Output Structure

Print the following header:

```
# 📋 Qodo Rules Loaded

Search queries: `{TOPIC_QUERY_NAME}` + `{CROSS_CUTTING_QUERY_NAME}`
Rules loaded: **{TOTAL_RULES}** (ranked by relevance to your task)

These rules must be applied during code generation based on severity:
```

## Rules List

List rules in the order returned (ranked by relevance — most relevant first). Each rule uses this format:

```
- **{name}** [{SEVERITY}]: {content}
```

Where `{SEVERITY}` is one of: `ERROR`, `WARNING`, or `RECOMMENDATION`.

**Example:**

```
- **No Hardcoded Credentials** [ERROR]: Credentials, API keys, and tokens must not appear in source code; use environment variables or a secrets manager instead.
- **Structured Logging Required** [WARNING]: All log statements must use structured logging with key-value pairs; avoid string interpolation in log messages.
- **Repository Pattern** [RECOMMENDATION]: Service layer should delegate data access to a dedicated repository class rather than calling the ORM directly.
```

## Empty Result

If no rules were returned, output:

```
# 📋 Qodo Rules Loaded

No relevant rules found for this task. Proceeding without rule constraints.

---
```

Do **not** crash or error — an empty result is valid.

## Closing Separator

End all output (rules found or not) with `---`.
