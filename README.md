# Classly Smart Contracts

> Cardano smart contracts powering trustless course payments and NFT certificates

## Table of Contents
- [Overview](#overview)
- [Validators](#validators)
- [Getting Started](#getting-started)
- [Testing](#testing)
- [Contributing](#contributing)

## Overview

This repository contains the Aiken smart contracts that power Classly's trustless education platform. The contracts implement:

- **Escrow Payment System** - Securely lock payments until course milestones are met
- **NFT Certificate Minting** - Issue verifiable course completion and attendance certificates
- **Merkle Proof Verification** - Efficient branching algorithm for batch certificate validation

**Related:** [Classly Frontend](https://github.com/Huey-dev/classly)

## Validators

### 1. Escrow Validator (`validators/escrow.ak`)
- **Purpose:** Holds course payment in escrow until completion conditions are met
- **Type:** Spending Validator
- **Logic:** 
  - Locks funds with seller (tutor) and buyer (student) addresses
  - Releases payment when student confirms course completion
  - Validates both parties sign the transaction
- **Address:** `addr_test1...` (testnet - generate after build)

### 2. Course NFT Policy (`validators/course_nft.ak`)
- **Purpose:** Mints NFT certificates for course attendance and completion
- **Type:** Minting Validator
- **Logic:**
  - Validates merkle proof for batch certificate minting
  - Ensures one NFT per student per course
  - Includes course metadata in token name
- **Policy ID:** (generate after build)

## Getting Started

### Prerequisites

- Aiken v1.0.0+
- Cardano Node (for deployment)

### Installation

```bash
# Clone the repo
git clone https://github.com/Huey-dev/classly-contracts.git
cd classly-contracts

# Check Aiken installation
aiken --version
```

### Build

```bash
aiken build
```

This generates `plutus.json` with compiled validators.

### Generate Addresses & Policy IDs

```bash
# Generate escrow script address
aiken blueprint address -v classly_contracts.escrow.spend

# Generate NFT minting policy ID
aiken blueprint policy -v classly_contracts.course_nft.mint
```

## Testing

Run all tests:
```bash
aiken check
```

Run specific module tests:
```bash
aiken check -m escrow
aiken check -m course_nft
```

Run with trace output for debugging:
```bash
aiken check -m trace
```

## Project Structure

```
classly-contracts/
├── validators/
│   ├── escrow.ak           # Escrow payment validator
│   └── course_nft.ak       # NFT certificate minting policy
├── lib/
│   └── merkle.ak           # Merkle proof utilities (if needed)
├── aiken.toml              # Project configuration
└── plutus.json             # Compiled output (generated)
```

## Deployment

### Testnet Deployment

1. Build contracts: `aiken build`
2. Generate addresses and policy IDs (see above)
3. Fund addresses with test ADA from [Cardano Testnet Faucet](https://docs.cardano.org/cardano-testnet/tools/faucet/)
4. Integrate addresses/policy IDs into frontend

### Mainnet Deployment

(To be documented after testnet validation)

## Contributing

### Branch Naming

- `feature/validator-name` - new validators or features
- `fix/bug-description` - bug fixes
- `test/what-youre-testing` - test improvements
- `docs/what-you-updated` - documentation

### Testing Guidelines

- Write at least 2 success tests per validator
- Write failure tests for each validation condition
- Use descriptive test names: `test_escrow_buyer_claims_success()`
- Add trace messages for debugging: `trace @"Checking payment"`
- Test edge cases (e.g., insufficient payment, wrong signer)

### Commit Convention

```bash
git commit -m "feat: add merkle proof validation to NFT policy"
git commit -m "test: add failure case for insufficient escrow payment"
git commit -m "fix: correct signature verification in escrow"
```

## Learning Resources

- [Aiken Language Tour](https://aiken-lang.org/language-tour)
- [Cardano Plutus Docs](https://plutus.cardano.org/)
- [Module M001: Writing Your First Validator](./docs/m001.md)
- [Module M002: Testing with Mock Transactions](./docs/m002.md)

## License

MIT

---

Built with Aiken for the Cardano blockchain 🔗
