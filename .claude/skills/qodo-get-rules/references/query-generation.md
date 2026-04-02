# Query Generation Guidelines

The search query is the most important input to the `/rules/search` endpoint. A well-formed query retrieves rules that are genuinely applicable to the task; a generic query returns irrelevant or noisy rules.

## Strategy

The search uses **embedding-based retrieval** where every rule is indexed as a vector of:

```
Name: {rule name}
Category: {rule category}
Content: {rule content}
```

To maximize semantic alignment between the query and the stored rule vectors, the search query must mirror this exact structure. A structured query aligns on **all three dimensions** (name, category, content) rather than collapsing the signal into a single sentence.

### Field guidelines

- **Name**: Think of it as "what rule would apply here?" Write a concise 5-10 word title describing the rule this coding assignment would trigger.
- **Category**: Choose the single most relevant category from the available values:
  - `Security` — authentication, authorization, injection, secrets, encryption, token validation, access control, privilege escalation, CSRF, XSS
  - `Correctness` — logic errors, null handling, off-by-one, type safety, incorrect computation, wrong conditional, missing guard, data corruption
  - `Quality` — code style, naming, readability, maintainability, dead code, code duplication, comment quality, magic numbers, overly complex logic, formatting
  - `Reliability` — error handling, retries, graceful degradation, timeouts, circuit breakers, fault tolerance, service availability, idempotency, recovery
  - `Performance` — latency, caching, memory, query optimization, batching, N+1 queries, connection pooling, unnecessary computation, scalability
  - `Testability` — test coverage, mocking, test structure, assertions, test isolation, test data, parameterized tests, fixture management
  - `Compliance` — licensing, regulatory, data retention, audit trails, GDPR, PII handling, data classification, policy enforcement
  - `Accessibility` — WCAG, ARIA, screen readers, keyboard navigation, color contrast, focus management, semantic HTML
  - `Observability` — logging, metrics, tracing, alerting, monitoring, instrumentation, dashboards, distributed tracing, log levels, error reporting
  - `Architecture` — layering, coupling, module boundaries, API design, dependency direction, separation of concerns, package structure, interface design, service decomposition, domain modeling

  **Tie-breaking:** When an assignment spans multiple categories, prefer `Security` if security is one of the candidates (security rules have the highest impact if missed). Otherwise prefer the category that describes the primary *purpose* of the change, not a secondary effect. For example, "add rate limiting" is primarily `Reliability` (protecting availability), not `Security`, even though it has security benefits. The cross-cutting query will cover the other dimensions.

  **Avoiding over-use of Correctness:** The heuristic classifier defaults to `Correctness` for a disproportionate share of tasks. Before selecting `Correctness`, consider whether a more specific category better describes the primary purpose:
  - Structural changes (new modules, refactors, layer reorganization) → prefer `Architecture`
  - Code style, naming, or readability improvements → prefer `Quality`
  - Availability, fault tolerance, or error recovery work → prefer `Reliability`
  - Instrumentation, logging, or monitoring additions → prefer `Observability`
  - Speed or resource efficiency improvements → prefer `Performance`

  Use `Correctness` when the task is genuinely about fixing a logic error, ensuring type safety, or preventing incorrect computation — not as a generic catch-all. If LLM-based classification is available, prefer it over keyword heuristics for ambiguous cases.
