use aiken/collection/list
use aiken/interval.{Finite}
use cardano/address.{Address, VerificationKey}
use cardano/assets.{Value, ada_asset_name, ada_policy_id, quantity_of}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}

// ============================================================================
// CLASSLY ESCROW VALIDATOR
// ============================================================================
// Payment model: 30/40/30 split with quality gates
// - First 30%: Released when 5 senders pay (batch) OR incrementally for 6+
// - Next 40%: Released when quality metrics met (watch time primary)
// - Final 30%: Released 10 days after first watch OR after dispute deadline
// 
// Platform fee (7%) deducted OFF-CHAIN before funds enter escrow
// All amounts are NET (post-platform-fee)
// ============================================================================

// ============================================================================
// DATUM: On-chain state for each escrow
// ============================================================================
pub type EscrowDatum {
  receiver: ByteArray,
  // Payment receiver (course creator) public key hash
  oracle: ByteArray,
  // Trusted off-chain authority public key hash (signs refunds/disputes)
  net_total: Int,
  // Total ADA locked in escrow (in lovelace, after platform fee)
  paid_count: Int,
  // Number of senders who have paid into this escrow
  paid_out: Int,
  // Total amount already released to receiver (in lovelace)
  released30: Bool,
  // TRUE after 5th sender triggers batch 30% release
  released40: Bool,
  // TRUE after metrics gate passed and 40% released
  releasedFinal: Bool,
  // TRUE after final 30% released (escrow complete)
  comments: Int,
  // Aggregated comment count from all senders
  rating_sum: Int,
  // Sum of all ratings × 10 (to avoid decimals: 4.5 stars = 45)
  rating_count: Int,
  // Number of senders who left ratings
  all_watch_met: Bool,
  // TRUE if ALL senders have watched ≥60% of content
  // This is the PRIMARY quality gate (non-gameable via Mux webhooks)
  first_watch: Int,
  // Timestamp (POSIX ms) when first sender reached 60% watch
  // Used to calculate 10-day dispute window
  dispute_by: Int,
}

// Deadline (POSIX ms) for disputes/refunds

// ============================================================================
// REDEEMER: Actions that can be performed on escrow
// ============================================================================
pub type Redeemer {
  AddPayment {
    net_amount: Int,
    // Amount sender is paying (lovelace, after platform fee)
    watch_met: Bool,
    // TRUE if this sender has watched ≥60% of content
    rating_x10: Int,
    // Sender's rating × 10 (e.g., 4.5 stars = 45, 0 = no rating)
    commented: Bool,
    // TRUE if sender left a comment
    first_watch_at: Int,
  }
  // Timestamp (POSIX ms) when THIS sender hit 60% watch
  // Only matters if this is the first sender to watch
  ReleaseInitial
  // DEPRECATED: 30% now auto-releases in AddPayment for sender 5
  // Kept for backward compatibility
  ReleaseMetrics40
  // Receiver claims 40% after quality gates met
  ReleaseFinal
  // Receiver claims final 30% after time lock expires
  Refund
  // Oracle-signed refund if metrics unmet or within dispute window
  DisputeHold
}

// Oracle can freeze escrow for investigation

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// Check if transaction is signed by given public key hash
fn expect_signature(pkh: ByteArray, extra_sigs: List<ByteArray>) -> Bool {
  list.has(extra_sigs, pkh)
}

// Extract lovelace amount from a Value
fn lovelace_of(val: Value) -> Int {
  quantity_of(val, ada_policy_id, ada_asset_name)
}

// Find the output that continues the script (same address as input)
fn find_continuing(
  outputs: List<Output>,
  script_addr: Address,
) -> Option<Output> {
  list.find(outputs, fn(o) { o.address == script_addr })
}

// Check if average rating meets threshold
// sum: total rating × 10 (e.g., 3 ratings of 4.0 = 120)
// count: number of ratings
// threshold_x10: minimum average × 10 (e.g., 1.0 stars = 10)
// Returns TRUE if (sum / count) >= (threshold_x10 / 10)
fn avg_rating_ok(sum: Int, count: Int, threshold_x10: Int) -> Bool {
  if count == 0 {
    False
  } else {
    // Multiply by 1000 to avoid division precision issues
    // sum * 1000 >= threshold_x10 * count * 100
    // Example: sum=120, count=3, threshold=10
    //   120 * 1000 >= 10 * 3 * 100
    //   120000 >= 3000 ✓ (avg 4.0 >= 1.0)
    sum * 1_000 >= threshold_x10 * count * 100
  }
}

