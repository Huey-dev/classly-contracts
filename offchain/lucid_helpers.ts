// Off-chain helpers (stubs) for the new 30/40/30 milestone escrow.
// Replace with real Lucid code in the application layer.

export type EscrowDatum = {
  escrowId: string;
  senderAddress: string;
  receiverAddress: string;
  totalLocked: bigint; // after platform fee
  phase1Amount: bigint;
  phase2Amount: bigint;
  phase3Amount: bigint;
  phase1Released: boolean;
  phase2Released: boolean;
  phase3Released: boolean;
  milestoneReached: boolean;
  disputeWindowStart?: bigint | null; // ms
  resourceId: string; // hex or utf-8 encoded
  oraclePubKey: string; // hex
  createdAt: bigint; // ms
};

export type MilestoneProof = {
  senderAddress: string;
  resourceId: string;
  completionPercentage: number; // must be >=50
  timestamp: bigint; // ms
  nonce: string; // hex
  signature: string; // hex
};

export type TimeProof = {
  escrowId: string;
  currentTime: bigint;
  disputeWindowStart: bigint;
  nonce: string;
  signature: string;
};

export type CompletionProof = {
  senderAddress: string;
  resourceId: string;
  completionPercentage: number; // must be 100
  timestamp: bigint;
  nonce: string;
  signature: string;
};

export type EscrowDeployment = {
  scriptCbor: string;
  address: string;
  oraclePubKey: string;
};

export function buildLockFundsTx() {
  // TODO: build initial lock that pays 30% to receiver and re-locks remainder with inline datum.
}

export function buildRelease40Tx(_proof: MilestoneProof) {
  // TODO: collect escrow UTXO, attach oracle-signed milestone proof, pay 40% to receiver, re-lock remainder.
}

export function buildRelease30FinalTx(_proof: TimeProof) {
  // TODO: enforce 14d window from disputeWindowStart, pay final 30%, close contract.
}

export function buildRefundTx() {
  // TODO: allow sender refund (70% before milestone, 30% within window after milestone). Sender signs.
}

export function buildCompletionNftMintTx(_proof: CompletionProof) {
  // TODO: mint single NFT under completion policy with oracle signature, send to senderAddress.
}
