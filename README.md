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

`db/stock.csv` contains the opening stock list. Pink and Mirror SKUs use the `SAU-PINK-...` and `SAU-MIRROR-...` prefixes; blank quantities are treated as zero, and the strap opens with 40. Opening movements use a fixed seed reference so reseeding does not duplicate them.

## Using the app

- Choose Ship, Return good, or Return damaged and scan the barcode into the focused SKU field. A good return adds one unit back into stock; a damaged return records the item without adding stock.
- The optional order/tracking reference remains in the field after every scan. Referenced returns must match an unreturned shipment for the same variant and reference.
- Stock is calculated from movements. The stock page shows all variants and highlights stock at or below each variant's threshold.
- History can be filtered by reference. The Labels page prints Code 128 labels sized 60 × 30 mm.
- The stock dashboard shows unit-based movement metrics, charts, quantity reorder estimates, and recent activity. Money metrics are kept in the owner-only Finance section; the Finance overview currently displays cost-based stock valuation when variant cost prices are configured. Income, expenses, cash, carrier balances, and pots require finance tracking records, which are not yet implemented.
- Finance owners can record expenses in `/finance/expenses`, either one per line with preview/category/account selection or through the single-expense form. Amounts are stored as integer cents; run `bin/rails db:seed` to install the starter expense categories, keyword matches, and Cash/Bank accounts.

Create the first login through environment variables (`STOCK_APP_EMAIL` and `STOCK_APP_PASSWORD`) before running the seed task. Do not put production passwords in source control.

## Dokku

The `Procfile` runs `db:prepare` as the release command and Puma as the web process. Provision a PostgreSQL service, link it to the app so Dokku supplies `DATABASE_URL`, and set `RAILS_MASTER_KEY`, `STOCK_APP_EMAIL`, and `STOCK_APP_PASSWORD` through Dokku config (never commit these values). On the first deployment, run `dokku run <app> bin/rails db:seed` to load the catalog and opening movements; reseeding is safe.
