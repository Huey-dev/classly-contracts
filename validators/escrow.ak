use aiken/collection/list
use aiken/interval.{Finite}
use cardano/transaction.{Input, Output, OutputReference, Transaction, InlineDatum}
use cardano/address.{Address, Credential, VerificationKey}
use cardano/assets.{Value, ada_policy_id, ada_asset_name, quantity_of}

// Simplified, user-centric escrow with platform fee removal off-chain.
// Net amounts (after 25% platform fee) are recorded and split 30/40/30 with gates.

pub type EscrowDatum {
  receiver: ByteArray,      // course owner / seller pkh
  oracle: ByteArray,        // off-chain authority pkh
  net_total: Int,           // cumulative net funds (post-fee) locked
  paid_count: Int,          // number of payers who funded
  paid_out: Int,            // total already paid to receiver
  released30: Bool,         // initial 30% batch paid (first 5 students)
  released40: Bool,         // metrics batch paid
  releasedFinal: Bool,      // final 30% paid
  comments: Int,            // aggregated comments count
  rating_sum: Int,          // sum of ratings *10 (to avoid floats)
  rating_count: Int,        // number of ratings
  all_watch_met: Bool,      // true when all students have >=60% watch
  first_watch: Int,         // timestamp of first watch event (posix milliseconds)
  dispute_by: Int,          // deadline for dispute / final release (posix milliseconds)
}

pub type Redeemer {
  AddPayment { 
    net_amount: Int, 
    watch_met: Bool, 
    rating_x10: Int, 
    commented: Bool, 
    first_watch_at: Int 
  }
  ReleaseInitial
  ReleaseMetrics40
  ReleaseFinal
  Refund
  DisputeHold
}

fn expect_signature(pkh: ByteArray, extra_sigs: List<ByteArray>) -> Bool {
  list.has(extra_sigs, pkh)
}

fn lovelace_of(val: Value) -> Int {
  quantity_of(val, ada_policy_id, ada_asset_name)
}

fn find_continuing(outputs: List<Output>, script_addr: Address) -> Option<Output> {
  list.find(outputs, fn(o) { o.address == script_addr })
}

fn avg_rating_ok(sum: Int, count: Int, threshold_x10: Int) -> Bool {
  if count == 0 {
    False
  } else {
    sum * 1_000 >= threshold_x10 * count * 100
  }
}

fn has_output_to_pkh(outputs: List<Output>, pkh: ByteArray, min_amount: Int) -> Bool {
  list.any(
    outputs,
    fn(o) {
      when o.address.payment_credential is {
        VerificationKey(pk) -> pk == pkh && lovelace_of(o.value) >= min_amount
        _ -> False
      }
    },
  )
}

fn parse_output_datum(out: Output) -> Option<EscrowDatum> {
  when out.datum is {
    InlineDatum(data) -> {
      expect datum: EscrowDatum = data
      Some(datum)
    }
    _ -> None
  }
}

