// ========================================
// ESCROW OFF-CHAIN FUNCTIONS
// frontend/src/lib/escrow.ts
// ========================================

import { Lucid, Data, UTxO, Address, PolicyId, Constr } from 'lucid-cardano';
import { getEscrowValidator, getEscrowAddress } from './contracts';

// ========================================
// TYPES
// ========================================

const EscrowDatumSchema = Data.Object({
  student_address: Data.Bytes(),
  teacher_address: Data.Bytes(),
  locked_amount: Data.Integer(),
  classroom_nft_policy: Data.Bytes(),
  classroom_nft_asset_name: Data.Bytes(),
  refund_deadline: Data.Integer(),
});

type EscrowDatum = Data.Static<typeof EscrowDatumSchema>;
const EscrowDatum = EscrowDatumSchema as unknown as EscrowDatum;

const EscrowRedeemer = Data.Enum([
  Data.Literal('Release'),
  Data.Literal('Refund'),
]);

type EscrowRedeemer = Data.Static<typeof EscrowRedeemer>;

// ========================================
// LOCK FUNDS (Student)
// ========================================

export interface LockFundsParams {
  lucid: Lucid;
  studentAddress: Address;
  teacherAddress: Address;
  amountLovelace: bigint;
  classroomNFTPolicy: PolicyId;
  classroomNFTAssetName: string;
  refundDeadlineUnix: number;
}

/**
 * Student locks ADA payment in escrow
 */
export async function lockFunds(params: LockFundsParams): Promise<string> {
  const {
    lucid,
    studentAddress,
    teacherAddress,
    amountLovelace,
    classroomNFTPolicy,
    classroomNFTAssetName,
    refundDeadlineUnix,
  } = params;

  try {
    // Get payment credential (remove "addr_test1" prefix)
    const studentCredential = lucid.utils.getAddressDetails(studentAddress)
      .paymentCredential!.hash;
    const teacherCredential = lucid.utils.getAddressDetails(teacherAddress)
      .paymentCredential!.hash;

    // Create datum
    const datum: EscrowDatum = {
      student_address: studentCredential,
      teacher_address: teacherCredential,
      locked_amount: amountLovelace,
      classroom_nft_policy: classroomNFTPolicy,
      classroom_nft_asset_name: Buffer.from(classroomNFTAssetName).toString('hex'),
      refund_deadline: BigInt(refundDeadlineUnix),
    };

    // Get script address
    const scriptAddress = getEscrowAddress(lucid);

    console.log('🔒 Locking funds in escrow...');
    console.log(`   Amount: ${Number(amountLovelace) / 1_000_000} ADA`);
    console.log(`   Script: ${scriptAddress}`);

    // Build transaction
    const tx = await lucid
      .newTx()
      .payToContract(
        scriptAddress,
        { inline: Data.to(datum, EscrowDatum) },
        { lovelace: amountLovelace }
      )
      .complete();

    // Sign and submit
    const signedTx = await tx.sign().complete();
    const txHash = await signedTx.submit();

    console.log('✅ Funds locked!');
    console.log(`   TxHash: ${txHash}`);

    return txHash;
  } catch (error: any) {
    console.error('❌ Failed to lock funds:', error);
    throw new Error(error.message || 'Failed to lock funds');
  }
}

// ========================================
// RELEASE FUNDS (Teacher)
// ========================================

export interface ReleaseFundsParams {
  lucid: Lucid;
  teacherAddress: Address;
  escrowUtxo: UTxO;
  teacherNFTUtxo: UTxO;
}

/**
 * Teacher releases funds from escrow (requires NFT ownership)
 */
