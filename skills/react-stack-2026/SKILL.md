---
name: react-stack-2026
description: 2026 React stack patterns — React 19 (RSC, Server Actions, use(), useActionState/useFormStatus/useOptimistic, ref-as-prop, document metadata), Next.js 15 App Router (parallel/intercepting routes, streaming, partial prerender), TanStack Query v5 (Suspense queries, mutations), react-hook-form + Conform (Server Actions), shadcn/ui composition, Tailwind v4 CSS-first config, Vite 6 + Vitest 3 + Playwright. Load when project uses React 19, Next.js 15, App Router, RSC, or asks for modern stack patterns. Sibling to frontend-patterns (core React).
---

# React Stack 2026

Companion to `frontend-patterns/SKILL.md`. **frontend-patterns** owns framework-agnostic React patterns (composition, hooks, state, error, accessibility, animation). **This skill** owns framework-specific patterns for the 2026 React ecosystem — load only when project actually uses these tools.

When to load:
- Project has `next@15+` in `package.json` → Next.js 15 App Router patterns
- Project uses `app/` directory or any `'use server'` / `'use client'` directives → RSC
- Project uses `@tanstack/react-query@5+` → query patterns below
- Project uses `react@19+` features → React 19 essentials
- Designer / frontend agent building new UI → shadcn/ui + Tailwind v4 base

If project is on React 18 or Vite-only SPA with no RSC, prefer `frontend-patterns/SKILL.md` and load this skill only for the relevant subsystem.

---

## 1. React 19 Essentials

### 1.1 `use()` hook for promises and context

```tsx
import { use, Suspense } from "react";

// Server component fetches promise, client component reads via use()
async function ServerWrapper() {
  const usersPromise = api.getUsers(); // NOT awaited here
  return (
    <Suspense fallback={<Skeleton />}>
      <UserList usersPromise={usersPromise} />
    </Suspense>
  );
}

function UserList({ usersPromise }: { usersPromise: Promise<User[]> }) {
  const users = use(usersPromise);  // suspends until resolved
  return <ul>{users.map((u) => <li key={u.id}>{u.name}</li>)}</ul>;
}
```

`use()` also reads context conditionally (allowed inside if/for, unlike `useContext`):

```tsx
function MaybeThemed({ enabled }: { enabled: boolean }) {
  if (!enabled) return <Plain />;
  const theme = use(ThemeContext); // ← legal inside conditional
  return <Themed theme={theme} />;
}
```

### 1.2 Server Actions + form mutation

```tsx
// app/actions/createUser.ts
"use server";

import { z } from "zod";
import { revalidatePath } from "next/cache";

const schema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
});

export async function createUser(prevState: unknown, formData: FormData) {
  const parsed = schema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { ok: false, errors: parsed.error.flatten().fieldErrors };
  }
  await db.user.create({ data: parsed.data });
  revalidatePath("/users");
  return { ok: true, errors: {} };
}
```

### 1.3 `useActionState` + `useFormStatus` form pair

```tsx
// app/users/new/page.tsx
"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { createUser } from "@/app/actions/createUser";

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button type="submit" disabled={pending}>
      {pending ? "Creating…" : "Create"}
    </button>
  );
}

export function CreateUserForm() {
  const [state, formAction] = useActionState(createUser, { ok: false, errors: {} });
  return (
    <form action={formAction}>
      <input name="name" />
      {state.errors.name && <span className="text-red-600">{state.errors.name[0]}</span>}
      <input name="email" />
      {state.errors.email && <span className="text-red-600">{state.errors.email[0]}</span>}
      <SubmitButton />
    </form>
  );
}
```

### 1.4 `useOptimistic` for instant feedback

