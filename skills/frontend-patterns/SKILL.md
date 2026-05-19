---
name: frontend-patterns
description: Frontend architecture patterns for dev-squad agents. Covers component composition, compound components, render props, custom hooks, state management, performance optimization, form handling, error boundaries, animations, and accessibility. React/TypeScript examples.
---

# Frontend Patterns - React Architecture for Dev Squad

## INSTRUCTIONS: When this skill is invoked

Load these patterns when any dev-squad agent is building, reviewing, or architecting frontend applications. Use as a reference for component design, state management, performance, and accessibility.

---

## 1. Component Composition

### Favor Composition Over Props Drilling

```tsx
// BAD: Prop drilling through many layers
function App() {
  const [user, setUser] = useState<User | null>(null);
  return <Layout user={user}><Sidebar user={user}><UserMenu user={user} /></Sidebar></Layout>;
}

// GOOD: Composition with children
function App() {
  const [user, setUser] = useState<User | null>(null);
  return (
    <Layout>
      <Sidebar>
        <UserMenu user={user} />
      </Sidebar>
    </Layout>
  );
}
```

### Slot Pattern

```tsx
interface PageLayoutProps {
  header: React.ReactNode;
  sidebar?: React.ReactNode;
  children: React.ReactNode;
  footer?: React.ReactNode;
}

function PageLayout({ header, sidebar, children, footer }: PageLayoutProps) {
  return (
    <div className="min-h-screen flex flex-col">
      <header className="border-b">{header}</header>
      <div className="flex flex-1">
        {sidebar && <aside className="w-64 border-r">{sidebar}</aside>}
        <main className="flex-1 p-6">{children}</main>
      </div>
      {footer && <footer className="border-t">{footer}</footer>}
    </div>
  );
}
```

---

## 2. Compound Components

Share implicit state between related components:

```tsx
// Tabs compound component
interface TabsContextValue {
  activeTab: string;
  setActiveTab: (tab: string) => void;
}

const TabsContext = createContext<TabsContextValue | null>(null);

function useTabsContext() {
  const ctx = useContext(TabsContext);
  if (!ctx) throw new Error("Tabs components must be used within <Tabs>");
  return ctx;
}

function Tabs({ defaultTab, children }: { defaultTab: string; children: React.ReactNode }) {
  const [activeTab, setActiveTab] = useState(defaultTab);
  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab }}>
      <div role="tablist">{children}</div>
    </TabsContext.Provider>
  );
}

function TabTrigger({ value, children }: { value: string; children: React.ReactNode }) {
  const { activeTab, setActiveTab } = useTabsContext();
  return (
    <button
      role="tab"
      aria-selected={activeTab === value}
      onClick={() => setActiveTab(value)}
      className={activeTab === value ? "border-b-2 border-blue-500 font-semibold" : "text-gray-500"}
    >
      {children}
    </button>
  );
}

function TabContent({ value, children }: { value: string; children: React.ReactNode }) {
  const { activeTab } = useTabsContext();
  if (activeTab !== value) return null;
  return <div role="tabpanel">{children}</div>;
}

Tabs.Trigger = TabTrigger;
Tabs.Content = TabContent;

// Usage
<Tabs defaultTab="general">
  <Tabs.Trigger value="general">General</Tabs.Trigger>
  <Tabs.Trigger value="security">Security</Tabs.Trigger>
  <Tabs.Content value="general"><GeneralSettings /></Tabs.Content>
  <Tabs.Content value="security"><SecuritySettings /></Tabs.Content>
</Tabs>
```

---

## 3. Render Props

Inversion of control for flexible rendering:

```tsx
interface DataListProps<T> {
  items: T[];
  renderItem: (item: T, index: number) => React.ReactNode;
  renderEmpty?: () => React.ReactNode;
  keyExtractor: (item: T) => string;
}

function DataList<T>({ items, renderItem, renderEmpty, keyExtractor }: DataListProps<T>) {
  if (items.length === 0) {
    return renderEmpty ? <>{renderEmpty()}</> : <p>No items found.</p>;
  }
  return (
    <ul>
      {items.map((item, i) => (
        <li key={keyExtractor(item)}>{renderItem(item, i)}</li>
      ))}
    </ul>
  );
}

// Usage
<DataList
  items={users}
  keyExtractor={(u) => u.id}
  renderItem={(user) => <UserCard user={user} />}
  renderEmpty={() => <EmptyState message="No users found" />}
/>
```

