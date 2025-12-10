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

## Address
addr_test1wpc980vyehhh685s6hhjxf87nfyg475kfrldcfudk2ey9tqwldddc

## Hash
7053bd84cdef7d1e90d5ef2324fe9a488afa9648fedc278db2b242ac


# Next.js Integration Guide for Cardano Smart Contract

Here is how to integrate your Cardano smart contract with a Next.js frontend:

## Prerequisites

1. **Development Environment**
   - Node.js (v18+)
   - NPM or Yarn
   - Cardano wallet (Nami, Eternl, or similar)

## Step 1: Create a New Next.js Project

```bash
npx create-next-app@latest classly-frontend --typescript --tailwind --eslint
cd classly-frontend
```

## Step 2: Install Dependencies

```bash
npm install @emurgo/cardano-serialization-lib-browser @emurgo/cardano-message-signing-browser lucid-cardano buffer
```

## Step 3: Configure Next.js

1. Update `next.config.mjs` to handle Node.js modules:

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  webpack: (config) => {
    config.resolve.fallback = { 
      ...config.resolve.fallback,
      fs: false,
      net: false,
      tls: false,
      crypto: require.resolve('crypto-browserify'),
      stream: require.resolve('stream-browserify'),
      buffer: require.resolve('buffer/'),
    };
    return config;
  },
  // Enable server components external packages
  experimental: {
    serverComponentsExternalPackages: ['lucid-cardano'],
  },
};

export default nextConfig;
```

2. Create a global type declaration file `src/types/global.d.ts`:

```typescript
// Add Buffer to global scope
declare global {
  interface Window {
    Buffer: any;
    cardano: any;
  }
}

export {};
```

## Step 4: Create Cardano Service

Create `src/lib/cardano.ts`:

```typescript
import { Lucid, Blockfrost } from "lucid-cardano";

// Initialize Lucid with Blockfrost
export const initLucid = async (walletName = 'nami') => {
  try {
    const lucid = await Lucid.new(
      new Blockfrost(
        process.env.NEXT_PUBLIC_BLOCKFROST_URL!,
        process.env.NEXT_PUBLIC_BLOCKFROST_API_KEY!
      ),
      process.env.NEXT_PUBLIC_NETWORK as any || "Preview"
    );
    
    const api = await window.cardano[walletName].enable();
    lucid.selectWallet(api);
    
    return lucid;
  } catch (error) {
    console.error("Error initializing Lucid:", error);
    throw error;
  }
};
```

## Step 5: Create Contract Types

Create `src/contracts/escrow.ts`:

```typescript
import { Data } from "lucid-cardano";

// Define the datum type to match your Aiken contract
export const EscrowDatum = Data.Object({
  receiver: Data.Bytes(),
  oracle: Data.Bytes(),
  net_total: Data.Integer(),
  paid_count: Data.Integer(),
  paid_out: Data.Integer(),
  released30: Data.Boolean(),
  released40: Data.Boolean(),
  releasedFinal: Data.Boolean(),
  comments: Data.Integer(),
  rating_sum: Data.Integer(),
  rating_count: Data.Integer(),
  all_watch_met: Data.Boolean(),
  first_watch: Data.Integer(),
  dispute_by: Data.Integer(),
});

// Define the redeemer type
export const Redeemer = Data.Enum([
  Data.Object({
    AddPayment: Data.Tuple([
      Data.Object({
        net_amount: Data.Integer(),
        watch_met: Data.Boolean(),
        rating_x10: Data.Integer(),
        commented: Data.Boolean(),
        first_watch_at: Data.Integer(),
      })
    ])
  }),
  Data.Object({ ReleaseInitial: Data.Tuple([]) }),
  Data.Object({ ReleaseMetrics40: Data.Tuple([]) }),
  Data.Object({ ReleaseFinal: Data.Tuple([]) }),
  Data.Object({ Refund: Data.Tuple([]) }),
  Data.Object({ DisputeHold: Data.Tuple([]) }),
]);

// Helper function to create a payment datum
export const createPaymentDatum = (params: {
  receiver: string;
  oracle: string;
  netTotal?: bigint;
  paidCount?: number;
  paidOut?: number;
  released30?: boolean;
  released40?: boolean;
  releasedFinal?: boolean;
  comments?: number;
  ratingSum?: number;
  ratingCount?: number;
  allWatchMet?: boolean;
  firstWatch?: number;
  disputeBy?: number;
}) => {
  return {
    receiver: params.receiver,
    oracle: params.oracle,
    net_total: params.netTotal ?? 0n,
    paid_count: params.paidCount ?? 0,
    paid_out: params.paidOut ?? 0,
    released30: params.released30 ?? false,
    released40: params.released40 ?? false,
    releasedFinal: params.releasedFinal ?? false,
    comments: params.comments ?? 0,
    rating_sum: params.ratingSum ?? 0,
    rating_count: params.ratingCount ?? 0,
    all_watch_met: params.allWatchMet ?? false,
    first_watch: params.firstWatch ?? 0,
    dispute_by: params.disputeBy ?? 0,
  };
};
```

## Step 6: Create Custom Hooks

Create `src/hooks/useEscrow.ts`:

```typescript
'use client';

