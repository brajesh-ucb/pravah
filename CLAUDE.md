# Project Context: Swift iOS Application

## Build & Test Commands
- Build Project: `xcodebuild -scheme MyApp -sdk iphonesimulator -configuration Debug build`
- Run All Tests: `xcodebuild -scheme MyApp -sdk iphonesimulator -configuration Debug test`
- SPM Clean: `swift package clean`

## Code & Architecture Style
- Language Standard: Strict Swift 6 compliance with complete concurrency checking enabled.
- Framework Choice: 100% declarative SwiftUI. Do not fall back to UIKit or AppKit wrappers unless explicitly told.
- Concurrency: Prioritize structural concurrency (`async/await` and `TaskGroup`). Avoid old-school closure-based completion handlers.
- State Management: Use modern `@Observable` state macros. Avoid deprecated `@ObservedObject` or `@EnvironmentObject` wrappers.
- Data & Persistence: Use `SwiftData` for model storage and native `@AppStorage` for lightweight user preferences.
- **Design:** Enforce strict SOLID principles. Maximize composition; minimize inheritance. 
- **Responsibility:** Every class/struct must have exactly one reason to change. If a function exceeds 30 lines, immediately decompose it into single-purpose units.
- **Python Naming:** `snake_case` (vars/funcs), `PascalCase` (classes), `UPPER_SNAKE` (constants).
- **Swift Naming:** `camelCase` (vars/funcs), `PascalCase` (types/protocols). Adhere strictly to Apple's API Design Guidelines (clarity over brevity, omit needless words).
- **Intent:** Variable names must reveal intent. Avoid generic abbreviations (e.g., use `lendingRepository` instead of `repo`).

## Testing Standards
- Test Framework: Use the modern **Swift Testing** framework. Do not use legacy XCTest.
- Syntax: Use `@Test` annotations instead of prefixes (`func testExample()`).
- Assertions: Use the native `#expect()` macro exclusively for verifying outcomes.

## UI Style
- Component Design: Enforce a strict "one major Type per file" organization rule.
- Preview Blocks: Every view file must include a valid `#Preview` container block for live rendering.
- Assets: Always use native system SF Symbols referenced by their precise literal string identifier.

<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes` or `query_graph` instead of Grep
- **Understanding impact**: `get_impact_radius` instead of manually tracing imports
- **Code review**: `detect_changes` + `get_review_context` instead of reading entire files
- **Finding relationships**: `query_graph` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview` + `list_communities`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
| ------ | ---------- |
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