---

## 4. Custom Hooks

### useToggle

```tsx
function useToggle(initial = false): [boolean, () => void, (value: boolean) => void] {
  const [value, setValue] = useState(initial);
  const toggle = useCallback(() => setValue((v) => !v), []);
  return [value, toggle, setValue];
}

// Usage
const [isOpen, toggleOpen] = useToggle(false);
```

### Data fetching — do NOT roll your own

Hand-rolling a `useQuery` hook with `useEffect` + `setState` is an anti-pattern. It misses:
- Request deduplication across components
- Background refetch on focus / reconnect / interval
- Cache invalidation + optimistic updates
- Stale-while-revalidate
- Race condition handling (stale response overwriting fresh one)
- Suspense + Error Boundary integration

**Use TanStack Query v5** (canonical) — or React Server Components for server-rendered data.

```tsx
import { useQuery } from "@tanstack/react-query";

function UserList() {
  const { data: users, isPending, error } = useQuery({
    queryKey: ["users"],
    queryFn: () => api.getUsers(),
    staleTime: 30_000, // consider fresh for 30s, skip refetch
  });

  if (isPending) return <Skeleton />;
  if (error) throw error; // let Error Boundary handle
  return <ul>{users.map((u) => <li key={u.id}>{u.name}</li>)}</ul>;
}
```

Mutations use `useMutation`. Real-time use `useSubscription` (TanStack Query v5 sync). For React Server Components, fetch directly in the async server component — no hook needed.

If you genuinely need a 5-line debounced fetch inside a single component, write `useEffect` inline — don't extract a named hook that looks like a library export.

### useDebounce

```tsx
function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
}

// Usage
function SearchInput() {
  const [query, setQuery] = useState("");
  const debouncedQuery = useDebounce(query, 300);

  useEffect(() => {
    if (debouncedQuery) {
      searchApi(debouncedQuery);
    }
  }, [debouncedQuery]);

  return <input value={query} onChange={(e) => setQuery(e.target.value)} />;
}
```

---

## 5. State Management

### Context + Reducer (Built-in, No Dependencies)

```tsx
interface AppState {
  user: User | null;
  theme: "light" | "dark";
  notifications: Notification[];
}

type AppAction =
  | { type: "SET_USER"; payload: User | null }
  | { type: "SET_THEME"; payload: "light" | "dark" }
  | { type: "ADD_NOTIFICATION"; payload: Notification }
  | { type: "DISMISS_NOTIFICATION"; payload: string };

function appReducer(state: AppState, action: AppAction): AppState {
  switch (action.type) {
    case "SET_USER":
      return { ...state, user: action.payload };
    case "SET_THEME":
      return { ...state, theme: action.payload };
    case "ADD_NOTIFICATION":
      return { ...state, notifications: [...state.notifications, action.payload] };
    case "DISMISS_NOTIFICATION":
      return { ...state, notifications: state.notifications.filter((n) => n.id !== action.payload) };
  }
}

const AppContext = createContext<{ state: AppState; dispatch: React.Dispatch<AppAction> } | null>(null);

function AppProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(appReducer, {
    user: null,
    theme: "light",
    notifications: [],
  });

  return <AppContext.Provider value={{ state, dispatch }}>{children}</AppContext.Provider>;
}

function useApp() {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error("useApp must be used within AppProvider");
  return ctx;
}
```

### Zustand (Lightweight External Store)

```tsx
import { create } from "zustand";
import { devtools, persist } from "zustand/middleware";

interface CartStore {
  items: CartItem[];
  addItem: (product: Product, quantity: number) => void;
  removeItem: (productId: string) => void;
  updateQuantity: (productId: string, quantity: number) => void;
  clearCart: () => void;
  total: () => number;
}

export const useCartStore = create<CartStore>()(
  devtools(
    persist(
      (set, get) => ({
        items: [],
        addItem: (product, quantity) =>
          set((state) => {
            const existing = state.items.find((i) => i.product.id === product.id);
            if (existing) {
              return {
                items: state.items.map((i) =>
                  i.product.id === product.id ? { ...i, quantity: i.quantity + quantity } : i
                ),
              };
            }
            return { items: [...state.items, { product, quantity }] };
          }),
        removeItem: (productId) =>
          set((state) => ({ items: state.items.filter((i) => i.product.id !== productId) })),
        updateQuantity: (productId, quantity) =>
          set((state) => ({
            items: state.items.map((i) => (i.product.id === productId ? { ...i, quantity } : i)),
          })),
        clearCart: () => set({ items: [] }),
        total: () => get().items.reduce((sum, i) => sum + i.product.price * i.quantity, 0),
      }),
      { name: "cart-storage" }
    )
  )
);

// Usage in components
function CartBadge() {
  const itemCount = useCartStore((s) => s.items.length); // only re-renders when count changes
  return <span>{itemCount}</span>;
}
```