import { useState, useEffect } from 'react';
import { initLucid } from '@/lib/cardano';
import { EscrowDatum, Redeemer, createPaymentDatum } from '@/contracts/escrow';
import { Data, Lucid } from 'lucid-cardano';

export const useEscrow = () => {
  const [lucid, setLucid] = useState<Lucid | null>(null);
  const [address, setAddress] = useState<string>('');
  const [isConnected, setIsConnected] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Check for wallet connection on mount
  useEffect(() => {
    const checkConnection = async () => {
      if (window.cardano?.nami) {
        try {
          const lucidInstance = await initLucid('nami');
          setLucid(lucidInstance);
          const address = await lucidInstance.wallet.address();
          setAddress(address);
          setIsConnected(true);
        } catch (err) {
          console.error('Wallet connection error:', err);
        }
      }
    };
    
    checkConnection();
  }, []);

  const connectWallet = async (walletName = 'nami') => {
    try {
      setLoading(true);
      setError(null);
      
      if (!window.cardano) {
        throw new Error('No Cardano wallet extension found');
      }
      
      if (!window.cardano[walletName]) {
        throw new Error(`${walletName} wallet not installed`);
      }
      
      const lucidInstance = await initLucid(walletName);
      const address = await lucidInstance.wallet.address();
      
      setLucid(lucidInstance);
      setAddress(address);
      setIsConnected(true);
      return true;
    } catch (err: any) {
      console.error('Error connecting wallet:', err);
      setError(err.message || 'Failed to connect wallet');
      return false;
    } finally {
      setLoading(false);
    }
  };

  const addPayment = async (escrowAddress: string, amount: bigint, datumParams: any) => {
    if (!lucid) throw new Error('Wallet not connected');
    
    try {
      setLoading(true);
      setError(null);
      
      const datum = createPaymentDatum(datumParams);
      
      const tx = await lucid
        .newTx()
        .payToContract(
          escrowAddress,
          { inline: Data.to(datum, EscrowDatum) },
          { lovelace: amount }
        )
        .complete();
      
      const signedTx = await tx.sign().complete();
      const txHash = await signedTx.submit();
      return txHash;
    } catch (err: any) {
      console.error('Error adding payment:', err);
      setError(err.message || 'Failed to add payment');
      throw err;
    } finally {
      setLoading(false);
    }
  };

  const releaseFunds = async (escrowAddress: string, releaseType: 'initial' | 'metrics' | 'final') => {
    if (!lucid) throw new Error('Wallet not connected');
    
    try {
      setLoading(true);
      setError(null);
      
      let redeemer;
      switch (releaseType) {
        case 'initial':
          redeemer = Data.to({ ReleaseInitial: [] }, Redeemer);
          break;
        case 'metrics':
          redeemer = Data.to({ ReleaseMetrics40: [] }, Redeemer);
          break;
        case 'final':
          redeemer = Data.to({ ReleaseFinal: [] }, Redeemer);
          break;
        default:
          throw new Error('Invalid release type');
      }

      // You'll need to fetch the UTXOs at the script address first
      // This is a simplified example - you'll need to adjust based on your contract
      const utxos = await lucid.utxosAt(escrowAddress);
      
      const tx = await lucid
        .newTx()
        .collectFrom(utxos, redeemer)
        .attachSpendingValidator(escrowAddress)
        .complete();
      
      const signedTx = await tx.sign().complete();
      const txHash = await signedTx.submit();
      return txHash;
    } catch (err: any) {
      console.error('Error releasing funds:', err);
      setError(err.message || 'Failed to release funds');
      throw err;
    } finally {
      setLoading(false);
    }
  };

  return {
    connectWallet,
    addPayment,
    releaseFunds,
    address,
    isConnected,
    loading,
    error,
  };
};
```

## Step 7: Create UI Components

Create `src/components/EscrowInterface.tsx`:

```tsx
'use client';

import { useState } from 'react';
import { useEscrow } from '@/hooks/useEscrow';

