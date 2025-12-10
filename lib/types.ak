use cardano/address.{Address}

// Core types for the escrow system and completion NFT policy.

pub type EscrowDatum {
  escrow_id: ByteArray,              // unique identifier for this escrow instance
  sender: Address,                   // student / buyer
  receiver: Address,                 // tutor / seller
  total_locked: Int,                 // total lovelace locked after platform fee
  phase1_amount: Int,                // 30%
  phase2_amount: Int,                // 40%
  phase3_amount: Int,                // 30%
  phase1_released: Bool,             // phase1 paid
  phase2_released: Bool,             // phase2 paid
  phase3_released: Bool,             // phase3 paid
  milestone_reached: Bool,           // milestone (>=50%) verified
  dispute_window_start: Option<Int>, // posix ms when phase2 paid (start of 14d window)
  resource_id: ByteArray,            // course / product id
  oracle_pubkey: ByteArray,          // oracle public key for proofs
  created_at: Int,                   // lock timestamp (posix ms)
}

pub type MilestoneProof {
  sender_address: Address,
  resource_id: ByteArray,
  completion_percentage: Int,
  timestamp: Int,
  nonce: ByteArray,
  signature: ByteArray,
}

pub type TimeProof {
  escrow_id: ByteArray,
  current_time: Int,
  dispute_window_start: Int,
  nonce: ByteArray,
  signature: ByteArray,
}

pub type CompletionProof {
  sender_address: Address,
  resource_id: ByteArray,
  completion_percentage: Int,
  timestamp: Int,
  nonce: ByteArray,
  signature: ByteArray,
}

pub type EscrowRedeemer {
  LockFunds
  Release40 { proof: MilestoneProof }
  Release30Final { proof: TimeProof }
  Refund { sender_signature: ByteArray }
}

pub type CompletionRedeemer {
  MintCompletion { proof: CompletionProof, oracle_pubkey: ByteArray }
}

pub const fourteen_days_ms: Int = 1_209_600_000
pub const one_hour_ms: Int = 3_600_000