validator escrow {
  spend(
    datum_opt: Option<EscrowDatum>,
    redeemer: Redeemer,
    own_ref: OutputReference,
    tx: Transaction,
  ) -> Bool {
    expect Some(datum) = datum_opt
    
    // Get script address from input being spent
    expect Some(own_input) = 
      list.find(tx.inputs, fn(i) { i.output_reference == own_ref })
    let script_addr = own_input.output.address
    
    when redeemer is {
      AddPayment { net_amount, watch_met, rating_x10, commented, first_watch_at } -> {
        let new_count = datum.paid_count + 1
        let immediate_payout =
          if new_count > 5 {
            net_amount * 30 / 100
          } else {
            0
          }

        let ok_payout =
          if immediate_payout > 0 {
            has_output_to_pkh(tx.outputs, datum.receiver, immediate_payout)
          } else {
            True
          }

        expect Some(continuing_out) = find_continuing(tx.outputs, script_addr)
        expect Some(next) = parse_output_datum(continuing_out)

        ok_payout && (
          next.receiver == datum.receiver &&
          next.oracle == datum.oracle &&
          next.net_total == datum.net_total + net_amount - immediate_payout &&
          next.paid_count == new_count &&
          next.paid_out == datum.paid_out + immediate_payout &&
          next.released30 == datum.released30 &&
          next.released40 == datum.released40 &&
          next.releasedFinal == datum.releasedFinal &&
          next.comments == datum.comments + if commented { 1 } else { 0 } &&
          next.rating_sum == datum.rating_sum + rating_x10 &&
          next.rating_count == datum.rating_count + if rating_x10 > 0 { 1 } else { 0 } &&
          next.all_watch_met == if datum.paid_count == 0 {
            watch_met
          } else {
            datum.all_watch_met && watch_met
          } &&
          next.first_watch == if datum.first_watch == 0 {
            first_watch_at
          } else {
            datum.first_watch
          } &&
          next.dispute_by == datum.dispute_by
        )
      }

      ReleaseInitial -> {
        let payout_amount = datum.net_total * 30 / 100

        expect Some(continuing_out) = find_continuing(tx.outputs, script_addr)
        expect Some(next) = parse_output_datum(continuing_out)

        expect_signature(datum.receiver, tx.extra_signatories) &&
        datum.paid_count >= 5 &&
        !datum.released30 &&
        has_output_to_pkh(tx.outputs, datum.receiver, payout_amount) &&
        next.released30 == True &&
        next.paid_out == datum.paid_out + payout_amount &&
        next.net_total == datum.net_total - payout_amount &&
        next.receiver == datum.receiver &&
        next.oracle == datum.oracle
      }

      ReleaseMetrics40 -> {
        let payout_amount = datum.net_total * 40 / 100

        expect Some(continuing_out) = find_continuing(tx.outputs, script_addr)
        expect Some(next) = parse_output_datum(continuing_out)

        expect_signature(datum.receiver, tx.extra_signatories) &&
        datum.released30 &&
        !datum.released40 &&
        datum.all_watch_met &&
        datum.comments >= 3 &&
        avg_rating_ok(datum.rating_sum, datum.rating_count, 35) &&
        has_output_to_pkh(tx.outputs, datum.receiver, payout_amount) &&
        next.released40 == True &&
        next.paid_out == datum.paid_out + payout_amount &&
        next.net_total == datum.net_total - payout_amount &&
        next.receiver == datum.receiver &&
        next.oracle == datum.oracle
      }

      ReleaseFinal -> {
        let ten_days_ms = 10 * 24 * 3600 * 1000
        let ten_days_after_first = datum.first_watch + ten_days_ms

        // Valid if EITHER condition is true:
        // 1. Current time is after dispute deadline
        // 2. Current time is 10 days after first watch
        let lower_bound = tx.validity_range.lower_bound.bound_type
        expect Finite(lb) = lower_bound
        let time_ok = lb >= datum.dispute_by || lb >= ten_days_after_first

        expect_signature(datum.receiver, tx.extra_signatories) &&
        datum.released40 &&
        !datum.releasedFinal &&
        time_ok &&
        has_output_to_pkh(tx.outputs, datum.receiver, datum.net_total)
      }

      Refund -> {
        let metrics_unmet =
          !datum.all_watch_met ||
          datum.comments < 3 ||
          !avg_rating_ok(datum.rating_sum, datum.rating_count, 35)

        let upper_bound = tx.validity_range.upper_bound.bound_type
        expect Finite(ub) = upper_bound
        let within_dispute = ub <= datum.dispute_by

        ( within_dispute || metrics_unmet ) &&
        expect_signature(datum.oracle, tx.extra_signatories)
      }

      DisputeHold -> {
        expect Some(continuing_out) = find_continuing(tx.outputs, script_addr)
        expect Some(next) = parse_output_datum(continuing_out)

        expect_signature(datum.oracle, tx.extra_signatories) &&
        next.receiver == datum.receiver &&
        next.oracle == datum.oracle &&
        !next.releasedFinal
      }
    }
  }
}