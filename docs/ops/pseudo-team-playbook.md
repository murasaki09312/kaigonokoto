# Pseudo-team Playbook (Codex)

このドキュメントは、擬似チーム運用の最小セットを1ページで辿れるようにするための入口です。

## 目的
- Architect / QA / Security / Builder / Reviewer の役割分担を固定する
- 会議で決めた内容を Decision Log に落として実装へ渡す
- PR までの品質ゲートをテンプレ運用で標準化する

## 関連ファイル
- ルール本体: [AGENTS.md](../../AGENTS.md)
- 決定ログ: [docs/ops/decision-log-template.md](./decision-log-template.md)
- 役割プロンプト
  - [docs/prompt/roles/architect.md](../prompt/roles/architect.md)
  - [docs/prompt/roles/qa.md](../prompt/roles/qa.md)
  - [docs/prompt/roles/security.md](../prompt/roles/security.md)
  - [docs/prompt/roles/builder.md](../prompt/roles/builder.md)
  - [docs/prompt/roles/reviewer.md](../prompt/roles/reviewer.md)
- PR テンプレ: [.github/pull_request_template.md](../../.github/pull_request_template.md)
- レビュー依頼文テンプレ: [docs/prompt/review-request-template.md](../prompt/review-request-template.md)

## 標準フロー
1. Architect / QA / Security が並列でレビュー素材を作成
2. PO が Decision Log を確定
3. Builder が worktree で実装し PR を作成
4. Reviewer が PR レビュー
5. PO が最終判断してマージ

## 運用手順（最小）
1. 対象チケットを決め、worktree を作成する
2. Architect / QA / Security のテンプレをコピーして会議ログを作る
3. [Decision Log テンプレ](./decision-log-template.md) に決定内容を記入する
4. Builder が Decision Log を入力に実装・テスト・PR 作成する
5. Reviewer が指摘と改善案を返し、必要修正後に再レビューする
6. PO が承認してマージし、次タスクへ進む

## 命名規約
- ブランチ接頭辞: `feat/` `fix/` `chore/` `docs/` `test/`
- worktree: `../wt/<TICKET>-<role>-<slug>`