export async function releaseFunds(params: ReleaseFundsParams): Promise<string> {
  const { lucid, teacherAddress, escrowUtxo, teacherNFTUtxo } = params;

  try {
    // Parse datum
    const datum = Data.from(escrowUtxo.datum!, EscrowDatum);

    // Create redeemer
    const redeemer = Data.to('Release', EscrowRedeemer);

    // Create validator
    const validator = {
      type: 'PlutusV2' as const,
      script: getEscrowValidator(),
    };

    console.log('💰 Releasing funds to teacher...');
    console.log(`   Amount: ${Number(datum.locked_amount) / 1_000_000} ADA`);

    // Build transaction
    const tx = await lucid
      .newTx()
      .collectFrom([escrowUtxo], redeemer)
      .readFrom([teacherNFTUtxo]) // Reference NFT for validation
      .attachSpendingValidator(validator)
      .payToAddress(teacherAddress, { lovelace: datum.locked_amount })
      .addSigner(teacherAddress)
      .complete();

    // Sign and submit
    const signedTx = await tx.sign().complete();
    const txHash = await signedTx.submit();

    console.log('✅ Funds released!');
    console.log(`   TxHash: ${txHash}`);

    return txHash;
  } catch (error: any) {
    console.error('❌ Failed to release funds:', error);
    throw new Error(error.message || 'Failed to release funds');
  }
}

// ========================================
// REFUND FUNDS (Student)
// ========================================

export interface RefundFundsParams {
  lucid: Lucid;
  studentAddress: Address;
  escrowUtxo: UTxO;
}

/**
 * Student refunds ADA after deadline
 */
export async function refundFunds(params: RefundFundsParams): Promise<string> {
  const { lucid, studentAddress, escrowUtxo } = params;

  try {
    // Parse datum
    const datum = Data.from(escrowUtxo.datum!, EscrowDatum);

    // Create redeemer
    const redeemer = Data.to('Refund', EscrowRedeemer);

    // Create validator
    const validator = {
      type: 'PlutusV2' as const,
      script: getEscrowValidator(),
    };

    console.log('💸 Refunding to student...');
    console.log(`   Amount: ${Number(datum.locked_amount) / 1_000_000} ADA`);

    // Build transaction with validity range after deadline
    const tx = await lucid
      .newTx()
      .collectFrom([escrowUtxo], redeemer)
      .attachSpendingValidator(validator)
      .payToAddress(studentAddress, { lovelace: datum.locked_amount })
      .validFrom(Number(datum.refund_deadline))
      .addSigner(studentAddress)
      .complete();

    // Sign and submit
    const signedTx = await tx.sign().complete();
    const txHash = await signedTx.submit();

    console.log('✅ Refunded!');
    console.log(`   TxHash: ${txHash}`);

    return txHash;
  } catch (error: any) {
    console.error('❌ Failed to refund:', error);
    throw new Error(error.message || 'Failed to refund');
  }
}

// ========================================
// QUERY FUNCTIONS
// ========================================

/**
 * Get all escrow UTXOs at script address
 */
export async function getEscrowUtxos(lucid: Lucid): Promise<UTxO[]> {
  const scriptAddress = getEscrowAddress(lucid);
  return await lucid.utxosAt(scriptAddress);
}

/**
 * Find specific escrow UTXO by student and teacher
 */
export async function findEscrowUtxo(
  lucid: Lucid,
  studentAddress: Address,
  teacherAddress: Address
): Promise<UTxO | null> {
  const utxos = await getEscrowUtxos(lucid);
  const studentHash = lucid.utils.getAddressDetails(studentAddress).paymentCredential!.hash;
  const teacherHash = lucid.utils.getAddressDetails(teacherAddress).paymentCredential!.hash;

  for (const utxo of utxos) {
    if (!utxo.datum) continue;

    try {
      const datum = Data.from(utxo.datum, EscrowDatum);
      if (datum.student_address === studentHash && datum.teacher_address === teacherHash) {
        return utxo;
      }
    } catch (e) {
      continue;
    }
  }

  return null;
}

/**
 * Get escrow details from UTXO
 */
export function getEscrowDetails(utxo: UTxO): {
  studentAddress: string;
  teacherAddress: string;
  lockedAmount: bigint;
  refundDeadline: Date;
  nftPolicy: string;
  nftAssetName: string;
} | null {
  if (!utxo.datum) return null;

  try {
    const datum = Data.from(utxo.datum, EscrowDatum);

    return {
      studentAddress: datum.student_address,
      teacherAddress: datum.teacher_address,
      lockedAmount: datum.locked_amount,
      refundDeadline: new Date(Number(datum.refund_deadline)),
      nftPolicy: datum.classroom_nft_policy,
      nftAssetName: Buffer.from(datum.classroom_nft_asset_name, 'hex').toString(),
    };
  } catch (e) {
    return null;
  }
}