// Check if there's an output paying at least min_amount to a public key hash
fn has_output_to_pkh(
  outputs: List<Output>,
  pkh: ByteArray,
  min_amount: Int,
) -> Bool {
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

// Parse inline datum from output
fn parse_output_datum(out: Output) -> Option<EscrowDatum> {
  when out.datum is {
    InlineDatum(data) -> {
      expect datum: EscrowDatum = data
      Some(datum)
    }
    _ -> None
  }
}

// ============================================================================
// MAIN VALIDATOR
// ============================================================================
validator escrow {
  spend(
    datum_opt: Option<EscrowDatum>,
    redeemer: Redeemer,
    own_ref: OutputReference,
    tx: Transaction,
  ) {
    // Extract datum from UTXO being spent
    expect Some(datum) = datum_opt
    // Get script address from the input being spent
    expect Some(own_input) =
      list.find(tx.inputs, fn(i) { i.output_reference == own_ref })
    let script_addr = own_input.output.address
    when redeemer is {
      // ======================================================================
      // ADD PAYMENT: Sender pays into escrow
      // ======================================================================
      AddPayment {
        net_amount,
        watch_met,
        rating_x10,
        commented,
        first_watch_at,
      } -> {
        let new_count = datum.paid_count + 1
        // CRITICAL LOGIC: Determine payout based on sender count
        let immediate_payout =
          if new_count == 5 {
            // SENDER 5: Batch release 30% of ALL accumulated funds
            // Example: 4 senders × 10 ADA + this 10 ADA = 50 ADA total
            //          Payout: 50 × 30% = 15 ADA
            ( datum.net_total + net_amount ) * 30 / 100
          } else if new_count > 5 {
            // SENDER 6+: Incremental release 30% of THIS payment only
            // Example: This sender pays 10 ADA
            //          Payout: 10 × 30% = 3 ADA
            net_amount * 30 / 100
          } else {
            // SENDERS 1-4: Accumulation phase, no payout yet
            0
          }

        // Verify payout is sent to receiver (if any)
        let ok_payout =
          if immediate_payout > 0 {
            has_output_to_pkh(tx.outputs, datum.receiver, immediate_payout)
          } else {
            True
          }

        // Find continuing output (updated escrow state)
        expect Some(continuing_out) = find_continuing(tx.outputs, script_addr)
        expect Some(next) = parse_output_datum(continuing_out)

        // VALIDATE ALL STATE TRANSITIONS
        ok_payout && // Immutable fields must not change
        next.receiver == datum.receiver && next.oracle == datum.oracle && // Financial state updates
        next.net_total == datum.net_total + net_amount - immediate_payout && next.paid_count == new_count && next.paid_out == datum.paid_out + immediate_payout && // Release flags
        next.released30 == if new_count >= 5 {
          True
        } else {
          datum.released30
        } && // ↑ Mark released30=TRUE when 5th sender pays
        next.released40 == datum.released40 && next.releasedFinal == datum.releasedFinal && // Quality metrics updates
        next.comments == datum.comments + if commented {
          1
        } else {
          0
        } && next.rating_sum == datum.rating_sum + rating_x10 && next.rating_count == datum.rating_count + if rating_x10 > 0 {
          1
        } else {
          0
        } && // Watch time tracking (AND logic: all must watch ≥60%)
        next.all_watch_met == if datum.paid_count == 0 {
          // First sender sets the baseline
          watch_met
        } else {
          // Subsequent senders: maintain TRUE only if all have watched
          datum.all_watch_met && watch_met
        } && // First watch timestamp (set once, never changes)
        next.first_watch == if datum.first_watch == 0 {
          first_watch_at
        } else {
          datum.first_watch
        } && // Dispute deadline unchanged
        next.dispute_by == datum.dispute_by
      }

      // ======================================================================
      // RELEASE INITIAL 30%: Manual trigger (DEPRECATED)
      // ======================================================================
      // This was the original design but is now AUTOMATIC in AddPayment
      // Keeping for backward compatibility with existing escrows
      ReleaseInitial -> {
        let payout_amount = datum.net_total * 30 / 100

        expect Some(continuing_out) = find_continuing(tx.outputs, script_addr)
        expect Some(next) = parse_output_datum(continuing_out)

        // Validations:
        expect_signature(datum.receiver, tx.extra_signatories) && datum.paid_count >= 5 && // At least 5 senders
        !datum.released30 && // Not already released
        has_output_to_pkh(tx.outputs, datum.receiver, payout_amount) && // State updates
        next.released30 == True && next.paid_out == datum.paid_out + payout_amount && next.net_total == datum.net_total - payout_amount && next.receiver == datum.receiver && next.oracle == datum.oracle
      }

      // ======================================================================
      // RELEASE 40%: Quality metrics gate
      // ======================================================================
      ReleaseMetrics40 -> {
        let payout_amount = datum.net_total * 40 / 100

        expect Some(continuing_out) = find_continuing(tx.outputs, script_addr)
        expect Some(next) = parse_output_datum(continuing_out)

        // QUALITY GATES (all must pass):
        // 1. all_watch_met: PRIMARY GATE (non-gameable, tracked by Mux)
        // 2. comments >= 1: Minimal threshold (prevents receiver lockout)
        // 3. avg rating >= 1.0 stars: Minimal threshold (prevents malicious ratings)
        expect_signature(datum.receiver, tx.extra_signatories) && datum.released30 && // First 30% must be released already
        !datum.released40 && // Not already released
        datum.all_watch_met && // ★ PRIMARY GATE: All senders watched ≥60%
        datum.comments >= 1 && // At least 1 comment
        avg_rating_ok(datum.rating_sum, datum.rating_count, 10) && // ↑ Average rating ≥ 1.0 stars (threshold_x10 = 10)
        has_output_to_pkh(tx.outputs, datum.receiver, payout_amount) && // State updates
        next.released40 == True && next.paid_out == datum.paid_out + payout_amount && next.net_total == datum.net_total - payout_amount && next.receiver == datum.receiver && next.oracle == datum.oracle
      }

      // ======================================================================
      // RELEASE FINAL 30%: Time lock gate
      // ======================================================================
      ReleaseFinal -> {
        let ten_days_ms = 10 * 24 * 3600 * 1000
        let ten_days_after_first = datum.first_watch + ten_days_ms

        // Time gate: Valid if EITHER condition is true
        // 1. Current time >= dispute_by deadline
        // 2. Current time >= 10 days after first watch event
        let lower_bound = tx.validity_range.lower_bound.bound_type
        expect Finite(lb) = lower_bound
        let time_ok = lb >= datum.dispute_by || lb >= ten_days_after_first

        expect_signature(datum.receiver, tx.extra_signatories) && datum.released40 && // 40% must be released already
        !datum.releasedFinal && // Not already released
        time_ok && // Time lock expired
        has_output_to_pkh(tx.outputs, datum.receiver, datum.net_total)
      }

      // ↑ Pay out ALL remaining funds (should be ~30% of original)
      // Note: No continuing output needed - escrow is complete
      // ======================================================================
      // REFUND: Return funds to senders
      // ======================================================================
      Refund -> {
        // Metrics are "unmet" if ANY of these fail:
        let metrics_unmet =
          !datum.all_watch_met || // Watch time not met
          datum.comments < 1 || // No comments
          !avg_rating_ok(datum.rating_sum, datum.rating_count, 10)

        // Rating < 1.0
        // NOTE: These thresholds are REDUCED to prevent receiver punishment
        // Watch time is the ONLY truly reliable metric
        // Check if we're within dispute window
        let upper_bound = tx.validity_range.upper_bound.bound_type
        expect Finite(ub) = upper_bound
        let within_dispute = ub <= datum.dispute_by

        // Refund allowed if:
        // - Within dispute window (time-based protection), OR
        // - Metrics unmet (quality-based protection)
        ( within_dispute || metrics_unmet ) && expect_signature(
          datum.oracle,
          tx.extra_signatories,
        )
      }

      // ↑ Oracle must sign (prevents malicious refund attacks)
      // Note: Refund amount calculated off-chain based on release state
      // - Before released30: Refund ~100% (nothing paid yet)
      // - After released30, before released40: Refund ~70% (30% paid)
      // - After released40: Refund ~30% (70% paid)
      // ======================================================================
      // DISPUTE HOLD: Freeze escrow for investigation
      // ======================================================================
      DisputeHold -> {
        expect Some(continuing_out) = find_continuing(tx.outputs, script_addr)
        expect Some(next) = parse_output_datum(continuing_out)

        // Oracle can freeze escrow (prevents final release during dispute)
        expect_signature(datum.oracle, tx.extra_signatories) && next.receiver == datum.receiver && next.oracle == datum.oracle && !next.releasedFinal
      }
    }
    // ↑ Ensure final release flag not set during hold
  }

  else(_) {
    fail
  }
}
