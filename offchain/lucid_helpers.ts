// Off-chain stubs for building transactions against classly_escrow_30_40_30_v3
// Fill in with real Lucid logic in the app layer.

export type EscrowDeployment = {
  scriptCbor: string;
  address: string;
  oraclePubKeyHash: string;
};

export function buildLockTx() {
  // TODO: construct lock tx removing 25% platform fee off-chain, supply net_amount in datum.
}

export function buildAddPaymentTx() {
  // TODO: spend state UTXO, pay receiver 30% if >5th payer, re-lock remainder with updated datum.
}

export function buildReleaseInitialTx() {
  // TODO: teacher signs; release initial 30% when paid_count >=5.
}

export function buildReleaseMetrics40Tx() {
  // TODO: teacher signs; release 40% when metrics met.
}

export function buildReleaseFinalTx() {
  // TODO: teacher signs; release final 30% after dispute window or inactivity.
}

export function buildRefundTx() {
  // TODO: oracle signs; refund path when metrics/dispute conditions fail.
}