export default function EscrowInterface() {
  const { 
    connectWallet, 
    addPayment, 
    releaseFunds, 
    address, 
    isConnected, 
    loading, 
    error 
  } = useEscrow();
  
  const [amount, setAmount] = useState<string>('');
  const [txHash, setTxHash] = useState<string>('');

  const handleAddPayment = async () => {
    if (!amount) return;
    
    try {
      const tx = await addPayment(
        process.env.NEXT_PUBLIC_ESCROW_ADDRESS!,
        BigInt(amount),
        {
          receiver: process.env.NEXT_PUBLIC_RECEIVER_ADDRESS!,
          oracle: process.env.NEXT_PUBLIC_ORACLE_PUBKEY!,
          netTotal: BigInt(amount),
        }
      );
      setTxHash(tx);
    } catch (err) {
      console.error(err);
    }
  };

  const handleRelease = async (type: 'initial' | 'metrics' | 'final') => {
    try {
      const tx = await releaseFunds(process.env.NEXT_PUBLIC_ESCROW_ADDRESS!, type);
      setTxHash(tx);
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <div className="max-w-4xl mx-auto p-6">
      <h1 className="text-3xl font-bold mb-8">Classly Escrow Platform</h1>
      
      {!isConnected ? (
        <div className="text-center p-8 border-2 border-dashed rounded-lg">
          <h2 className="text-xl font-semibold mb-4">Connect Your Wallet</h2>
          <button
            onClick={() => connectWallet()}
            disabled={loading}
            className="bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 disabled:opacity-50"
          >
            {loading ? 'Connecting...' : 'Connect Wallet'}
          </button>
          {error && <p className="mt-2 text-red-500">{error}</p>}
        </div>
      ) : (
        <div className="space-y-8">
          <div className="bg-white p-6 rounded-lg shadow-md">
            <h2 className="text-xl font-semibold mb-4">Wallet Connected</h2>
            <p className="font-mono text-sm bg-gray-100 p-3 rounded break-all">
              {address}
            </p>
          </div>

          <div className="bg-white p-6 rounded-lg shadow-md">
            <h2 className="text-xl font-semibold mb-4">Add Payment</h2>
            <div className="flex flex-col sm:flex-row gap-4">
              <input
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="Amount in lovelace"
                className="flex-1 p-3 border rounded-lg"
                disabled={loading}
              />
              <button
                onClick={handleAddPayment}
                disabled={loading || !amount}
                className="bg-green-600 text-white px-6 py-3 rounded-lg hover:bg-green-700 disabled:opacity-50"
              >
                {loading ? 'Processing...' : 'Add Payment'}
              </button>
            </div>
          </div>

          <div className="bg-white p-6 rounded-lg shadow-md">
            <h2 className="text-xl font-semibold mb-4">Release Funds</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <button
                onClick={() => handleRelease('initial')}
                disabled={loading}
                className="bg-purple-600 text-white p-4 rounded-lg hover:bg-purple-700 disabled:opacity-50"
              >
                Release Initial 30%
              </button>
              <button
                onClick={() => handleRelease('metrics')}
                disabled={loading}
                className="bg-purple-600 text-white p-4 rounded-lg hover:bg-purple-700 disabled:opacity-50"
              >
                Release Metrics 40%
              </button>
              <button
                onClick={() => handleRelease('final')}
                disabled={loading}
                className="bg-purple-600 text-white p-4 rounded-lg hover:bg-purple-700 disabled:opacity-50"
              >
                Release Final 30%
              </button>
            </div>
          </div>

          {txHash && (
            <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
              <p className="text-green-700 font-medium">Transaction successful!</p>
              <a
                href={`https://cardanoscan.io/transaction/${txHash}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-blue-600 hover:underline mt-2 inline-block"
              >
                View on Cardanoscan
              </a>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
```

## Step 8: Update the Home Page

Update `app/page.tsx`:

```tsx
import EscrowInterface from '@/components/EscrowInterface';

export default function Home() {
  return (
    <main className="min-h-screen bg-gray-50 py-12">
      <div className="container mx-auto px-4">
        <EscrowInterface />
      </div>
    </main>
  );
}
```

## Step 9: Create Environment Variables

Create a `.env.local` file in your project root:

```env
# Blockfrost API
NEXT_PUBLIC_BLOCKFROST_URL=https://cardano-preview.blockfrost.io/api/v0
NEXT_PUBLIC_BLOCKFROST_API_KEY=your_blockfrost_api_key
NEXT_PUBLIC_NETWORK=Preview

# Contract Addresses
NEXT_PUBLIC_ESCROW_ADDRESS=your_escrow_contract_address
NEXT_PUBLIC_RECEIVER_ADDRESS=receiver_address
NEXT_PUBLIC_ORACLE_PUBKEY=oracle_public_key
```

## Step 10: Run the Development Server

```bash
npm run dev
```

Your Next.js application should now be running at `http://localhost:3000`.

## Key Features of This Implementation:

1. **Next.js 14 with App Router**: Modern React framework with server components and improved performance.

2. **Type Safety**: Full TypeScript support with proper type definitions.

3. **Responsive Design**: Mobile-first approach with Tailwind CSS.

4. **Error Handling**: Comprehensive error handling and user feedback.

5. **Wallet Integration**: Seamless integration with Cardano wallets (Nami, Eternl, etc.).

6. **Environment Variables**: Secure configuration management.

7. **Modular Architecture**: Separated concerns with custom hooks and components.

## Next Steps:

1. **Add More Wallets**: Extend the wallet connection to support multiple wallets (Eternl, Flint, etc.).

2. **Transaction History**: Implement a transaction history component.

3. **Loading States**: Add more detailed loading states and progress indicators.

4. **Error Boundaries**: Implement error boundaries for better error handling.

5. **Testing**: Add unit and integration tests.

6. **Deployment**: Deploy to Vercel or your preferred hosting provider.

7. **Analytics**: Add analytics to track user interactions.

This implementation provides a solid foundation for your Next.js application to interact with your Cardano smart contract. Let me know if you need any clarification or have questions about specific parts of the implementation!