```tsx
"use client";

import { useOptimistic } from "react";

export function TodoList({ todos }: { todos: Todo[] }) {
  const [optimistic, addOptimistic] = useOptimistic(
    todos,
    (state, newTodo: Todo) => [...state, { ...newTodo, sending: true }]
  );

  async function add(formData: FormData) {
    const text = formData.get("text") as string;
    addOptimistic({ id: crypto.randomUUID(), text, sending: false });
    await createTodo(text); // server action
  }

  return (
    <>
      <form action={add}><input name="text" /></form>
      {optimistic.map((t) => <li key={t.id} className={t.sending ? "opacity-50" : ""}>{t.text}</li>)}
    </>
  );
}
```

### 1.5 Ref as prop (no more `forwardRef`)

```tsx
// React 19: ref is just a normal prop
function FancyButton({ ref, children, ...rest }: { ref?: React.Ref<HTMLButtonElement> } & ButtonHTMLAttributes) {
  return <button ref={ref} {...rest}>{children}</button>;
}

// Caller
const btnRef = useRef<HTMLButtonElement>(null);
<FancyButton ref={btnRef}>Click</FancyButton>;
```

### 1.6 Document metadata as JSX

```tsx
function ProductPage({ product }: { product: Product }) {
  return (
    <>
      <title>{product.name} — Acme Store</title>
      <meta name="description" content={product.description} />
      <link rel="canonical" href={`https://acme.com/p/${product.slug}`} />
      <ProductDetails product={product} />
    </>
  );
}
```

React 19 hoists these to `<head>` automatically. For Next.js App Router, prefer `generateMetadata` (server) — use inline JSX metadata only in CSR/SPA contexts.

---

## 2. Next.js 15 App Router

### 2.1 Server / Client component boundary

- Default = Server Component (RSC). No `useState`, `useEffect`, browser APIs, event handlers.
- Add `"use client"` at file top to opt into client rendering.
- Server components can import client components. Client components CANNOT import server components — pass as children.

```tsx
// app/dashboard/page.tsx — server
import { ClientChart } from "./client-chart";
async function Page() {
  const data = await db.metrics.findMany();
  return <ClientChart data={data} />;
}
```

### 2.2 Streaming with Suspense

```tsx
// app/dashboard/page.tsx
import { Suspense } from "react";
import { Revenue, Users, Activity } from "./widgets";

export default function Dashboard() {
  return (
    <>
      <h1>Dashboard</h1>
      <Suspense fallback={<Skeleton h="200px" />}><Revenue /></Suspense>
      <Suspense fallback={<Skeleton h="200px" />}><Users /></Suspense>
      <Suspense fallback={<Skeleton h="200px" />}><Activity /></Suspense>
    </>
  );
}
```

Each widget fetches independently; slow ones don't block fast ones.

### 2.3 Parallel + Intercepting routes

```
app/
  @modal/
    (.)photos/[id]/page.tsx   ← intercepts /photos/[id] as modal
  photos/[id]/page.tsx        ← full-page when reached directly
  layout.tsx                  ← receives { children, modal }
```

```tsx
// app/layout.tsx
export default function Layout({ children, modal }: { children: ReactNode; modal: ReactNode }) {
  return <>{children}{modal}</>;
}
```

Use for: photo-modal pattern (Instagram), drawer overlays, side-panel routes.

### 2.4 `generateMetadata` (SEO)

```tsx
// app/p/[slug]/page.tsx
import type { Metadata } from "next";

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const product = await getProduct(params.slug);
  return {
    title: `${product.name} — Acme`,
    description: product.summary,
    openGraph: { images: [product.heroImage] },
    alternates: { canonical: `/p/${product.slug}` },
  };
}
```

### 2.5 Partial Prerendering (PPR, opt-in)

```ts
// next.config.ts
export default { experimental: { ppr: "incremental" } };
```

```tsx
// app/product/[slug]/page.tsx
export const experimental_ppr = true;

// Static shell prerendered, dynamic parts stream
export default async function Page({ params }: Props) {
  return (
    <>
      <ProductHero slug={params.slug} /> {/* static */}
      <Suspense fallback={<Skeleton />}>
        <Recommendations slug={params.slug} /> {/* dynamic, streamed */}
      </Suspense>
    </>
  );
}
```

### 2.6 Server-side data — direct fetch, dedupe via React cache

```tsx
import { cache } from "react";

