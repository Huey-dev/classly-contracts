# 🎓 Classroom Escrow - Aiken Smart Contracts

Decentralized classroom payment system on Cardano featuring escrow, NFT ownership, and on-chain reputation.

## 📁 Project Structure

```
classroom-escrow/
├── aiken.toml                    # Project configuration
├── README.md                     # This file
├── validators/
│   ├── escrow.ak                # Payment escrow contract
│   ├── classroom_nft.ak         # NFT minting policy
│   └── reputation.ak            # Reputation system
└── lib/
    └── classroom/
        ├── types.ak             # Shared type definitions
        ├── utils.ak             # Helper functions
        └── constants.ak         # System constants
```

## 🚀 Quick Start

### Prerequisites

- Aiken v1.0.0 or higher
- Cardano node (optional, for testing)

### Installation

```bash
# Install Aiken
curl -sSfL https://install.aiken-lang.org | bash

# Clone and setup project
git clone <your-repo>
cd classroom-escrow

# Check project
aiken check

# Build contracts
aiken build
```

This generates `plutus.json` with compiled validators.

## 📜 Contracts Overview

### 1. Escrow Contract (`validators/escrow.ak`)

**Purpose:** Securely holds student payments until conditions are met.

**Functions:**
- `lock()` - Student locks ADA payment in escrow
- `release()` - Teacher claims funds (requires NFT ownership)
- `refund()` - Student gets refund after deadline

**Key Features:**
- NFT-gated fund release
- Time-locked refunds
- Multi-signature support

### 2. Classroom NFT (`validators/classroom_nft.ak`)

**Purpose:** Mints unique NFTs representing classroom ownership.

**Functions:**
- `mint()` - Creates unique classroom NFT
- `burn()` - Destroys NFT (owner-only)

**Key Features:**
- Uniqueness guarantee via one-time UTXO
- Teacher ownership verification
- CIP-25 compatible metadata

### 3. Reputation System (`validators/reputation.ak`)

**Purpose:** Stores immutable teacher ratings on-chain.

**Functions:**
- `anchor()` - Students add ratings (1-5 stars)
- `initialize()` - Teacher sets up reputation

**Key Features:**
- Cumulative rating calculation
- Version tracking
- Tamper-proof storage

## 🔧 Building & Testing

### Build All Contracts

```bash
aiken build
```

Output: `plutus.json` containing all compiled validators.

### Check Syntax

```bash
aiken check
```

### Run Tests (when available)

```bash
aiken test
```

## 📊 Contract Specifications

### Escrow Datum

```aiken
type EscrowDatum {
  student_address: Address,
  teacher_address: Address,
  locked_amount: Int,
  classroom_nft_policy: PolicyId,
  classroom_nft_asset_name: AssetName,
  refund_deadline: Int,
}
```

### Reputation Datum

```aiken
type ReputationDatum {
  teacher_address: Address,
  total_rating_sum: Int,
  total_ratings_count: Int,
  last_updated: Int,
  version: Int,
}
```

## 🎯 Usage Examples

### Escrow Flow

```
1. Student locks 100 ADA for classroom
2. Teacher teaches the class
3. Teacher releases funds (must own NFT)
4. Student rates teacher (1-5 stars)
```

### Alternative: Refund Flow

```
1. Student locks 100 ADA
2. Class is cancelled
3. Deadline passes
4. Student requests refund
```

## 🔐 Security Features

- **Double-spend protection** - UTXO model
- **NFT verification** - Proves classroom ownership
- **Time-locks** - Deadline-based refunds
- **Signature requirements** - Both parties must authorize
- **Immutable ratings** - Cannot be deleted or modified

## 📝 Constants & Configuration

See `lib/classroom/constants.ak` for configurable values:

- Minimum escrow: 2 ADA
- Default deadline: 30 days
- Rating range: 1-5 stars
- Max students: 100 per classroom

## 🛠 Development

### Adding New Features

1. Create new function in appropriate validator
2. Update types in `lib/classroom/types.ak`
3. Add utilities to `lib/classroom/utils.ak`
4. Rebuild with `aiken build`

### Code Style

- Use descriptive function names
- Add comments for complex logic
- Follow Aiken best practices
- Keep functions pure when possible

## 🧪 Testing Strategy

### Unit Tests

- Test each validator function independently
- Mock transaction contexts
- Verify all validation paths

### Integration Tests

- Test complete transaction flows
- Use real UTXO data
- Verify state transitions

## 📈 Gas Optimization

- Minimize list operations
- Use early returns
- Inline small functions
- Batch similar checks

## 🚀 Deployment

### Testnet Deployment

```bash
# Build contracts
aiken build

# Extract validator hashes
cat plutus.json | jq '.validators[] | {title, hash}'

# Deploy with cardano-cli or off-chain code
```

### Mainnet Deployment

1. Complete security audit
2. Test thoroughly on testnet
3. Build production contracts
4. Deploy validators
5. Verify on CardanoScan

## 📚 Documentation

- [Aiken Language Guide](https://aiken-lang.org)
- [Cardano Developer Portal](https://developers.cardano.org)
- [Smart Contract Best Practices](https://docs.cardano.org/smart-contracts)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Run `aiken check`
5. Submit pull request

## 📄 License

MIT License - see LICENSE file

## 🐛 Known Issues

- None currently

## 🔄 Changelog

### v1.0.0
- Initial release
- Escrow contract with lock/release/refund
- NFT minting with uniqueness guarantee
- Reputation system with on-chain ratings

## 📞 Support

- GitHub Issues: <your-repo>/issues
- Discord: #classroom-escrow
- Email: support@yourproject.com

## 🎓 Educational Resources

### Learning Aiken

- [Aiken Tutorial](https://aiken-lang.org/getting-started)
- [Example Projects](https://github.com/aiken-lang)
- [Community Examples](https://discord.gg/aiken)

### Understanding Validators

- Spending validators control UTXOs
- Minting policies control token creation
- Redeemers specify actions
- Datums store state

## ⚠️ Important Notes

1. Always test on testnet first
2. Audit contracts before mainnet
3. Keep private keys secure
4. Monitor contract addresses
5. Have emergency procedures

## 🎯 Roadmap

- [ ] Add multi-classroom batch operations
- [ ] Implement dispute resolution
- [ ] Add refund partial amounts
- [ ] Create governance token
- [ ] Build DAO for platform decisions

---

**Built with ❤️ by classly team using Aiken and Cardano**