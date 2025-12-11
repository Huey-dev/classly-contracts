// types.ak - CORRECTED
use cardano/address.{Address}

pub type EscrowDatum {
  receiver: ByteArray,           // Receiver PKH (course creator)
  oracle: ByteArray,             // Oracle PKH for proofs
  net_total: Int,                // Cumulative locked funds (after platform fee)
  paid_count: Int,               // Number of senders who paid
  paid_out: Int,                 // Total already released
  released30: Bool,              // First 30% batch released (sender 5)
  released40: Bool,              // Metrics 40% released
  releasedFinal: Bool,           // Final 30% released
  comments: Int,                 // Aggregated comments
  rating_sum: Int,               // Sum of ratings × 10
  rating_count: Int,             // Number of ratings
  all_watch_met: Bool,           // All senders watched ≥60%
  first_watch: Int,              // Timestamp of first watch (POSIX ms)
  dispute_by: Int,               // Dispute deadline (POSIX ms)
}

pub type EscrowRedeemer {
  AddPayment {
    net_amount: Int,
    watch_met: Bool,
    rating_x10: Int,
    commented: Bool,
    first_watch_at: Int,
  }
  ReleaseInitial                 // DEPRECATED (now automatic)
  ReleaseMetrics40
  ReleaseFinal
  Refund
  DisputeHold
}

// For NFT minting - this can stay per-sender
pub type CompletionProof {
  sender_address: Address,
  resource_id: ByteArray,
  completion_percentage: Int,    // Must be 100
  timestamp: Int,
  nonce: ByteArray,
  signature: ByteArray,
}

pub type CompletionRedeemer {
  MintCompletion { 
    proof: CompletionProof, 
    oracle_pubkey: ByteArray 
  }
}

pub const fourteen_days_ms: Int = 1_209_600_000
pub const ten_days_ms: Int = 864_000_000