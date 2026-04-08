# QMD Search Examples

Worked examples covering common patterns. Load this file when you need a concrete reference for composing typed sub-queries with intent.

## 1. Finding implementation patterns

User asks how Next.js handles authentication middleware.

```
mcp__qmd__query(
  searches: [
    { type: "lex", query: "authentication middleware" },
    { type: "vec", query: "how auth middleware validates requests" }
  ],
  intent: "Next.js App Router server-side authentication and route protection",
  collections: ["next.js"],
  limit: 10
)
```

Then `mcp__qmd__get(file: "next.js/packages/next/src/server/web/adapter.ts", lineNumbers: true)` for the top hit.

## 2. Precise lookup with quoted phrase + negation

User asks about a specific error in a known function.

```
mcp__qmd__query(
  searches: [
    { type: "lex", query: "\"NEXT_NOT_FOUND\" handleNotFound -test" },
    { type: "vec", query: "how the not-found error propagates through the router" }
  ],
  intent: "Next.js App Router error propagation and redirect handling",
  collections: ["next.js"],
  limit: 5
)
```

Quoted phrase forces verbatim match. `-test` excludes test fixtures from results.

## 3. Cross-repo comparison

User wants to compare error handling between React and Next.js.

```
mcp__qmd__query(
  searches: [
    { type: "lex", query: "error boundary" },
    { type: "vec", query: "error boundary implementation" }
  ],
  intent: "React class component error boundaries and componentDidCatch",
  collections: ["react"],
  limit: 5
)

mcp__qmd__query(
  searches: [
    { type: "lex", query: "error handling middleware" },
    { type: "vec", query: "how errors are handled in Next.js middleware" }
  ],
  intent: "Next.js App Router middleware request error handling",
  collections: ["next.js"],
  limit: 5
)
```

Two separate calls, one per collection. Each call has its own intent scoped to that codebase.

## 4. Disambiguation with intent

User asks about "performance" in the next.js collection.

```
mcp__qmd__query(
  searches: [
    { type: "lex", query: "performance" },
    { type: "vec", query: "how to improve page load performance" }
  ],
  intent: "web page load times and Core Web Vitals",
  collections: ["next.js"],
  limit: 10
)
```

Without `intent`, "performance" pulls in random blog posts and team-perf docs. With it, the pipeline preferentially expands, ranks, and snippets web-perf content.

## 5. Hyde for nuanced topics

User asks how Convex handles optimistic updates.

```
mcp__qmd__query(
  searches: [
    { type: "vec", query: "how does optimistic update work in Convex react client" },
    {
      type: "hyde",
      query: "Convex's React client supports optimistic updates by letting you specify a local update function on a mutation. The local update is applied immediately to the in-memory query result so the UI re-renders, then the server response replaces it. If the mutation fails the optimistic state is rolled back."
    }
  ],
  intent: "Convex React client optimistic mutation update API",
  collections: ["convex-docs", "convex-src"],
  limit: 10
)
```

Hyde excels when keyword surface is thin but you can describe the answer.

## 6. Fast path on CPU-only

User on a CPU-only machine wants fast results.

```
mcp__qmd__query(
  searches: [
    { type: "lex", query: "useEffect cleanup" }
  ],
  intent: "React hooks effect cleanup function and unmount",
  rerank: false,
  candidateLimit: 20,
  collections: ["react"],
  limit: 5
)
```

`rerank: false` skips the LLM reranker. `candidateLimit: 20` reduces fusion work. Quality drops slightly, latency drops a lot.

## 7. Broad research via subagent

User asks to research all routing patterns in Next.js.

Don't search directly — delegate so the raw retrieval stays out of the main thread.

```
Use the Explore subagent: "Search the next.js QMD collection for routing patterns. Use mcp__qmd__query for: routing, middleware, route handler, page router vs app router, parallel routes, intercepting routes. For each, intent: 'Next.js App Router routing primitives'. Retrieve top results with mcp__qmd__get. Return a structured summary with file:line references and a comparison of pages vs app router conventions."
```

The subagent runs all the searches in its own context and returns a summary.

## 8. Precision identifier lookup (no LLM needed)

User asks where `useTransition` is defined in React.

```
mcp__qmd__query(
  searches: [
    { type: "lex", query: "useTransition" }
  ],
  intent: "React 18 concurrent rendering hook implementation",
  collections: ["react"],
  rerank: false,
  limit: 3
)
```

For a unique identifier you don't need vec or rerank — BM25 alone is enough. Skipping the reranker drops latency from ~10s to ~1s.

## 9. Multi-collection broad query

User asks about authentication patterns across all their indexed framework refs.

```
mcp__qmd__query(
  searches: [
    { type: "lex", query: "session token cookie" },
    { type: "vec", query: "how the framework establishes and validates user sessions" },
    { type: "hyde", query: "After login the framework issues a signed session token, stores it as an HTTP-only cookie, and validates it on every request via middleware. The token contains the user id and an expiry. On expiry the user must re-authenticate." }
  ],
  intent: "framework session management with cookies and middleware",
  collections: ["next.js", "remix", "convex-docs", "better-auth-docs"],
  limit: 15
)
```

Multi-collection lets you compare implementations across frameworks in one call.
