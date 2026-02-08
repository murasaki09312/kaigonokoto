# kaigonokoto (Rails API)

デイサービス顧客管理アプリ `kaigonokoto` の基盤として、以下を実装しています。

- シングルDB `tenant_id` 方式のマルチテナント
- JWT 認証（`tenant_slug + email + password`）
- Pundit + RBAC（Role / Permission）
- RSpec request spec による 401 / 403 / テナント越境防止の保証

## Tech Stack

- Rails 8 (API mode)
- PostgreSQL
- JWT (`jwt` gem)
- Authorization (`pundit` gem)
- Test (`rspec-rails`)
- Minimal TS API client (`/client/src/api.ts`)

## Setup

```bash
export RBENV_VERSION=3.3.6
eval "$(rbenv init - zsh)"

bundle install
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
bin/rails s
```

Docker 上の PostgreSQL を使う場合は、以下を付与してください。

```bash
export PGHOST=127.0.0.1
export PGUSER=postgres
export PGPASSWORD=postgres
```

別ターミナルでテスト:

```bash
export RBENV_VERSION=3.3.6
eval "$(rbenv init - zsh)"
bin/rails spec
```

## Seed Data

`bin/rails db:seed` で以下を作成します。

- Tenant: `demo-dayservice`
- Admin user: `admin@example.com` / `Password123!`
- Staff user: `staff@example.com` / `Password123!`
- Permissions:
  - `users:read`
  - `users:manage`
  - `tenants:manage`
  - `system:audit_read`
- Roles:
  - `admin`: 全 permission
  - `staff`: `users:read` のみ

## API Endpoints

- `POST /auth/login`
- `GET /auth/me` (returns `user` and `permissions`)
- `POST /auth/logout`
- `GET /tenants` (requires `tenants:manage`)
- `POST /tenants` (requires `tenants:manage`)
- `GET /users`
- `POST /users`
- `GET /users/:id`
- `PATCH /users/:id`
- `GET /clients` (requires `clients:read`)
- `POST /clients` (requires `clients:manage`)
- `GET /clients/:id` (requires `clients:read`)
- `PATCH /clients/:id` (requires `clients:manage`)
- `DELETE /clients/:id` (requires `clients:manage`)

エラー形式は統一しています。

```json
{
  "error": {
    "code": "forbidden",
    "message": "Forbidden"
  }
}
```

## curl Examples

### 1) Login

```bash
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"tenant_slug":"demo-dayservice","email":"admin@example.com","password":"Password123!"}' \
  | ruby -rjson -e 'puts JSON.parse(STDIN.read)["token"]')

echo "$TOKEN"
```

### 2) Me

```bash
curl -s http://localhost:3000/auth/me \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

### 3) Users Index (current tenant only)

```bash
curl -s http://localhost:3000/users \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

### 4) Users Create (requires `users:manage`)

```bash
curl -s -X POST http://localhost:3000/users \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Created User","email":"created@example.com","password":"Password123!"}'
```

### 5) Clients Index (supports `q` and `status`)

```bash
curl -s "http://localhost:3000/clients?q=山田&status=active" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

### 6) Clients Create (requires `clients:manage`)

```bash
curl -s -X POST http://localhost:3000/clients \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"新規 利用者","kana":"シンキ リヨウシャ","phone":"090-1234-5678","status":"active"}'
```

## RBAC Design

- `Role` はグローバル
- `Permission` はグローバル（例: `users:read`）
- `Permission` はグローバル（例: `users:read`, `clients:manage`）
- `User` は 1 tenant 所属
- `UserRole`, `RolePermission` で多対多を構成
- `User#allowed?(permission_key)` で権限判定

主要ポリシー:

- `UsersPolicy`
  - `index/show`: `users:read`
  - `create/update`: `users:manage`
  - `Scope`: `user.tenant_id` で限定
- `ClientPolicy`
  - `index/show`: `clients:read`
  - `create/update/destroy`: `clients:manage`
  - `Scope`: `user.tenant_id` で限定
- `TenantsPolicy`
  - `index/create`: `tenants:manage`

## Tenant Isolation Policy

- ログイン時に `tenant_slug` を受け取り、JWTに `tenant_id` と `user_id` を埋め込み
- 以降のリクエストは `Authorization: Bearer` の token だけを真実として扱う
- `ApplicationController#authenticate_request` で `Current.tenant` / `Current.user` を確定
- `UsersController#show/update` は必ず `current_tenant.users.find(params[:id])`
  - 他テナントIDを指定しても `404 Not Found`
- `UsersController#index` は `policy_scope(User)` で current tenant のみ返却

## TypeScript Client

`/client/src/api.ts` に最小クライアントを用意しています。

- `login(tenantSlug, email, password)`
- `me()`
- `listUsers()`
- `createUser(payload)`

token は `localStorage`（利用可能な環境）とメモリに保存し、`Authorization: Bearer` を自動付与します。

## Frontend (UI Verification)

`/frontend` に Vite + React + TypeScript の管理画面UIを追加しています。

- `/login`
- `/app` (Dashboard)
- `/app/clients` (一覧 + 作成/編集/削除)
- `/app/clients/:id` (詳細)
- `/app/users` (一覧 + 作成ダイアログ)

### Frontend Setup

```bash
cd /Users/hyomaeda/program/codex/kaigonokoto/frontend
cp .env.example .env
npm install
npm run dev
```

- Rails API: `http://localhost:3000`
- Frontend: `http://localhost:5173`
- `.env`: `VITE_API_BASE_URL=http://localhost:3000`

### UI 動作確認手順

1. Rails を起動して `db:seed` 実行済みにする
2. Frontend を `npm run dev` で起動する
3. `demo-dayservice / admin@example.com / Password123!` でログインする
4. `/app/clients` で利用者一覧が表示されることを確認する
5. adminで利用者の作成/編集/削除ができることを確認する
6. `staff@example.com` でログインし、利用者作成ボタンが無効表示になることを確認する
7. `/app/users` でも staff の作成権限がないことを確認する

### CORS

`rack-cors` を導入し、`config/initializers/cors.rb` で `http://localhost:5173` を許可しています。