---

## 6. Performance

### Memoization — React Compiler first

React 19's React Compiler (stable, opt-in via `babel-plugin-react-compiler`) auto-memoizes components, values, and callbacks. **For projects using the compiler, write idiomatic React and let the compiler optimize.** Manual `useMemo`/`useCallback`/`memo()` are largely unnecessary.

```tsx
// React Compiler-friendly: write naturally
function ProductList({ items, onSelect }: Props) {
  const sortedItems = items.slice().sort((a, b) => a.name.localeCompare(b.name));
  const handleSelect = (id: string) => {
    setSelectedId(id);
    onSelect?.(id);
  };
  return sortedItems.map((item) => (
    <Row key={item.id} item={item} onSelect={handleSelect} />
  ));
}
```

**Manual memoization is still appropriate when**:
1. Project does NOT use React Compiler (most legacy codebases)
2. Profiler shows a specific component re-rendering measurably hot
3. Passing a stable reference is part of the contract (e.g. `useEffect` dep, `useMemo` for a derived value used in deps)

```tsx
// Legacy / measured-hot path: manual memoization OK
const sortedItems = useMemo(
  () => items.slice().sort((a, b) => a.name.localeCompare(b.name)),
  [items]
);

const handleSelect = useCallback(
  (id: string) => {
    setSelectedId(id);
    onSelect?.(id);
  },
  [onSelect]
);

const MemoizedRow = memo(function Row({ item, onSelect }: RowProps) {
  return <tr onClick={() => onSelect(item.id)}>...</tr>;
});
```

**Anti-pattern**: blanket-wrapping every component in `memo()` "to be safe". Memoization has its own cost (reference comparison, cache storage). Profile first.

### Concurrent rendering (React 18+)

For non-urgent updates that would otherwise jank the UI:

```tsx
import { useTransition, useDeferredValue } from "react";

// useTransition — explicit non-urgent update
function SearchPage() {
  const [query, setQuery] = useState("");
  const [isPending, startTransition] = useTransition();

  return (
    <>
      <input
        value={query}
        onChange={(e) => {
          setQuery(e.target.value);              // urgent: input feedback
          startTransition(() => setResults([])); // non-urgent: clear results
        }}
      />
      {isPending && <Spinner />}
    </>
  );
}

// useDeferredValue — let React render with stale value while computing fresh
function SlowList({ filter }: { filter: string }) {
  const deferredFilter = useDeferredValue(filter);
  // expensive render uses deferredFilter, stays interactive
}
```

### Code Splitting with Lazy Loading

```tsx
const Dashboard = lazy(() => import("./pages/Dashboard"));
const Settings = lazy(() => import("./pages/Settings"));
const AdminPanel = lazy(() => import("./pages/AdminPanel"));

function App() {
  return (
    <Suspense fallback={<PageSkeleton />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/admin" element={<AdminPanel />} />
      </Routes>
    </Suspense>
  );
}
```

### Virtualization for Large Lists

```tsx
import { useVirtualizer } from "@tanstack/react-virtual";

function VirtualList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 48, // estimated row height
    overscan: 5,
  });

  return (
    <div ref={parentRef} className="h-96 overflow-auto">
      <div style={{ height: `${virtualizer.getTotalSize()}px`, position: "relative" }}>
        {virtualizer.getVirtualItems().map((virtualRow) => (
          <div
            key={virtualRow.key}
            style={{
              position: "absolute",
              top: 0,
              transform: `translateY(${virtualRow.start}px)`,
              height: `${virtualRow.size}px`,
              width: "100%",
            }}
          >
            <ItemRow item={items[virtualRow.index]} />
          </div>
        ))}
      </div>
    </div>
  );
}
```