export const getUser = cache(async (id: string) => {
  return db.user.findUnique({ where: { id } });
});

// Called in multiple components per request → executes once
```

---

## 3. Data Fetching — TanStack Query v5

### 3.1 Suspense queries (preferred for React 19)

```tsx
import { useSuspenseQuery } from "@tanstack/react-query";

function UserDetail({ id }: { id: string }) {
  const { data: user } = useSuspenseQuery({
    queryKey: ["user", id],
    queryFn: () => api.getUser(id),
  });
  return <div>{user.name}</div>; // no loading branch needed
}

// Caller wraps with Suspense + ErrorBoundary
<ErrorBoundary FallbackComponent={ErrorFallback}>
  <Suspense fallback={<Skeleton />}>
    <UserDetail id="42" />
  </Suspense>
</ErrorBoundary>
```

### 3.2 Mutations with optimistic update

```tsx
import { useMutation, useQueryClient } from "@tanstack/react-query";

function useToggleTask() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.toggleTask(id),
    onMutate: async (id) => {
      await qc.cancelQueries({ queryKey: ["tasks"] });
      const prev = qc.getQueryData<Task[]>(["tasks"]);
      qc.setQueryData<Task[]>(["tasks"], (old) =>
        old?.map((t) => (t.id === id ? { ...t, done: !t.done } : t))
      );
      return { prev };
    },
    onError: (_err, _id, ctx) => qc.setQueryData(["tasks"], ctx?.prev),
    onSettled: () => qc.invalidateQueries({ queryKey: ["tasks"] }),
  });
}
```

### 3.3 RSC + Hydration

Server fetches → client gets pre-populated cache.

```tsx
// app/users/page.tsx — server
import { dehydrate, HydrationBoundary, QueryClient } from "@tanstack/react-query";

export default async function Page() {
  const qc = new QueryClient();
  await qc.prefetchQuery({ queryKey: ["users"], queryFn: getUsers });
  return (
    <HydrationBoundary state={dehydrate(qc)}>
      <UsersClient />
    </HydrationBoundary>
  );
}
```

---

## 4. Forms

### 4.1 react-hook-form + Zod (client-only forms)

```tsx
"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";

const Schema = z.object({
  name: z.string().min(1, "Required"),
  email: z.string().email(),
});

type FormValues = z.infer<typeof Schema>;

export function ProfileForm() {
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<FormValues>({
    resolver: zodResolver(Schema),
  });

  return (
    <form onSubmit={handleSubmit(async (data) => { await api.save(data); })}>
      <input {...register("name")} />
      {errors.name && <span>{errors.name.message}</span>}
      <input {...register("email")} />
      {errors.email && <span>{errors.email.message}</span>}
      <button disabled={isSubmitting}>Save</button>
    </form>
  );
}
```

### 4.2 Conform — progressive enhancement (works without JS)

```tsx
"use client";

import { useForm, getFormProps, getInputProps } from "@conform-to/react";
import { parseWithZod } from "@conform-to/zod";
import { Schema, saveAction } from "./action";

export function ProfileForm({ lastResult }: { lastResult: SubmissionResult }) {
  const [form, fields] = useForm({
    lastResult,
    onValidate({ formData }) { return parseWithZod(formData, { schema: Schema }); },
  });

  return (
    <form {...getFormProps(form)} action={saveAction}>
      <input {...getInputProps(fields.name, { type: "text" })} />
      <div>{fields.name.errors}</div>
      <button>Save</button>
    </form>
  );
}
```

**Pick rule**: client-only SPA → react-hook-form. RSC + Server Actions + want forms to work without JS → Conform.

---

## 5. shadcn/ui Composition

shadcn/ui is **not** a component library — it's copy-paste source. Components live in your repo, you own them, you modify them.

### 5.1 Compose, don't override

```tsx
// BAD: overriding className with magic strings
<Button className="!bg-red-500 !text-white !rounded-full !px-8">Submit</Button>

