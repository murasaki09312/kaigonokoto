# kaigonokoto Frontend

Vite + React + TypeScript で作成した UI 検証用フロントエンドです。

- Tailwind CSS
- shadcn/ui (Radix)
- React Router
- React Query
- react-hook-form + zod
- sonner toast
- Light/Dark theme (localStorage保存)

## Setup

```bash
cd frontend
cp .env.example .env
npm install
npm run dev
```

Frontend: [http://localhost:5173](http://localhost:5173)

`.env`:

```bash
VITE_API_BASE_URL=http://localhost:3000
```

## Demo Login

- tenant_slug: `demo-dayservice`
- email: `admin@example.com`
- password: `Password123!`

## Pages

- `/login`
- `/app` (dashboard)
- `/app/clients` (利用者一覧)
- `/app/clients/:id` (利用者詳細)
- `/app/users`

## Behavior checks

1. `admin@example.com` でログイン
2. `/app/users` で一覧取得できる
3. `/app/clients` で利用者一覧が取得できる
4. admin で利用者の作成/編集/削除ができる
5. `staff@example.com` でログインすると利用者の作成/編集/削除ができない