---

## 7. Form Handling with Validation

```tsx
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";

const signupSchema = z
  .object({
    email: z.string().email("Invalid email address"),
    name: z.string().min(2, "Name must be at least 2 characters"),
    password: z.string().min(8, "Password must be at least 8 characters"),
    confirmPassword: z.string(),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Passwords do not match",
    path: ["confirmPassword"],
  });

type SignupForm = z.infer<typeof signupSchema>;

function SignupPage() {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<SignupForm>({ resolver: zodResolver(signupSchema) });

  const onSubmit = async (data: SignupForm) => {
    await api.signup(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <div>
        <label htmlFor="email">Email</label>
        <input id="email" type="email" {...register("email")} aria-invalid={!!errors.email} />
        {errors.email && <p role="alert">{errors.email.message}</p>}
      </div>

      <div>
        <label htmlFor="name">Name</label>
        <input id="name" type="text" {...register("name")} aria-invalid={!!errors.name} />
        {errors.name && <p role="alert">{errors.name.message}</p>}
      </div>

      <div>
        <label htmlFor="password">Password</label>
        <input id="password" type="password" {...register("password")} aria-invalid={!!errors.password} />
        {errors.password && <p role="alert">{errors.password.message}</p>}
      </div>

      <div>
        <label htmlFor="confirmPassword">Confirm Password</label>
        <input id="confirmPassword" type="password" {...register("confirmPassword")} aria-invalid={!!errors.confirmPassword} />
        {errors.confirmPassword && <p role="alert">{errors.confirmPassword.message}</p>}
      </div>

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? "Signing up..." : "Sign Up"}
      </button>
    </form>
  );
}
```

---

## 8. Error Boundaries

```tsx
interface ErrorBoundaryProps {
  children: React.ReactNode;
  fallback?: React.ReactNode;
  onError?: (error: Error, errorInfo: React.ErrorInfo) => void;
}

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

// Use react-error-boundary (community standard 2026). React still requires
// class boundaries internally, but the library wraps that for you with a
// functional API + reset capability + suspense integration.
import { ErrorBoundary } from "react-error-boundary";

function ErrorFallback({ error, resetErrorBoundary }: FallbackProps) {
  return (
    <div role="alert" className="p-6 bg-red-50 border border-red-200 rounded-lg">
      <h2 className="text-lg font-semibold text-red-800">Something went wrong</h2>
      <p className="mt-2 text-red-600">{error.message}</p>
      <button
        className="mt-4 px-4 py-2 bg-red-600 text-white rounded"
        onClick={resetErrorBoundary}
      >
        Try Again
      </button>
    </div>
  );
}

// Usage: wrap sections that can fail independently
function Dashboard() {
  return (
    <div className="grid grid-cols-2 gap-4">
      <ErrorBoundary FallbackComponent={ErrorFallback} onReset={() => queryClient.resetQueries()}>
        <RevenueChart />
      </ErrorBoundary>
      <ErrorBoundary FallbackComponent={ErrorFallback}>
        <UserStats />
      </ErrorBoundary>
    </div>
  );
}
```

**Pair with Suspense**: TanStack Query's `throwOnError` + Suspense + ErrorBoundary gives a clean async loading/error model.

```tsx
<ErrorBoundary FallbackComponent={ErrorFallback}>
  <Suspense fallback={<Skeleton />}>
    <UserList /> {/* useSuspenseQuery inside */}
  </Suspense>
</ErrorBoundary>
```

---

## 9. Animation Patterns (Framer Motion)

### Enter/Exit Animations

```tsx
import { motion, AnimatePresence } from "framer-motion";

function Notification({ id, message, onDismiss }: NotificationProps) {
  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: -20, scale: 0.95 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, x: 100, scale: 0.95 }}
      transition={{ type: "spring", stiffness: 300, damping: 25 }}
      className="bg-white shadow-lg rounded-lg p-4"
    >
      <p>{message}</p>
      <button onClick={() => onDismiss(id)}>Dismiss</button>
    </motion.div>
  );
}

function NotificationStack({ notifications, onDismiss }: StackProps) {
  return (
    <div className="fixed top-4 right-4 space-y-2 z-50">
      <AnimatePresence>
        {notifications.map((n) => (
          <Notification key={n.id} {...n} onDismiss={onDismiss} />
        ))}
      </AnimatePresence>
    </div>
  );
}
```

