# Client API Example

`client/src/api.ts` contains a minimal TypeScript API client for:

- `login(tenantSlug, email, password)`
- `me()`
- `listUsers()`
- `createUser(payload)`

Token handling uses `localStorage` when available.

Example usage:

```ts
import { login, me, listUsers, createUser } from "./src/api";

await login("demo-dayservice", "admin@example.com", "Password123!");
const current = await me();
const users = await listUsers();
const created = await createUser({
  name: "New User",
  email: "new@example.com",
  password: "Password123!",
});
```
