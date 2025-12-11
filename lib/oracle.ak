// oracle.ak - CORRECTED
use aiken/builtin.{append_bytearray, serialise_data}
use cardano/address.{Address}

fn concat_bytes(chunks: List<ByteArray>) -> ByteArray {
  when chunks is {
    [] -> #[]
    [x, ..xs] -> append_bytearray(x, concat_bytes(xs))
  }
}

fn int_bytes(i: Int) -> ByteArray {
  serialise_data(i)
}

fn address_bytes(addr: Address) -> ByteArray {
  serialise_data(addr)
}

// For AddPayment: Not needed (no oracle proof required)

// For ReleaseMetrics40: Not needed in cohort model
// Watch time is tracked in datum.all_watch_met (updated per AddPayment)

// For ReleaseFinal: Not needed in cohort model
// Time check is done in validator using datum.first_watch + 10 days

// For NFT minting: Oracle signs completion proof
pub fn build_completion_message(
  sender_address: Address,
  resource_id: ByteArray,
  timestamp: Int,
  nonce: ByteArray,
) -> ByteArray {
  concat_bytes([
    address_bytes(sender_address),
    resource_id,
    int_bytes(100),           // Always 100% for NFT
    int_bytes(timestamp),
    nonce,
  ])
}

// For Refund: Oracle signs refund authorization
pub fn build_refund_message(
  escrow_datum_hash: ByteArray,  // Hash of the escrow datum for this course
  sender_address: Address,       // Which sender is requesting refund
  nonce: ByteArray,
) -> ByteArray {
  concat_bytes([
    escrow_datum_hash,
    address_bytes(sender_address),
    nonce,
  ])
}