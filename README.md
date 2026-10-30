# Stock tracker

A private Rails inventory app for scanning barcode-labelled variants while shipping and receiving returns.

## Requirements

- Ruby 3.3
- PostgreSQL

## Local setup

1. Install dependencies with `bundle install`.
2. Create a PostgreSQL role/database accessible to your local user (or set `DATABASE_URL`).
3. Set the initial user's credentials in the environment, then prepare the database:

   ```sh
   export STOCK_APP_EMAIL="you@example.com"
   export STOCK_APP_PASSWORD="use-a-long-unique-password"
   bin/rails db:prepare
   bin/rails db:seed
   ```

   The seed creates the user only if one does not already exist. The app redirects unauthenticated visitors to the sign-in page.
4. Start Rails with `bin/dev` and open `http://localhost:3000`. The root URL redirects to `/dashboard`.
5. Run tests with `bin/rails test`.

`db/stock.csv` contains the opening stock list. Phone-case SKUs use `SAU-<DESIGN>-...`, for example `SAU-PINK-...`, `SAU-MIRROR-...`, `SAU-BLUE-...`, and `SAU-LENS-...`; blank quantities are treated as zero, and the strap opens with 40. Opening movements use a fixed seed reference so reseeding does not duplicate them.

## Using the app

- Choose Ship, Return good, or Return damaged and scan the barcode into the focused SKU field. A good return adds one unit back into stock; a damaged return records the item without adding stock.
- The optional order/tracking reference remains in the field after every scan. Referenced returns must match an unreturned shipment for the same variant and reference.
- Stock is calculated from movements. The stock page shows all variants and highlights stock at or below each variant's threshold.
- History can be filtered by reference. The Labels page prints Code 128 labels sized 60 × 30 mm.
- The stock dashboard shows unit-based movement metrics, charts, quantity reorder estimates, and recent activity. Money metrics and recorded expenses are kept in the owner-only Finance section; the overview displays cost-based stock valuation when variant cost prices are configured.
- Finance owners can record expenses in `/finance/expenses`, either one per line with preview/category/account selection or through the single-expense form. Amounts are stored as integer cents; run `bin/rails db:seed` to install the starter expense categories, keyword matches, and Cash/Bank accounts.

## Ask ChatGPT about stock and expenses

The app exposes a read-only MCP server for ChatGPT at `/api/mcp`. It provides `get_inventory` (current quantity by SKU, optionally one SKU) and `get_expenses` (monthly total and category breakdown; defaults to the current month). Expense totals follow the Finance report and exclude stock purchase costs and transfers.

To connect it:

1. Deploy the app at a public HTTPS address.
2. Generate a long random key, for example with `openssl rand -hex 32`, and set it as `CHATGPT_MCP_API_KEY` in the app's environment. On Dokku, use `dokku config:set <app> CHATGPT_MCP_API_KEY=<generated-key>`. Keep this key private; rotate it by replacing the environment value and updating the ChatGPT connection.
3. In ChatGPT, add a custom MCP server/plugin using `https://<your-app-domain>/api/mcp`, configure Bearer authentication with the same key, and enable the read-only tools.
4. Select the connected app in a chat when you want fresh data; you can ask questions such as “How many units are left?” or “How much did I spend this month?”

The MCP connection is read-only and cannot change stock or financial records. ChatGPT connects to remote HTTPS MCP servers; local-only app instances need a public deployment or a supported secure tunnel. Availability and setup controls depend on the ChatGPT plan and workspace permissions. See [OpenAI's current custom MCP connection guide](https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt). The equivalent bearer-authenticated HTTP endpoints are also documented in `docs/chatgpt-openapi.yaml`.

Create the first login through environment variables (`STOCK_APP_EMAIL` and `STOCK_APP_PASSWORD`) before running the seed task. Do not put production passwords in source control.

## Dokku

The `Procfile` runs `db:prepare` as the release command and Puma as the web process. Provision a PostgreSQL service, link it to the app so Dokku supplies `DATABASE_URL`, and set `RAILS_MASTER_KEY`, `STOCK_APP_EMAIL`, and `STOCK_APP_PASSWORD` through Dokku config (never commit these values). On the first deployment, run `dokku run <app> bin/rails db:seed` to load the catalog and opening movements; reseeding is safe.
