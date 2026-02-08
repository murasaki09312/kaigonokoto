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
- `/app/users`

## Behavior checks

1. `admin@example.com` でログイン
2. `/app/users` で一覧取得できる
3. 「新規ユーザー」ダイアログでユーザー作成できる
4. `staff@example.com` でログインすると「新規ユーザー」ボタンは無効表示になる
