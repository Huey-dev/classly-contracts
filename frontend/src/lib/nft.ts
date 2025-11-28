
// ========================================
// NFT OFF-CHAIN FUNCTIONS
// frontend/src/lib/nft.ts
// ========================================

import { Lucid, Data, UTxO, Address, PolicyId, MintingPolicy, Unit, Constr } from 'lucid-cardano';
import { getNFTPolicy, getNFTPolicyId } from './contracts';

// ========================================
// TYPES - FIXED
// ========================================

// Define the redeemer schema directly without Data.Enum
const MintRedeemerSchema = Data.Object({
  Teacher_address: Data.Bytes(),
  classroom_id: Data.Bytes(),
  utxo_ref: Data.Object({
    transaction_id: Data.Object({ hash: Data.Bytes() }),
    output_index: Data.Integer(),
  }),
});

// For the burn case, we'll use a simple constructor approach

// ========================================
// MINT CLASSROOM NFT
// ========================================

export interface MintNFTParams {
  lucid: Lucid;
  teacherAddress: Address;
  classroomId: string;
  oneTimeUtxo: UTxO;
}

/**
 * Mint unique classroom NFT
 */
export async function mintClassroomNFT(params: MintNFTParams): Promise<{
  txHash: string;
  policyId: PolicyId;
  assetName: string;
  unit: Unit;
}> {
  const { lucid, teacherAddress, classroomId, oneTimeUtxo } = params;

  try {
    // Generate NFT asset name
    const assetName = 'CLASSROOM_' + classroomId;
    const assetNameHex = Buffer.from(assetName).toString('hex');

    // Get policy
    const mintingPolicy: MintingPolicy = {
      type: 'PlutusV2',
      script: getNFTPolicy(),
    };

    const policyId = lucid.utils.mintingPolicyToId(mintingPolicy);
    const unit: Unit = policyId + assetNameHex;

    // Get teacher credential
    const teacherCredential = lucid.utils.getAddressDetails(teacherAddress)
      .paymentCredential!.hash;

    // Create mint redeemer (Constructor 0 for Mint variant)
    const mintRedeemerData = {
      Teacher_address: teacherCredential,
      classroom_id: classroomId,
      utxo_ref: {
        transaction_id: { hash: oneTimeUtxo.txHash },
        output_index: BigInt(oneTimeUtxo.outputIndex),
      },
    };

    const redeemer = Data.to(
      new Constr(0, [Data.to(mintRedeemerData, MintRedeemerSchema)])
    );
    

    console.log('🎨 Minting classroom NFT...');
    console.log(`   Name: ${assetName}`);
    console.log(`   Policy: ${policyId.slice(0, 20)}...`);

    // Build transaction
    const tx = await lucid
      .newTx()
      .collectFrom([oneTimeUtxo]) // Consume unique UTXO
      .attachMintingPolicy(mintingPolicy)
      .mintAssets({ [unit]: 1n }, redeemer)
      .payToAddress(teacherAddress, { [unit]: 1n })
      .addSigner(teacherAddress)
      .complete();

    // Sign and submit
    const signedTx = await tx.sign().complete();
    const txHash = await signedTx.submit();

    console.log('✅ NFT minted!');
    console.log(`   TxHash: ${txHash}`);
    console.log(`   Unit: ${unit}`);

    return { txHash, policyId, assetName, unit };
  } catch (error: any) {
    console.error('❌ Failed to mint NFT:', error);
    throw new Error(error.message || 'Failed to mint NFT');
  }
}

// ========================================
// BURN CLASSROOM NFT
// ========================================

export interface BurnNFTParams {
  lucid: Lucid;
  ownerAddress: Address;
  nftUtxo: UTxO;
  policyId: PolicyId;
  assetName: string;
}

/**
 * Burn classroom NFT (owner only)
 */