- **Content**: 1-2 sentences (aim for at least 15 words) describing what specifically should be checked or enforced for this coding assignment. When the coding assignment is in a known repository with established patterns, mention the relevant tech stack in the Content field — this helps the embedding model align with rules that reference specific technologies. Even for ambiguous assignments, expand the Content with general concerns (e.g., error handling, input validation) to provide enough semantic signal.

  **Broadening Content for weak domains:** Some domains have sparser rule coverage in a given organization's rule set. When a topic query returns fewer than 3 rules, or when the assignment involves a domain that the organization's rules may not address directly, expand the Content field with semantically adjacent concepts to improve retrieval.

  To identify adjacent concepts, ask: *What broader category does this task touch? What common patterns or concerns appear in code that does this kind of work?*

  **Examples by domain (for illustration — your org's sparse domains may differ):**

  | Domain | Adjacent concepts to include in Content |
  |---|---|
  | Auth / JWT / OAuth | token validation, credential handling, session management, authorization headers, access control |
  | Async / concurrency | event loop, task management, concurrent execution, thread safety, resource cleanup |
  | Rate limiting / throttling | request quotas, backpressure, abuse prevention, middleware, circuit breaking |
  | Data migration | schema changes, rollback safety, backward compatibility, data integrity |
  | Frontend form validation | input sanitization, client-side validation, accessibility requirements, error state handling |
  | Database access patterns | query optimization, connection management, transaction handling, ORM conventions |

  The goal is to give the embedding model a richer surface to align against — not to make the query generic, but to ensure that closely related rules surface even when the exact terminology differs. Adjust based on your organization's actual rule coverage.

## Query Format

Write the query as a **structured three-line block** matching the rule embedding format:

```
Name: {concise title of the rule this coding assignment would trigger}
Category: {most relevant RuleCategory value}
Content: {what specifically should be checked or enforced for this assignment}
```

**Do not** write keyword-style queries (e.g., `authentication login JWT token Python`).

**Do not** write flat natural language sentences. The embedding model aligns better when the query mirrors the indexed structure.

**Do not** include filler words like "please", "I need to", or other padding that dilutes the semantic signal.

## Multi-Query Strategy

Generate **two queries** per coding assignment for best coverage:

1. **Topic query** -- a structured query focused on the assignment's primary concern (the standard approach described above).
2. **Cross-cutting query** -- a supplementary query targeting recurring quality and standards rules that apply to most code changes regardless of topic.

**Why two queries?** Evaluation data shows that cross-cutting rules (module structure, structured logging, type annotations, repository pattern) account for 60%+ of rules flagged in real code reviews. A single topic-focused query systematically misses these because they are semantically distant from the PR's specific subject.

**Cross-cutting query — Category selection:**

Choose the Category for the cross-cutting query based on the organization's rule set emphasis when that is known:
- If the org's rules are primarily about code structure, layering, or module design → use `Architecture`
- If the org's rules are primarily about security requirements applied everywhere → use `Security`
- If the org's rules include mandatory compliance or audit requirements → use `Compliance`
- If the org's rules focus on observability standards applied to all code → use `Observability`
- If the org's rule emphasis is unknown → default to `Architecture` (a reasonable fallback for most backend codebases)

The goal is to retrieve the category of rules that the org applies *broadly*, not just rules that are topically aligned with the PR.

**Cross-cutting query — Content:**

When the organization's rule set emphasis is known, tailor the cross-cutting Content to reflect the categories of rules the organization enforces broadly:
- A security-focused org: include secure coding baseline (input validation, safe dependencies, secret handling)
- A compliance-focused org: include audit trail, data classification, policy enforcement
- A quality-focused org: include naming, dead code, test coverage, documentation
- A performance-focused org: include query efficiency, caching, resource management

If the org's emphasis is unknown, use the generic default template. The goal is for the cross-cutting query to retrieve the rules that apply to *all* of the org's code changes, regardless of PR topic.

**Cross-cutting query default template:**

```
Name: Code Quality and Standards Compliance
Category: Architecture
Content: Module directory structure, type annotations or type safety, structured logging, repository or service layer patterns, dependency injection, and naming conventions
```

Adjust the Content field to reflect the repository's tech stack and the organization's rule emphasis when known.

Call the search endpoint **once per query** (each with the configured `TOP_K` value) and merge the results, deduplicating by rule ID.

**Low-return fallback:** If the topic query returns fewer than 3 rules, do not silently accept the sparse result. Re-generate the topic query with a broader Content field by including adjacent concepts for the domain (see the "Broadening Content for weak domains" table above). Then call the endpoint again with the broadened query before merging with cross-cutting results. Note: the threshold is count-based — use it as a trigger, not a hard guarantee of quality. Apply judgment on the semantic fit of returned rules; a sparse but highly relevant set may be preferable to a broader query that surfaces loosely related rules.

**Cross-cutting false positives:** The cross-cutting query intentionally casts a wide net. Some rules will surface frequently across many different code changes — these are typically your organization's broadest quality or standards rules that the org considers universally applicable. This is expected. Use cross-cutting results as supplementary context; rely on the topic query for task-specific guidance. When the merged result set feels too noisy for a particular assignment, deprioritize cross-cutting results that are semantically distant from the coding task.

## Examples

| Coding Assignment | Topic Query | Cross-Cutting Query |
|---|---|---|
| Add a login endpoint that accepts username and password, validates credentials, and returns a JWT token | `Name: JWT Authentication Endpoint Validation`<br>`Category: Security`<br>`Content: Implementing a login endpoint that validates user credentials against the database and issues JWT tokens securely` | `Name: Code Quality and Security Standards`<br>`Category: Security`<br>`Content: Token validation, credential handling, secure session management, input sanitization, and access control requirements applied broadly across all endpoints` |
| Refactor the user service to use async/await instead of callbacks | `Name: Async Await Migration Pattern`<br>`Category: Quality`<br>`Content: Refactoring a service layer from callback-based concurrency to async/await, ensuring correct error propagation and resource cleanup` | `Name: Code Quality and Standards Compliance`<br>`Category: Architecture`<br>`Content: Module directory structure, type annotations or type safety, structured logging, repository or service layer patterns, dependency injection, and naming conventions` |
| Fix a SQL injection vulnerability in the search query builder | `Name: SQL Injection Prevention`<br>`Category: Security`<br>`Content: Sanitizing user input in the database query builder to prevent SQL injection attacks through parameterized queries` | `Name: Code Quality and Standards Compliance`<br>`Category: Architecture`<br>`Content: Module directory structure, type annotations or type safety, structured logging, repository or service layer patterns, dependency injection, and naming conventions` |
| Add unit tests for the payment processing module | `Name: Payment Processing Test Coverage`<br>`Category: Testability`<br>`Content: Adding unit tests for the payment processing module with mocked external payment gateway services` | `Name: Code Quality and Standards Compliance`<br>`Category: Architecture`<br>`Content: Module directory structure, type annotations or type safety, structured logging, repository or service layer patterns, dependency injection, and naming conventions` |
| Implement a rate limiter middleware for the API | `Name: Rate Limiting Enforcement`<br>`Category: Reliability`<br>`Content: Implementing rate limiting middleware to throttle HTTP API requests and protect against abuse` | `Name: Code Quality and Standards Compliance`<br>`Category: Architecture`<br>`Content: Module directory structure, type annotations or type safety, structured logging, repository or service layer patterns, dependency injection, and naming conventions` |
| Add error handling to the file upload handler | `Name: File Upload Error Handling`<br>`Category: Reliability`<br>`Content: Adding structured error handling and exception management to the file upload handler for graceful failure recovery` | `Name: Code Quality and Standards Compliance`<br>`Category: Architecture`<br>`Content: Module directory structure, type annotations or type safety, structured logging, repository or service layer patterns, dependency injection, and naming conventions` |
| Optimize the dashboard query that takes 5 seconds to load | `Name: Database Query Performance Optimization`<br>`Category: Performance`<br>`Content: Optimizing slow database queries for the dashboard view through indexing, query restructuring, or caching` | `Name: Code Quality and Standards Compliance`<br>`Category: Architecture`<br>`Content: Module directory structure, type annotations or type safety, structured logging, repository or service layer patterns, dependency injection, and naming conventions` |
| Add ARIA labels to the navigation menu _(TypeScript React)_ | `Name: Navigation Accessibility Labels`<br>`Category: Accessibility`<br>`Content: Adding ARIA attributes and roles to the navigation menu to ensure screen reader compatibility and keyboard navigation` | `Name: Code Quality and Standards Compliance`<br>`Category: Architecture`<br>`Content: React component structure, TypeScript strict type checking, consistent naming conventions, proper prop typing, and component test coverage` |
| Add a new user management module with CRUD endpoints | `Name: Module Structure and Layer Boundaries`<br>`Category: Architecture`<br>`Content: Creating a new module with proper directory structure, service layer, repository pattern, and dependency injection` | `Name: Code Quality and Standards Compliance`<br>`Category: Architecture`<br>`Content: Module directory structure, type annotations or type safety, structured logging, repository or service layer patterns, dependency injection, and naming conventions` |
| Add logging to the payment processing pipeline _(Go microservice)_ | `Name: Structured Logging Implementation`<br>`Category: Observability`<br>`Content: Adding structured logging with contextual fields and appropriate log levels to the payment processing pipeline` | `Name: Code Quality and Architecture Standards`<br>`Category: Architecture`<br>`Content: Go package structure, interface-based dependency injection, structured logging with contextual fields, error wrapping conventions, and consistent handler patterns` |
| Add a GDPR data deletion endpoint _(Java Spring)_ | `Name: GDPR Data Deletion Compliance`<br>`Category: Compliance`<br>`Content: Implementing a data deletion endpoint that enforces data retention policies, logs audit trails, and handles PII according to GDPR requirements` | `Name: Code Quality and Compliance Standards`<br>`Category: Compliance`<br>`Content: Data retention policy enforcement, audit trail logging, PII handling requirements, Spring service layer conventions, and exception handling standards` |
| Add JWT authentication to the API _(Node.js Express)_ | `Name: JWT Authentication Middleware`<br>`Category: Security`<br>`Content: Implementing JWT token validation and authentication middleware in an Express API with secure credential handling` | `Name: Code Quality and Security Standards`<br>`Category: Security`<br>`Content: Token validation, credential handling, secure session management, Express middleware conventions, and input sanitization requirements` |

## Approach: Start from the Coding Assignment

1. Read the coding assignment and identify the **core concern** -- what rule would a reviewer look for?
2. Write that as a concise **Name** (5-10 words)
3. Pick the single best **Category** from the list above
4. Write 1-2 sentences for **Content** describing what should be checked or enforced; include tech stack details when the repository context is known
5. Assemble the three-line structured topic query
6. Generate the cross-cutting query: choose the Category based on the org's rule emphasis (or default to `Architecture`), and tailor the Content to reflect what the org enforces broadly
7. Call the search endpoint with both queries (top_k=20 each), merge and deduplicate results

## Fallback

If the coding assignment is very short or ambiguous (e.g., "fix the bug"), use the assignment text as the **Name** field, pick the closest Category (default to `Correctness` when truly ambiguous -- the cross-cutting query already covers Architecture, so using a different category for the topic query maximizes category diversity), and write a brief Content line restating the assignment with at least 15 words. Still generate the cross-cutting query alongside it. A short structured query is better than an invented one.
