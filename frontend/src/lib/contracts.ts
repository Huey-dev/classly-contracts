// ========================================
// CONTRACT LOADER
// frontend/src/lib/contracts.ts
// ========================================

import { Lucid, SpendingValidator, MintingPolicy, Address, PolicyId } from 'lucid-cardano';
import plutusJson from '../../plutus.json';

/**
 * Get compiled escrow validator script
 */
export function getEscrowValidator(): string {
  const validator = plutusJson.validators.find(
    (v: any) => v.title === 'escrow.escrow_validator.spend'
  );
  
  if (!validator) {
    throw new Error('Escrow validator not found in plutus.json');
  }
  
  return validator.compiledCode;
}

/**
 * Get escrow script address
 */
export function getEscrowAddress(lucid: Lucid): Address {
  const validator: SpendingValidator = {
    type: 'PlutusV2',
    script: getEscrowValidator(),
  };
  
  return lucid.utils.validatorToAddress(validator);
}

/**
 * Get compiled NFT minting policy script
 */
export function getNFTPolicy(): string {
  const policy = plutusJson.validators.find(
    (v: any) => v.title === 'classroom_nft.classroom_nft_policy.mint'
  );
  
  if (!policy) {
    throw new Error('NFT policy not found in plutus.json');
  }
  
  return policy.compiledCode;
}

/**
 * Get NFT policy ID
 */
export function getNFTPolicyId(lucid: Lucid): PolicyId {
  const policy: MintingPolicy = {
    type: 'PlutusV2',
    script: getNFTPolicy(),
  };
  
  return lucid.utils.mintingPolicyToId(policy);
}

/**
 * Get compiled reputation validator script
 */
export function getReputationValidator(): string {
  const validator = plutusJson.validators.find(
    (v: any) => v.title === 'reputation.reputation_validator.spend'
  );
  
  if (!validator) {
    throw new Error('Reputation validator not found in plutus.json');
  }
  
  return validator.compiledCode;
}

/**
 * Get reputation script address
 */
export function getReputationAddress(lucid: Lucid): Address {
  const validator: SpendingValidator = {
    type: 'PlutusV2',
    script: getReputationValidator(),
  };
  
  return lucid.utils.validatorToAddress(validator);
}

/**
 * Get all contract addresses at once
 */
export function getAllContractAddresses(lucid: Lucid): {
  escrowAddress: Address;
  nftPolicyId: PolicyId;
  reputationAddress: Address;
} {
  return {
    escrowAddress: getEscrowAddress(lucid),
    nftPolicyId: getNFTPolicyId(lucid),
    reputationAddress: getReputationAddress(lucid),
  };
}

/**
 * Log all contract information
 */
export function logContractInfo(lucid: Lucid): void {
  const addresses = getAllContractAddresses(lucid);
  
  console.log('📜 Contract Addresses:');
  console.log(`   Escrow: ${addresses.escrowAddress}`);
  console.log(`   NFT Policy: ${addresses.nftPolicyId}`);
  console.log(`   Reputation: ${addresses.reputationAddress}`);
}