use aiken/builtin.{append_bytearray, serialise_data}
use cardano/address.{Address}

// Oracle and proof helpers.

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

pub fn build_milestone_message(
  sender_address: Address,
  resource_id: ByteArray,
  completion_percentage: Int,
  timestamp: Int,
  nonce: ByteArray,
) -> ByteArray {
  concat_bytes(
    [
      address_bytes(sender_address),
      resource_id,
      int_bytes(completion_percentage),
      int_bytes(timestamp),
      nonce,
    ],
  )
}

pub fn build_time_message(
  escrow_id: ByteArray,
  current_time: Int,
  dispute_window_start: Int,
  nonce: ByteArray,
) -> ByteArray {
  concat_bytes(
    [escrow_id, int_bytes(current_time), int_bytes(dispute_window_start), nonce],
  )
}

pub fn build_completion_message(
  sender_address: Address,
  resource_id: ByteArray,
  timestamp: Int,
  nonce: ByteArray,
) -> ByteArray {
  concat_bytes(
    [
      address_bytes(sender_address),
      resource_id,
      int_bytes(100),
      int_bytes(timestamp),
      nonce,
    ],
  )
}

pub fn build_refund_message(escrow_id: ByteArray, nonce: ByteArray) -> ByteArray {
  concat_bytes([escrow_id, nonce])
}
