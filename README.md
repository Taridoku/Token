# AztecToken

An Aztec.nr fungible token example with public balances, private note balances, authwit-enabled delegated actions, and tests for public/private transfer flows.

## Contracts

- `token@Token`: the main token contract.
- `burner@Burner`: helper contract used to test contract-mediated private burns.
- `caller_contract@CallerContract`: helper contract used to test forwarded private calls and authwit behavior.

For normal deployment, you usually only need `token@Token`. The other two contracts are test helpers.

## Token Features

- Public and private minting by the deployer/minter.
- Public and private burning.
- Public-to-public transfers.
- Public allowance transfers with `approve` and `transfer_from_pub2pub`.
- Shielding and unshielding via public/private transfers.
- Private-to-private transfers backed by `BalanceSet` notes.
- One-shot delegated actions through Aztec authwits.
- Recursive private note spending for balances split across many notes.

## Project Layout

```text
.
├── Nargo.toml
├── token/
│   ├── Nargo.toml
│   └── src/
│       ├── main.nr
│       └── test/
├── burner/
│   ├── Nargo.toml
│   └── src/
└── caller_contract/
    ├── Nargo.toml
    └── src/
```

Generated `target/` artifacts are ignored and should be rebuilt locally.

## Requirements

- Aztec CLI / wallet installed.
- `aztec` and `nargo` available on your path.
- This repo currently uses Aztec.nr `v4.2.0` dependencies in the package manifests.

## Build

```sh
aztec compile
```

## Test

Run the full workspace test suite:

```sh
aztec test
```

For quieter output:

```sh
env LOG_LEVEL=error AZTEC_LOG_LEVEL=error aztec test --format terse
```

Expected passing counts at the time of writing:

- `burner`: 3 tests
- `caller_contract`: 0 tests
- `token`: 42 tests

Some replay tests intentionally trigger duplicate-nullifier failures. The tests pass, but the TXE may still print a `world-state:database` error log while proving that replay/double-spend protection works.

## Deploy Token

Set your testnet node URL:

```sh
export NODE_URL=https://rpc.testnet.aztec-labs.com
```

Deploy only the main token contract:

```sh
aztec-wallet deploy token@Token \
  --node-url "$NODE_URL" \
  --from accounts: ** \
  --payment method=fee_juice \
  --alias token \
  --args Token TOK 18
```

Replace `**` with your own deployed account alias.

# Token
