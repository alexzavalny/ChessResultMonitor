# Repository Guidelines

Follow these notes to contribute changes that fit the Chess Result Monitor codebase and ship without surprises.

## Project Structure & Module Organization
- Core entry point is `main.rb`; shared logic lives in `lib/`.
- Monitoring flow sits in `lib/chess_result_monitor.rb` with supporting namespaces under `lib/models`, `lib/scraper`, `lib/telegram`, and `lib/utils`.
- Configuration lives in `config/` (`bot_config.rb`, `tournament_config.rb`); runtime data persists in `data/` and logs in `logs/`.
- Specs mirror the library layout under `spec/`; align new tests with the directories they exercise.

## Build, Test, and Development Commands
- `bundle install` to sync gems (run after changes to `Gemfile` or a fresh checkout).
- `./setup.sh` performs the common bootstrap: dependency install plus `data/` and `logs/` directories.
- `ruby main.rb` runs the Telegram monitor; export required tokens before launching.
- `bundle exec rspec` runs the full RSpec suite; use `bundle exec rspec spec/path/to_file_spec.rb` while iterating.
- `bundle exec rubocop` enforces formatting and lint rules; run before opening a pull request.

## Coding Style & Naming Conventions
- Ruby 3.0+ with 2-space indentation; prefer early returns, guard clauses, and small service objects.
- Match existing naming: classes and modules in `CamelCase`, methods and variables in `snake_case`, files matching their class/module names.
- Keep Telegram message helpers tidy—`lib/utils/message_formatter.rb` aims for readable columns, so adjust constants rather than hardcoding widths.
- Let RuboCop surface style drift; do not disable cops unless the change affects multiple call sites.

## Testing Guidelines
- Specs belong beside the code under test (`lib/telegram/...` → `spec/telegram/...`); name files `*_spec.rb`.
- Use descriptive example names (`it 'notifies subscribers on table change'`) and prefer shared helpers over duplication.
- Run `bundle exec rspec` locally before pushing; keep the suite green and add coverage when changing scraping or formatting behaviour.

## Commit & Pull Request Guidelines
- Follow the existing Git history: imperative, scope-focused messages (`Add debug logging for message formatting`) and one concern per commit.
- Reference issues where applicable and note user-facing behaviour in the body.
- Pull requests should summarize the change impact, list manual verification (e.g., command output), and attach screenshots when UI-rich logs change.

## Configuration & Secrets
- Required environment: `CHESSRESULTS_TELEGRAM_TOKEN`; optional: `TELEGRAM_CHAT_IDS` for pre-seeded subscribers.
- Never commit real tokens or cached `data/state_cache.json`. Use sample values in docs and redact logs before sharing.
