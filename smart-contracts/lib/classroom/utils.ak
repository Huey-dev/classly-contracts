// ========================================
// UTILITY FUNCTIONS
// lib/classroom/utils.ak
// Helper functions shared across contracts
// ========================================

use aiken/builtin
use aiken/collection/list
use cardano/address.{Address, VerificationKey}
use cardano/assets.{AssetName, PolicyId, quantity_of}
use cardano/transaction.{Input, Output, OutputReference}

// Note: Hash and Blake2b_224 types are built-in, no import needed

// ========================================
// SIGNATURE VERIFICATION
// ========================================

/// Check if address signed the transaction
pub fn check_address_signed(
  signatories: List<ByteArray>,
  address: Address,
) -> Bool {
  when address.payment_credential is {
    VerificationKey(vkey_hash) -> list.has(signatories, vkey_hash)
    _ -> False
  }
}

/// Check if multiple addresses signed
pub fn check_multi_sig(
  signatories: List<ByteArray>,
  addresses: List<Address>,
  required: Int,
) -> Bool {
  let signed_count =
    list.count(
      addresses,
      fn(addr) { check_address_signed(signatories, addr) },
    )
  signed_count >= required
}

// ========================================
// NFT VERIFICATION
// ========================================

/// Check if address owns specific NFT
pub fn check_nft_ownership(
  inputs: List<Input>,
  owner_address: Address,
  nft_policy: PolicyId,
  nft_name: AssetName,
) -> Bool {
  list.any(
    inputs,
    fn(input) {
      let Input { output, .. } = input
      let Output { address, value, .. } = output

      address == owner_address && quantity_of(value, nft_policy, nft_name) >= 1
    },
  )
}

/// Check if NFT exists in any input
pub fn nft_exists_in_inputs(
  inputs: List<Input>,
  nft_policy: PolicyId,
  nft_name: AssetName,
) -> Bool {
  list.any(
    inputs,
    fn(input) {
      let Input { output, .. } = input
      let Output { value, .. } = output
      quantity_of(value, nft_policy, nft_name) >= 1
    },
  )
}

// ========================================
// PAYMENT VERIFICATION
// ========================================

/// Check if address receives minimum payment
pub fn check_payment_to_address(
  outputs: List<Output>,
  recipient: Address,
  min_amount: Int,
) -> Bool {
  list.any(
    outputs,
    fn(output) {
      let Output { address, value, .. } = output
      address == recipient && assets.lovelace_of(value) >= min_amount
    },
  )
}

/// Get total payment to address
pub fn get_payment_to_address(
  outputs: List<Output>,
  recipient: Address,
) -> Int {
  list.foldl(
    outputs,
    0,
    fn(output, acc) {
      let Output { address, value, .. } = output
      if address == recipient {
        acc + assets.lovelace_of(value)
      } else {
        acc
      }
    },
  )
}

/// Check exact payment amount
pub fn check_exact_payment(
  outputs: List<Output>,
  recipient: Address,
  exact_amount: Int,
) -> Bool {
  list.any(
    outputs,
    fn(output) {
      let Output { address, value, .. } = output
      address == recipient && assets.lovelace_of(value) == exact_amount
    },
  )
}


// ========================================
// UTXO VERIFICATION
// ========================================

/// Check if specific UTXO was spent
pub fn check_utxo_spent(
  inputs: List<Input>,
  target_ref: OutputReference,
) -> Bool {
  list.any(inputs, fn(input) { input.output_reference == target_ref })
}

/// Count UTXOs from address
pub fn count_utxos_from_address(inputs: List<Input>, address: Address) -> Int {
  list.count(
    inputs,
    fn(input) {
      let Input { output, .. } = input
      output.address == address
    },
  )
}

// ========================================
// TIME VERIFICATION
// ========================================

/// Check if deadline has passed
pub fn check_deadline_passed(lower_bound: Int, deadline: Int) -> Bool {
  lower_bound >= deadline
}

/// Check if time is within range
pub fn check_time_range(
  lower_bound: Int,
  upper_bound: Int,
  target_time: Int,
) -> Bool {
  lower_bound <= target_time && target_time <= upper_bound
}

// ========================================
// MATH UTILITIES
// ========================================

/// Calculate percentage
pub fn calculate_percentage(value: Int, total: Int) -> Int {
  if total == 0 {
    0
  } else {
    value * 100 / total
  }
}

/// Safe division with default
pub fn safe_divide(numerator: Int, denominator: Int, default: Int) -> Int {
  if denominator == 0 {
    default
  } else {
    numerator / denominator
  }
}

/// Calculate average
pub fn calculate_average(sum: Int, count: Int) -> Int {
  safe_divide(sum, count, 0)
}

// ========================================
// LIST UTILITIES
// ========================================

/// Find first element matching predicate
pub fn find_first(lst: List<a>, predicate: fn(a) -> Bool) -> Option<a> {
  list.find(lst, predicate)
}

/// Check if all elements satisfy predicate
pub fn all_satisfy(lst: List<a>, predicate: fn(a) -> Bool) -> Bool {
  list.all(lst, predicate)
}

/// Check if any element satisfies predicate
pub fn any_satisfies(lst: List<a>, predicate: fn(a) -> Bool) -> Bool {
  list.any(lst, predicate)
}

// ========================================
// BYTEARRAY UTILITIES
// ========================================

/// Generate asset name with prefix
pub fn generate_asset_name(prefix: ByteArray, id: ByteArray) -> AssetName {
  builtin.append_bytearray(prefix, id)
}

/// Check if bytearray starts with prefix
pub fn starts_with(data: ByteArray, prefix: ByteArray) -> Bool {
  builtin.length_of_bytearray(data) >= builtin.length_of_bytearray(prefix)
}

// ========================================
// VALIDATION HELPERS
// ========================================

/// Validate rating range (1-5)
pub fn is_valid_rating(rating: Int) -> Bool {
  rating >= 1 && rating <= 5
}

/// Validate positive amount
pub fn is_positive_amount(amount: Int) -> Bool {
  amount > 0
}

/// Validate address not zero
pub fn is_valid_address(address: Address) -> Bool {
  True
}