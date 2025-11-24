// ========================================
// CLASSROOM NFT MINTING CONTRACT
// validators/classroom_nft.ak
// Mints unique NFTs for classroom ownership
// ========================================

use aiken/builtin
use aiken/collection/list
use aiken/collection/dict
use cardano/transaction.{Input, Output, OutputReference, Transaction}
use cardano/address.{Address, VerificationKey}
use cardano/assets.{AssetName, PolicyId, quantity_of, tokens}

// ========================================
// TYPES
// ========================================

/// Redeemer for minting/burning actions
pub type NFTRedeemer {
  Mint {
    teacher_address: Address,
    classroom_id: ByteArray,
    utxo_ref: OutputReference,
  }
  Burn
}

// ========================================
// MAIN MINTING POLICY
// ========================================

validator classroom_nft_policy {
  mint(redeemer: NFTRedeemer, policy_id: PolicyId, self: Transaction) {
    when redeemer is {
      Mint { teacher_address, classroom_id, utxo_ref } ->
        handle_mint(self, policy_id, teacher_address, classroom_id, utxo_ref)
      Burn -> handle_burn(self, policy_id)
    }
  }

  else(_) {
    fail
  }
}

// ========================================
// MINT HANDLER
// ========================================

fn handle_mint(
  transaction: Transaction,
  policy_id: PolicyId,
  teacher_address: Address,
  classroom_id: ByteArray,
  utxo_ref: OutputReference,
) -> Bool {
  let nft_name = generate_nft_name(classroom_id)
  let minted_value = transaction.mint

  let correct_amount_minted = quantity_of(minted_value, policy_id, nft_name) == 1

  let utxo_consumed = check_utxo_spent(transaction.inputs, utxo_ref)

  let nft_sent_to_teacher =
    check_nft_in_outputs(
      transaction.outputs,
      teacher_address,
      policy_id,
      nft_name,
    )

  let teacher_signed =
    check_address_signed(transaction.extra_signatories, teacher_address)

  correct_amount_minted && utxo_consumed && nft_sent_to_teacher && teacher_signed
}

// ========================================
// BURN HANDLER
// ========================================

fn handle_burn(transaction: Transaction, policy_id: PolicyId) -> Bool {
  let minted_value = transaction.mint
  let burned_dict = tokens(minted_value, policy_id)
  let burned_keys = dict.keys(burned_dict)

  let all_burned =
    list.all(
      burned_keys,
      fn(asset_name) {
        when dict.get(burned_dict, asset_name) is {
          Some(quantity) -> quantity == -1
          None -> False
        }
      },
    )

  let nft_in_inputs = check_policy_in_inputs(transaction.inputs, policy_id)

  all_burned && nft_in_inputs
}

// ========================================
// HELPER FUNCTIONS
// ========================================

fn generate_nft_name(classroom_id: ByteArray) -> AssetName {
  let prefix = "CLASSROOM_"
  builtin.append_bytearray(prefix, classroom_id)
}

fn check_utxo_spent(inputs: List<Input>, target_ref: OutputReference) -> Bool {
  list.any(inputs, fn(input) { input.output_reference == target_ref })
}

fn check_nft_in_outputs(
  outputs: List<Output>,
  recipient: Address,
  policy_id: PolicyId,
  nft_name: AssetName,
) -> Bool {
  list.any(
    outputs,
    fn(output) {
      let Output { address, value, .. } = output
      address == recipient && quantity_of(value, policy_id, nft_name) >= 1
    },
  )
}

fn check_policy_in_inputs(inputs: List<Input>, policy_id: PolicyId) -> Bool {
  list.any(
    inputs,
    fn(input) {
      let Input { output, .. } = input
      let Output { value, .. } = output
      let assets = tokens(value, policy_id)
      !dict.is_empty(assets)
    },
  )
}

fn check_address_signed(
  signatories: List<ByteArray>,
  address: Address,
) -> Bool {
  when address.payment_credential is {
    VerificationKey(vkey_hash) -> list.has(signatories, vkey_hash)
    _ -> False
  }
}