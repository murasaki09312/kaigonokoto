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

### Troubleshooting: 500 on login

If `POST /auth/login` returns `500` and `log/development.log` shows
`ActiveRecord::ConnectionNotEstablished` or `PG::ConnectionBad`, PostgreSQL is not reachable.

1. Start PostgreSQL (local service or Docker).
2. Set DB env vars when using Docker:
   - `PGHOST=127.0.0.1`
   - `PGUSER=postgres`
   - `PGPASSWORD=postgres`
3. Run:
   - `bin/rails db:create db:migrate db:seed`

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
  - `clients:read`
  - `clients:manage`
  - `contracts:read`
  - `contracts:manage`
  - `today_board:read`
  - `attendances:manage`
  - `care_records:manage`
  - `reservations:read`
  - `reservations:manage`
  - `reservations:override_capacity`
  - `tenants:manage`
  - `system:audit_read`
- Roles:
  - `admin`: 全 permission
  - `staff`: `users:read` / `clients:read` / `contracts:read` / `today_board:read` / `attendances:manage` / `care_records:manage` / `reservations:read`

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
- `GET /clients/:client_id/contracts` (requires `contracts:read`)
- `POST /clients/:client_id/contracts` (requires `contracts:manage`)
- `GET /clients/:client_id/contracts/:id` (requires `contracts:read`)
- `PATCH /clients/:client_id/contracts/:id` (requires `contracts:manage`)
- `GET /reservations` (requires `reservations:read`)
- `POST /reservations` (requires `reservations:manage`)
- `POST /reservations/generate` (requires `reservations:manage`)
- `POST /api/v1/reservations/generate` (requires `reservations:manage`, alias)
- `GET /reservations/:id` (requires `reservations:read`)
- `PATCH /reservations/:id` (requires `reservations:manage`)
- `DELETE /reservations/:id` (requires `reservations:manage`)
- `GET /api/v1/today_board` (requires `today_board:read`)
- `PUT /api/v1/reservations/:reservation_id/attendance` (requires `attendances:manage`)
- `PUT /api/v1/reservations/:reservation_id/care_record` (requires `care_records:manage`)

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

### 7) Contracts Index (requires `contracts:read`)

```bash
curl -s "http://localhost:3000/clients/1/contracts?as_of=2026-02-01" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

### 8) Contracts Create (requires `contracts:manage`)

```bash
curl -s -X POST http://localhost:3000/clients/1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"start_on":"2026-03-01","weekdays":[1,3,5],"services":{"meal":true,"bath":false},"shuttle_required":true}'
```

### 9) Reservations Index (requires `reservations:read`)

```bash
curl -s "http://localhost:3000/reservations?from=2026-03-01&to=2026-03-07" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

### 10) Reservations Create (requires `reservations:manage`)

```bash
curl -s -X POST http://localhost:3000/reservations \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"client_id":1,"service_date":"2026-03-03","start_time":"09:30","end_time":"16:00"}'
```

### 11) Reservations Generate (requires `reservations:manage`)

```bash
curl -s -X POST http://localhost:3000/reservations/generate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"start_on":"2026-03-01","end_on":"2026-03-31","start_time":"09:30","end_time":"16:00"}'
```

`generate` は指定期間に有効な契約（`contracts.weekdays`）を参照して、対象利用者の予約を一括生成します。
- 既存予約がある利用者/日付はスキップ
- 定員超過日はベストエフォートでスキップし、`meta.capacity_skipped_dates` に返却
- 管理者が `force=true` を指定した場合のみ定員超過日も作成

### 12) Today Board (requires `today_board:read`)

```bash
curl -s "http://localhost:3000/api/v1/today_board?date=2026-02-24" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

### 13) Attendance Upsert (requires `attendances:manage`)

```bash
curl -s -X PUT "http://localhost:3000/api/v1/reservations/1/attendance" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status":"present","note":"到着済み"}'
```

### 14) Care Record Upsert (requires `care_records:manage`)

```bash
curl -s -X PUT "http://localhost:3000/api/v1/reservations/1/care_record" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"body_temperature":36.6,"care_note":"バイタル安定"}'
```

## RBAC Design

- `Role` はグローバル
- `Permission` はグローバル（例: `users:read`）
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
- `ContractPolicy`
  - `index/show`: `contracts:read`
  - `create/update`: `contracts:manage`
  - `Scope`: `user.tenant_id` で限定
- `ReservationPolicy`
  - `index/show`: `reservations:read`
  - `create/update/destroy/generate`: `reservations:manage`
  - `override_capacity?`: `reservations:override_capacity` or `tenants:manage`
  - `Scope`: `user.tenant_id` で限定
- `TodayBoardPolicy`
  - `index`: `today_board:read`
- `AttendancePolicy`
  - `upsert`: `attendances:manage`
  - Reservation/Attendance の `tenant_id` 一致を要求
- `CareRecordPolicy`
  - `upsert`: `care_records:manage`
  - Reservation/CareRecord の `tenant_id` 一致を要求

## Tenant Isolation Policy

- ログイン時に `tenant_slug` を受け取り、JWTに `tenant_id` と `user_id` を埋め込み
- 以降のリクエストは `Authorization: Bearer` の token だけを真実として扱う
- `ApplicationController#authenticate_request` で `Current.tenant` / `Current.user` を確定
- `UsersController#show/update` は必ず `current_tenant.users.find(params[:id])`
  - 他テナントIDを指定しても `404 Not Found`
- `UsersController#index` は `policy_scope(User)` で current tenant のみ返却
- `ContractsController` は `current_tenant.clients.find(params[:client_id])` と
  `current_tenant.contracts.find_by!(id:, client_id:)` を使い、他テナント参照は `404`

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
- `/app/today-board` (当日ボード: 出欠・ケア記録)
- `/app/clients` (一覧 + 作成/編集/削除)
- `/app/clients/:id` (詳細 + 契約/利用プラン履歴 + 改定追加/編集)
- `/app/reservations` (日/週表示 + 単発作成 + 繰り返し生成 + 定員表示)
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
6. `/app/clients/:id` で契約履歴が表示され、admin が契約の作成/編集できることを確認する
7. `/app/today-board` で当日の予定一覧、出欠更新、ケア記録更新ができることを確認する
8. `staff@example.com` でログインし、当日ボードで出欠/記録を更新できることを確認する
9. `/app/reservations` で日/週切替、単発作成、繰り返し生成、日別 `利用数/定員` 表示を確認する
10. 定員到達日に通常作成すると `capacity_exceeded` となり、override権限ユーザーのみ force 作成できることを確認する
11. `/app/users` で staff の作成権限がないことを確認する

### CORS

`rack-cors` を導入し、`config/initializers/cors.rb` で `http://localhost:5173` を許可しています。
