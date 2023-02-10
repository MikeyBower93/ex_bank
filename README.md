# ExBank

## Intro

This is a project used to demonstrate how to use distributed patterns in Elixir, specifically to solve for distributed payments across multiple systems, and how to make them scalable and reliable. It involves the use of several patterns
- Outbox pattern
- Saga (compensation transactions)
- Postgres transactions/atomic increments
- Rate limiting
- Circuit breaker pattern
- Eventual consistency

The project works by emulating a bank styled system, where a customer has an account, which has money in it (a balance), and that customer can send money from that account to another account via a sort code and account number, however to do this we need to decrease the balance in our system, and notify a payment provider to move the money to this new account, which requires some special attention to distributed patterns.

## How to Run
1. Install `asdf` and specifically the `elixir` and `erlang` plugin.
2. Run `asdf install` which will install the versions.
3. Run `docker compose up`, this will start the services (`postgres`).
4. Run `mix test` which will run the tests (which is how we simulate this project).