### Page Transitions

```tsx
const pageVariants = {
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 0, y: -20 },
};

function AnimatedPage({ children }: { children: React.ReactNode }) {
  return (
    <motion.div
      variants={pageVariants}
      initial="initial"
      animate="animate"
      exit="exit"
      transition={{ duration: 0.2 }}
    >
      {children}
    </motion.div>
  );
}
```

### Staggered List Animation

```tsx
const containerVariants = {
  animate: { transition: { staggerChildren: 0.05 } },
};

const itemVariants = {
  initial: { opacity: 0, y: 10 },
  animate: { opacity: 1, y: 0 },
};

function AnimatedList({ items }: { items: Item[] }) {
  return (
    <motion.ul variants={containerVariants} initial="initial" animate="animate">
      {items.map((item) => (
        <motion.li key={item.id} variants={itemVariants}>
          {item.name}
        </motion.li>
      ))}
    </motion.ul>
  );
}
```

---

## 10. Accessibility

### Keyboard Navigation

```tsx
function MenuList({ items, onSelect }: MenuListProps) {
  const [focusIndex, setFocusIndex] = useState(0);
  const refs = useRef<(HTMLButtonElement | null)[]>([]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    switch (e.key) {
      case "ArrowDown":
        e.preventDefault();
        setFocusIndex((i) => Math.min(i + 1, items.length - 1));
        break;
      case "ArrowUp":
        e.preventDefault();
        setFocusIndex((i) => Math.max(i - 1, 0));
        break;
      case "Home":
        e.preventDefault();
        setFocusIndex(0);
        break;
      case "End":
        e.preventDefault();
        setFocusIndex(items.length - 1);
        break;
      case "Enter":
      case " ":
        e.preventDefault();
        onSelect(items[focusIndex]);
        break;
    }
  };

  useEffect(() => {
    refs.current[focusIndex]?.focus();
  }, [focusIndex]);

  return (
    <div role="menu" onKeyDown={handleKeyDown}>
      {items.map((item, i) => (
        <button
          key={item.id}
          ref={(el) => { refs.current[i] = el; }}
          role="menuitem"
          tabIndex={i === focusIndex ? 0 : -1}
          onClick={() => onSelect(item)}
        >
          {item.label}
        </button>
      ))}
    </div>
  );
}
```

### Focus Management

```tsx
function Modal({ isOpen, onClose, title, children }: ModalProps) {
  const closeRef = useRef<HTMLButtonElement>(null);
  const previousFocus = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (isOpen) {
      previousFocus.current = document.activeElement as HTMLElement;
      closeRef.current?.focus();
    } else {
      previousFocus.current?.focus();
    }
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <div role="dialog" aria-modal="true" aria-labelledby="modal-title">
      <div className="fixed inset-0 bg-black/50" onClick={onClose} />
      <div className="fixed inset-0 flex items-center justify-center">
        <FocusTrap>
          <div className="bg-white rounded-lg p-6 max-w-md w-full">
            <h2 id="modal-title">{title}</h2>
            {children}
            <button ref={closeRef} onClick={onClose}>Close</button>
          </div>
        </FocusTrap>
      </div>
    </div>
  );
}
```

### Accessibility Checklist

| Area | Requirement |
|---|---|
| Semantic HTML | Use `button`, `nav`, `main`, `article`, not `div` with onClick |
| Labels | Every interactive element has an accessible name (label, aria-label) |
| Alt text | All images have descriptive alt text (or `alt=""` if decorative) |
| Color contrast | Minimum 4.5:1 for normal text, 3:1 for large text (WCAG AA) |
| Keyboard | All interactive elements reachable and operable with keyboard only |
| Focus visible | Focus indicator visible on all interactive elements |
| Focus trap | Modals and dialogs trap focus within them |
| Focus restore | Return focus to trigger element when modal closes |
| Error states | Use `aria-invalid`, `aria-describedby`, `role="alert"` |
| Live regions | Use `aria-live` for dynamic content updates |
| Skip links | Provide "skip to main content" link at page top |
| Reduced motion | Respect `prefers-reduced-motion` media query |
