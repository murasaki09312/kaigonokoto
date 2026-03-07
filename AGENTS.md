# Codex Project Instructions (chosyu_nanbanren)

## Review-request prompt format (MUST)
When asked to create a "reviewer prompt / レビューワー依頼文":
1) You MUST use `docs/prompt/review-request-template.md` as the output structure.
2) Fill all placeholders using the PR context (title, URL, changed files, goals, root cause, key changes, review focus).
3) Output MUST be valid Markdown.
4) Keep headings and section order exactly as the template.
5) If any detail is unknown, write it as `未確認:` with a short note, and list it under "動作確認（最小）".

## Style
- Be concise and concrete.
- Prefer bullet lists.
- When referencing files, use inline code paths like `wp-content/...`.

## Pseudo-team workflow (Codex)

このリポジトリでは、Codexを役割別に運用し「会議→決定ログ→実装→レビュー」を標準フローとする。

### Roles (threads)
- Architect: 設計/影響範囲/落とし穴の事前整理
- QA: 受け入れ条件のテスト化、テストケース/回帰観点
- Security: RBAC/マルチテナント/リダイレクトなどの脅威分析
- Builder: 実装（branch→commit→push→PR）まで完了
- Reviewer: PRレビュー（指摘→改善提案）

役割の固定プロンプトは `docs/prompt/roles/*.md` を使用する。

### Worktree / Branch naming
- Branch prefix: feat/ fix/ chore/ docs/ test/
- Worktree dir: ../wt/<TICKET>-<role>-<slug>
  - 例: ../wt/KK-012-builder-post-login-redirect

### Decision Log
- 決定は `docs/ops/decision-log-template.md` に従って記録し、Builderへの入力とする。

### PR template
- PR本文は `.github/pull_request_template.md` を使用し、チェックリストを満たすこと。

### Order of operations (recommended)
1) Architect/QA/Security が並列でレビュー素材を作成
2) 人間（PO）がDecision Logを確定
3) Builderがworktreeで実装→PR作成
4) ReviewerがPRレビュー
5) 人間（PO）が最終判断しマージ

### Playbook
- 導入手順と運用導線は `docs/ops/pseudo-team-playbook.md` を参照する。
