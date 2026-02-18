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