// GOOD: define a variant
// components/ui/button.tsx (in your repo, from shadcn)
const buttonVariants = cva("inline-flex …", {
  variants: {
    variant: {
      default:  "bg-primary text-primary-foreground",
      danger:   "bg-red-500 text-white",
      ghost:    "hover:bg-accent",
    },
    size: { sm: "h-8 px-3", md: "h-10 px-4", lg: "h-12 px-6 rounded-full" },
  },
});

<Button variant="danger" size="lg">Submit</Button>
```

### 5.2 Adapt primitives, don't wrap-wrap-wrap

```tsx
// BAD: Card wrapping Card wrapping CardHeader
<MyCard>
  <MyCardHeader>
    <MyCardTitle>...</MyCardTitle>
  </MyCardHeader>
</MyCard>

// GOOD: use shadcn primitives directly, compose at the page level
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";

function PricingCard({ plan }: Props) {
  return (
    <Card>
      <CardHeader><CardTitle>{plan.name}</CardTitle></CardHeader>
      <CardContent>${plan.price}/mo</CardContent>
    </Card>
  );
}
```

### 5.3 Theming via CSS variables (Tailwind v4 / shadcn)

```css
/* app/globals.css */
@import "tailwindcss";

:root {
  --background: 0 0% 100%;
  --foreground: 222.2 84% 4.9%;
  --primary: 221.2 83.2% 53.3%;
  --radius: 0.5rem;
}

.dark {
  --background: 222.2 84% 4.9%;
  --foreground: 210 40% 98%;
  --primary: 217.2 91.2% 59.8%;
}
```

Switching themes = swap CSS variable values. Never hardcode color hex in components.

---

## 6. Tailwind v4 (CSS-First Config)

v4 dropped `tailwind.config.ts` for most cases — config is now CSS.

```css
/* app/globals.css */
@import "tailwindcss";

@theme {
  --color-brand: oklch(0.65 0.2 250);
  --font-display: "Inter Variable", sans-serif;
  --breakpoint-3xl: 120rem;
}
```

Then in components: `bg-brand text-white`, `font-display`, `3xl:grid-cols-6`.

Vite plugin (faster than v3 PostCSS):

```ts
// vite.config.ts
import tailwindcss from "@tailwindcss/vite";

export default { plugins: [tailwindcss()] };
```

---

## 7. Build & Tooling

### 7.1 Vite 6

```ts
// vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";
import tailwindcss from "@tailwindcss/vite";
import tsconfigPaths from "vite-tsconfig-paths";

export default defineConfig({
  plugins: [react(), tailwindcss(), tsconfigPaths()],
  build: {
    target: "es2022",
    sourcemap: true,
    rollupOptions: { output: { manualChunks: { react: ["react", "react-dom"] } } },
  },
});
```

Use `@vitejs/plugin-react-swc` (faster than Babel-based plugin). For React Compiler, use `@vitejs/plugin-react` with `babel-plugin-react-compiler` until the SWC variant catches up.

### 7.2 React Compiler

```ts
// vite.config.ts — Babel variant
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [
    react({
      babel: { plugins: [["babel-plugin-react-compiler", { target: "19" }]] },
    }),
  ],
});
```

`.eslintrc.json`: `"plugins": ["eslint-plugin-react-compiler"], "rules": { "react-compiler/react-compiler": "error" }` — flags components Compiler can't safely memoize.

### 7.3 Biome 2 (replaces ESLint + Prettier)

```json
// biome.json
{
  "$schema": "https://biomejs.dev/schemas/2.0.0/schema.json",
  "linter": { "enabled": true, "rules": { "recommended": true } },
  "formatter": { "enabled": true, "indentStyle": "space", "indentWidth": 2 },
  "javascript": { "formatter": { "quoteStyle": "double", "semicolons": "always" } }
}
```

```jsonc
// package.json
"scripts": {
  "check":  "biome check .",
  "format": "biome format --write ."
}
```

For projects with heavy React-specific lint needs (a11y, hooks rules), keep ESLint for those rules + Biome for formatting until Biome's React plugin matures.

---

## 8. Testing

### 8.1 Vitest 3 + Testing Library

```ts
// vitest.config.ts
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react-swc";

