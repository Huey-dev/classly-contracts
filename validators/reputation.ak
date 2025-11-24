// ========================================
// REPUTATION ANCHOR CONTRACT
// validators/reputation.ak
// Stores immutable teacher ratings on-chain
// ========================================

use aiken/collection/list
use cardano/transaction.{InlineDatum, OutputReference, Transaction}
use cardano/address.{Address, VerificationKey}
use cardano/assets

// ========================================
// TYPES
// ========================================

/// Datum storing reputation state
pub type ReputationDatum {
  teacher_address: Address,
  total_rating_sum: Int,
  total_ratings_count: Int,
  last_updated: Int,
  version: Int,
}

/// Redeemer actions
pub type ReputationRedeemer {
  Anchor { new_rating: Int, rater_address: Address }
  Initialize
}

// ========================================
// MAIN VALIDATOR
// ========================================

validator reputation_validator {
  spend(
    datum_opt: Option<ReputationDatum>,
    redeemer: ReputationRedeemer,
    _own_ref: OutputReference,
    ctx: Transaction,
  ) {
    expect Some(datum) = datum_opt

    when redeemer is {
      Anchor { new_rating, rater_address } ->
        handle_anchor(datum, new_rating, rater_address, ctx)
      Initialize -> handle_initialize(datum, ctx)
    }
  }

  else(_) {
    fail
  }
}

// ========================================
// ANCHOR HANDLER (Add Rating)
// ========================================

fn handle_anchor(
  old_datum: ReputationDatum,
  new_rating: Int,
  rater_address: Address,
  transaction: Transaction,
) -> Bool {
  let valid_rating = new_rating >= 1 && new_rating <= 5

  let continuing_output =
    list.find(
      transaction.outputs,
      fn(output) {
        when output.datum is {
          InlineDatum(_) -> True
          _ -> False
        }
      },
    )

  when continuing_output is {
    Some(output) -> {
      expect InlineDatum(new_datum_data) = output.datum
      expect new_datum: ReputationDatum = new_datum_data

      let correct_update =
        new_datum.total_rating_sum == old_datum.total_rating_sum + new_rating && new_datum.total_ratings_count == old_datum.total_ratings_count + 1 && new_datum.version == old_datum.version + 1 && new_datum.teacher_address == old_datum.teacher_address

      let timestamp_valid = new_datum.last_updated > old_datum.last_updated

      let rater_signed =
        when rater_address.payment_credential is {
          VerificationKey(vkey_hash) ->
            list.has(transaction.extra_signatories, vkey_hash)
          _ -> False
        }

      let ada_preserved = 
        assets.lovelace_of(output.value) >= 2_000_000

      valid_rating && correct_update && timestamp_valid && rater_signed && ada_preserved
    }
    None -> False
  }
}

// ========================================
// INITIALIZE HANDLER
// ========================================

fn handle_initialize(datum: ReputationDatum, transaction: Transaction) -> Bool {
  let is_initial =
    datum.total_rating_sum == 0 && datum.total_ratings_count == 0 && datum.version == 0

  let teacher_signed =
    when datum.teacher_address.payment_credential is {
      VerificationKey(vkey_hash) ->
        list.has(transaction.extra_signatories, vkey_hash)
      _ -> False
    }

  is_initial && teacher_signed
}

// ========================================
// UTILITY FUNCTIONS (Off-chain)
// ========================================

pub fn calculate_average(datum: ReputationDatum) -> Int {
  if datum.total_ratings_count == 0 {
    0
  } else {
    datum.total_rating_sum / datum.total_ratings_count
  }
}

pub fn rating_percentage(datum: ReputationDatum) -> Int {
  let avg = calculate_average(datum)
  avg * 100 / 5
}