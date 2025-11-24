// ========================================
// CLASSROOM ESCROW CONTRACT
// validators/escrow.ak
// Handles secure payment locking and release
// ========================================

use aiken/collection/list
use aiken/interval.{Finite, IntervalBound}
use cardano/transaction.{Input, Output, OutputReference, Transaction, ValidityRange}
use cardano/address.{Address, VerificationKey}
use cardano/assets.{AssetName, PolicyId, lovelace_of, quantity_of}

// ========================================
// TYPES
// ========================================

/// Datum stored with locked funds
pub type EscrowDatum {
  student_address: Address,
  teacher_address: Address,
  locked_amount: Int,
  classroom_nft_policy: PolicyId,
  classroom_nft_asset_name: AssetName,
  refund_deadline: Int,
}

/// Redeemer actions
pub type EscrowRedeemer {
  Release
  Refund
}

// ========================================
// MAIN VALIDATOR
// ========================================

validator escrow_validator {
  spend(
    datum_opt: Option<EscrowDatum>,
    redeemer: EscrowRedeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(datum) = datum_opt

    when redeemer is {
      Release -> handle_release(datum, self)
      Refund -> handle_refund(datum, self)
    }
  }

  else(_) {
    fail
  }
}

// ========================================
// RELEASE HANDLER
// ========================================

fn handle_release(datum: EscrowDatum, transaction: Transaction) -> Bool {
  let teacher_has_nft =
    check_nft_ownership(
      transaction.inputs,
      datum.teacher_address,
      datum.classroom_nft_policy,
      datum.classroom_nft_asset_name,
    )

  let teacher_receives_payment =
    check_payment_to_address(
      transaction.outputs,
      datum.teacher_address,
      datum.locked_amount,
    )

  let teacher_signed =
    check_address_signed(transaction.extra_signatories, datum.teacher_address)

  teacher_has_nft && teacher_receives_payment && teacher_signed
}

// ========================================
// REFUND HANDLER
// ========================================

fn handle_refund(datum: EscrowDatum, transaction: Transaction) -> Bool {
  let deadline_passed =
    check_deadline_passed(transaction.validity_range, datum.refund_deadline)

  let student_receives_refund =
    check_payment_to_address(
      transaction.outputs,
      datum.student_address,
      datum.locked_amount,
    )

  let student_signed =
    check_address_signed(transaction.extra_signatories, datum.student_address)

  deadline_passed && student_receives_refund && student_signed
}

// ========================================
// HELPER FUNCTIONS
// ========================================

fn check_nft_ownership(
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

fn check_payment_to_address(
  outputs: List<Output>,
  recipient: Address,
  min_amount: Int,
) -> Bool {
  list.any(
    outputs,
    fn(output) {
      let Output { address, value, .. } = output
      address == recipient && lovelace_of(value) >= min_amount
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

fn check_deadline_passed(validity_range: ValidityRange, deadline: Int) -> Bool {
  when validity_range.lower_bound is {
    IntervalBound { bound_type: Finite(lower_time), .. } -> lower_time >= deadline
    _ -> False
  }
}