export default defineConfig({
  plugins: [react()],
  test: { environment: "jsdom", setupFiles: "./vitest.setup.ts", globals: true },
});
```

```ts
// vitest.setup.ts
import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import { afterEach } from "vitest";
afterEach(() => cleanup());
```

```tsx
// UserList.test.tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { UserList } from "./UserList";

test("renders users and handles click", async () => {
  render(<UserList users={[{ id: "1", name: "Ana" }]} />);
  expect(screen.getByText("Ana")).toBeInTheDocument();
  await userEvent.click(screen.getByRole("button", { name: /select/i }));
  // assert side effect
});
```

### 8.2 Playwright (E2E)

```ts
// playwright.config.ts
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  use: { baseURL: "http://localhost:3000", trace: "on-first-retry" },
  projects: [
    { name: "chromium", use: devices["Desktop Chrome"] },
    { name: "mobile",   use: devices["iPhone 14"] },
  ],
  webServer: { command: "pnpm dev", port: 3000, reuseExistingServer: true },
});
```

```ts
// e2e/checkout.spec.ts
import { test, expect } from "@playwright/test";

test("complete checkout", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: "Add to cart" }).click();
  await page.getByRole("link", { name: "Checkout" }).click();
  await page.getByLabel("Email").fill("test@example.com");
  await page.getByRole("button", { name: "Pay" }).click();
  await expect(page.getByText("Order confirmed")).toBeVisible();
});
```

### 8.3 Server Component tests

RSCs render to a stream — test via Next's `app/test-utils` or hit the rendered HTML in Playwright. Unit-testing RSCs in isolation is awkward; prefer integration tests through the framework.

---

## 9. Anti-Patterns to Reject

| Pattern | Why bad | Use instead |
|---------|---------|-------------|
| `useEffect(() => { fetch(...) }, [])` | Race conditions, no dedupe, no cache | TanStack Query OR RSC `await` |
| `forwardRef` in new code | React 19 ref-as-prop is simpler | `ref` as normal prop |
| `useMemo`/`useCallback` everywhere | Compiler auto-memoizes; manual adds cost | React Compiler; manual only on hot paths |
| Class `ErrorBoundary` | Verbose, no reset API | `react-error-boundary` |
| `"use client"` at root | Defeats RSC | Put it at the leaf component that needs it |
| Importing server module in client component | Build error or leaked secrets | Pass server data as props |
| `getServerSideProps` / `getStaticProps` in App Router | Pages-router pattern | Async server component + `cache()` |
| Custom `useQuery` | Reinvents TanStack Query badly | `useQuery` from `@tanstack/react-query` |
| Hardcoded color hex in component | Breaks theming | Tailwind theme token / CSS variable |

---

## 10. Decision Trees

### "Where do I fetch?"

```
Is the data needed for SSR / SEO?
├── Yes → Server Component, await directly, cache() if shared
└── No  → Client + TanStack Query useSuspenseQuery
          └── Need optimistic UI? → useOptimistic OR useMutation onMutate
```

### "Where do I put `'use client'`?"

```
Does this component use state / effects / browser APIs / event handlers?
├── Yes → "use client" at the TOP of this file (leaf)
└── No  → Leave as RSC; pass children from RSC parent
```

### "How do I memoize?"

```
Using React Compiler?
├── Yes → Don't. Write naturally.
└── No  → Did profiler show this hot?
          ├── Yes → useMemo / useCallback / memo()
          └── No  → Don't.
```

---

## See Also

- Core React patterns → `frontend-patterns/SKILL.md`
- TypeScript-specific patterns → `rules/typescript/patterns.md`
- SaaS frontend admin dashboard → `saas-patterns/SKILL.md` Part 2 (URL state, drill-down, virtualized tables)
- Designer artifacts (tokens, visual spec, component inventory) → `agents/dev-squad/designer.md` Phase 3.5 outputs
