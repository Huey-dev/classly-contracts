// ========================================
// LUCID INITIALIZATION
// frontend/src/lib/lucid.ts
// ========================================

import { Blockfrost, Lucid } from 'lucid-cardano';

const BLOCKFROST_URL = `https://cardano-${import.meta.env.VITE_NETWORK.toLowerCase()}.blockfrost.io/api/v0`;
const BLOCKFROST_API_KEY = import.meta.env.VITE_BLOCKFROST_API_KEY;
const NETWORK = import.meta.env.VITE_NETWORK as 'Preview' | 'Mainnet';

// Track if Lucid is already initialized
let lucidInstance: Lucid | null = null;

/**
 * Initialize Lucid instance with Blockfrost provider
 * Call this once when app starts
 */
export async function initLucid(): Promise<Lucid> {
  // Return existing instance if already initialized
  if (lucidInstance) {
    console.log('✅ Using existing Lucid instance');
    return lucidInstance;
  }

  try {
    console.log('🔄 Initializing Lucid...');
    console.log(`📡 Network: ${NETWORK}`);
    console.log(`🔗 Blockfrost URL: ${BLOCKFROST_URL}`);

    // Verify Blockfrost API key
    if (!BLOCKFROST_API_KEY || BLOCKFROST_API_KEY === 'undefined') {
      throw new Error('Blockfrost API key not configured. Check your .env file.');
    }

    // Create Blockfrost provider
    const provider = new Blockfrost(BLOCKFROST_URL, BLOCKFROST_API_KEY);

    // Initialize Lucid (WASM is now handled by vite-plugin-wasm)
    lucidInstance = await Lucid.new(provider, NETWORK);
    
    console.log('✅ Lucid initialized successfully');
    
    return lucidInstance;
  } catch (error: any) {
    console.error('❌ Failed to initialize Lucid:', error);
    console.error('Error details:', {
      message: error.message,
      stack: error.stack,
      blockfrostUrl: BLOCKFROST_URL,
      hasApiKey: !!BLOCKFROST_API_KEY,
      apiKeyLength: BLOCKFROST_API_KEY?.length || 0,
      network: NETWORK,
    });
    
    // Provide more helpful error messages
    let errorMessage = 'Failed to initialize Lucid';
    
    if (error.message.includes('transactionbuilderconfigbuilder_new')) {
      errorMessage = 'WASM module initialization failed. Try clearing cache and refreshing.';
    } else if (error.message.includes('fetch') || error.message.includes('Failed to fetch')) {
      errorMessage = 'Network error. Check your Blockfrost API key and internet connection.';
    } else if (error.message.includes('API key') || error.message.includes('Invalid project')) {
      errorMessage = 'Invalid Blockfrost API key. Get one from https://blockfrost.io';
    }
    
    throw new Error(`${errorMessage}: ${error.message || 'Unknown error'}`);
  }
}

/**
 * Get current Lucid instance (must be initialized first)
 */
export function getLucid(): Lucid {
  if (!lucidInstance) {
    throw new Error('Lucid not initialized. Call initLucid() first.');
  }
  return lucidInstance;
}

/**
 * Reset Lucid instance (useful for testing or reconnecting)
 */
export function resetLucid(): void {
  lucidInstance = null;
}

/**
 * Connect wallet to Lucid
 * @param lucid - Lucid instance
 * @param walletName - Wallet extension name
 */
export async function connectWallet(
  lucid: Lucid,
  walletName: 'nami' | 'eternl' | 'flint' | 'lace'
): Promise<string> {
  try {
    // Check if wallet is installed
    if (!window.cardano || !window.cardano[walletName]) {
      throw new Error(`${walletName} wallet not installed`);
    }

    console.log(`🔄 Connecting to ${walletName} wallet...`);

    // Enable wallet
    const api = await window.cardano[walletName].enable();
    lucid.selectWallet(api);

    // Get wallet address
    const address = await lucid.wallet.address();
    
    console.log('✅ Wallet connected');
    console.log(`👛 Address: ${address.slice(0, 20)}...`);
    
    return address;
  } catch (error: any) {
    console.error('❌ Failed to connect wallet:', error);
    throw new Error(error.message || 'Failed to connect wallet');
  }
}

/**
 * Get wallet balance
 */
export async function getWalletBalance(lucid: Lucid): Promise<{
  lovelace: bigint;
  assets: Record<string, bigint>;
}> {
  try {
    const utxos = await lucid.wallet.getUtxos();
    
    let lovelace = 0n;
    const assets: Record<string, bigint> = {};
    
    for (const utxo of utxos) {
      lovelace += utxo.assets.lovelace;
      
      for (const [unit, amount] of Object.entries(utxo.assets)) {
        if (unit === 'lovelace') continue;
        assets[unit] = (assets[unit] || 0n) + amount;
      }
    }
    
    return { lovelace, assets };
  } catch (error) {
    console.error('❌ Failed to get balance:', error);
    throw error;
  }
}

/**
 * Type declarations for Cardano wallet
 */
declare global {
  interface Window {
    cardano?: {
      nami?: any;
      eternl?: any;
      flint?: any;
      lace?: any;
    };
  }
}

export type WalletName = 'nami' | 'eternl' | 'flint' | 'lace';

/**
 * Check if wallet is installed
 */
export function isWalletInstalled(walletName: WalletName): boolean {
  return !!(window.cardano && window.cardano[walletName]);
}

/**
 * Get list of installed wallets
 */
export function getInstalledWallets(): WalletName[] {
  const wallets: WalletName[] = [];
  
  if (isWalletInstalled('nami')) wallets.push('nami');
  if (isWalletInstalled('eternl')) wallets.push('eternl');
  if (isWalletInstalled('flint')) wallets.push('flint');
  if (isWalletInstalled('lace')) wallets.push('lace');
  
  return wallets;
}

/**
 * Verify Blockfrost connection
 */
export async function verifyBlockfrostConnection(): Promise<boolean> {
  try {
    const response = await fetch(`${BLOCKFROST_URL}/health`, {
      headers: {
        project_id: BLOCKFROST_API_KEY,
      },
    });
    
    if (response.ok) {
      console.log('✅ Blockfrost connection verified');
      return true;
    } else {
      console.error('❌ Blockfrost connection failed:', response.status);
      return false;
    }
  } catch (error) {
    console.error('❌ Failed to verify Blockfrost connection:', error);
    return false;
  }
}