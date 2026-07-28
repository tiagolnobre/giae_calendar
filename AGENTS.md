# Deploy Flow

## When there are new migrations

1. Ensure `bin/release` contains `./bin/rails db:migrate:primary` (not `db:migrate` — with multiple databases the generic task may not apply all migrations)
2. Commit all changes including `bin/release`
3. Run `fly deploy` — the release command will run migrations before starting the app
4. The release machine runs `bin/release` (via `release_command` in `fly.toml`), then the web machines are updated with rolling strategy
5. **After deploy, verify migrations were applied** — if the rolling update didn't restart the web machine, run manually:
   ```
   bin/rails db:migrate:primary
   ```
   Or via SSH:
   ```
   fly ssh console -C "bin/rails db:migrate:primary"
   ```

## Verification

- Run `rails test` locally before deploying
- After deploy, check `fly logs` for migration output and ensure no `ActiveRecord::StatementInvalid` errors