export async function burnClassroomNFT(params: BurnNFTParams): Promise<string> {
  const { lucid, ownerAddress, nftUtxo, policyId, assetName } = params;

  try {
    // Create unit
    const assetNameHex = Buffer.from(assetName).toString('hex');
    const unit: Unit = policyId + assetNameHex;

    // Create burn redeemer (Constructor 1 for Burn variant)
    const redeemer = Data.to(new Constr(1, []));

    // Create minting policy
    const mintingPolicy: MintingPolicy = {
      type: 'PlutusV2',
      script: getNFTPolicy(),
    };

    console.log('🔥 Burning classroom NFT...');
    console.log(`   Name: ${assetName}`);

    // Build transaction
    const tx = await lucid
      .newTx()
      .collectFrom([nftUtxo]) // Spend UTXO containing NFT
      .attachMintingPolicy(mintingPolicy)
      .mintAssets({ [unit]: -1n }, redeemer) // Negative = burn
      .complete();

    // Sign and submit
    const signedTx = await tx.sign().complete();
    const txHash = await signedTx.submit();

    console.log('✅ NFT burned!');
    console.log(`   TxHash: ${txHash}`);

    return txHash;
  } catch (error: any) {
    console.error('❌ Failed to burn NFT:', error);
    throw new Error(error.message || 'Failed to burn NFT');
  }
}

// ========================================
// QUERY FUNCTIONS
// ========================================

/**
 * Get all NFTs owned by address for specific policy
 */
export async function getOwnedNFTs(
  lucid: Lucid,
  ownerAddress: Address,
  policyId: PolicyId
): Promise<Array<{ unit: Unit; assetName: string; utxo: UTxO }>> {
  try {
    const utxos = await lucid.utxosAt(ownerAddress);
    const nfts: Array<{ unit: Unit; assetName: string; utxo: UTxO }> = [];

    for (const utxo of utxos) {
      for (const [unit, amount] of Object.entries(utxo.assets)) {
        if (unit.startsWith(policyId) && amount > 0n) {
          const assetNameHex = unit.slice(policyId.length);
          const assetName = Buffer.from(assetNameHex, 'hex').toString();

          nfts.push({ unit, assetName, utxo });
        }
      }
    }

    return nfts;
  } catch (error) {
    console.error('❌ Failed to get owned NFTs:', error);
    return [];
  }
}

/**
 * Check if address owns specific NFT
 */
export async function hasNFT(
  lucid: Lucid,
  ownerAddress: Address,
  policyId: PolicyId,
  assetName: string
): Promise<boolean> {
  try {
    const assetNameHex = Buffer.from(assetName).toString('hex');
    const unit: Unit = policyId + assetNameHex;

    const utxos = await lucid.utxosAt(ownerAddress);
    return utxos.some((utxo) => utxo.assets[unit] >= 1n);
  } catch (error) {
    console.error('❌ Failed to check NFT:', error);
    return false;
  }
}

/**
 * Find UTXO containing specific NFT
 */
export async function findNFTUtxo(
  lucid: Lucid,
  ownerAddress: Address,
  policyId: PolicyId,
  assetName: string
): Promise<UTxO | null> {
  try {
    const assetNameHex = Buffer.from(assetName).toString('hex');
    const unit: Unit = policyId + assetNameHex;

    const utxos = await lucid.utxosAt(ownerAddress);
    return utxos.find((utxo) => utxo.assets[unit] >= 1n) || null;
  } catch (error) {
    console.error('❌ Failed to find NFT UTXO:', error);
    return null;
  }
}

// ========================================
// UTILITY FUNCTIONS
// ========================================

/**
 * Select a unique UTXO from wallet for minting
 */
export async function selectUniqueUtxo(lucid: Lucid): Promise<UTxO> {
  const utxos = await lucid.wallet.getUtxos();

  if (utxos.length === 0) {
    throw new Error('No UTXOs available in wallet');
  }

  // Prefer pure ADA UTXO
  const pureAdaUtxo = utxos.find(
    (utxo) =>
      Object.keys(utxo.assets).length === 1 && utxo.assets.lovelace >= 2_000_000n
  );

  if (pureAdaUtxo) return pureAdaUtxo;

  // Fallback: any UTXO with sufficient ADA
  const anyUtxo = utxos.find((utxo) => utxo.assets.lovelace >= 2_000_000n);

  if (!anyUtxo) {
    throw new Error('No suitable UTXO found (need at least 2 ADA)');
  }

  return anyUtxo;
}

/**
 * Generate unique classroom ID
 */
export function generateClassroomId(
  subject: string,
  courseNumber: string,
  teacherId: string
): string {
  const timestamp = Date.now();
  return `${subject}_${courseNumber}_${teacherId.slice(0, 8)}_${timestamp}`;
}

/**
 * Validate classroom ID format
 */
export function isValidClassroomId(classroomId: string): boolean {
  // Alphanumeric and underscores only, max 32 chars
  return /^[A-Za-z0-9_]{1,32}$/.test(classroomId);
}