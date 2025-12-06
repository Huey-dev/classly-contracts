use aiken/list
use aiken/time
use aiken/transaction
use aiken/transaction.{ScriptContext, Tx, Output, Credential}

// Simplified, user-centric escrow with platform fee removal off-chain.
// Net amounts (after 25% platform fee) are recorded and split 30/40/30 with gates.

// Datum represents the aggregated course escrow state.
type EscrowDatum {
  Escrow {
    receiver    : Credential,   // course owner / seller
    oracle      : Credential,   // off-chain authority to attest metrics/disputes
    net_total   : Int,          // cumulative net funds (post-fee) locked
    paid_count  : Int,          // number of payers who funded
    paid_out    : Int,          // total already paid to receiver
    released30  : Bool,         // initial 30% batch paid (first 5 students)
    released40  : Bool,         // metrics batch paid
    releasedFinal : Bool,       // final 30% paid
    comments    : Int,          // aggregated comments count
    rating_sum  : Int,          // sum of ratings *10 (to avoid floats)
    rating_count: Int,          // number of ratings
    all_watch_met : Bool,       // true when all students have >=60% watch
    first_watch  : time.Time,   // timestamp of first watch event
    dispute_by   : time.Time    // deadline for dispute / final release
  }
}

// Redeemer captures intent and optional payload for payments/metrics.
type Redeemer {
  AddPayment { net_amount: Int, watch_met: Bool, rating_x10: Int, commented: Bool, first_watch_at: time.Time }
  ReleaseInitial
  ReleaseMetrics40
  ReleaseFinal
  Refund
  DisputeHold
}

fn expect_signature(cred: Credential, ctx: ScriptContext) -> Bool {
  when cred is {
    Credential::PubKey(pkh) -> transaction.tx_signed_by(ctx.transaction, pkh)
    Credential::Script(_) -> False
  }
}

fn lovelace_of(out: Output) -> Int {
  transaction.value_get_amount(out.value, "lovelace")
}

fn find_continuing(ctx: ScriptContext) -> Option<Output> {
  list.find(ctx.outputs, fn(o: Output) { o.address == ctx.script_address })
}

fn continuing_matches(ctx: ScriptContext, predicate: fn(EscrowDatum) -> Bool) -> Bool {
  find_continuing(ctx)
    |> Option.map(fn(o: Output) {
         when o.datum is {
           datum::inline(next: EscrowDatum) -> predicate(next)
           _ -> False
         }
       })
    |> Option.unwrap_or(False)
}

fn avg_rating_ok(sum: Int, count: Int, threshold_x10: Int) -> Bool {
  if count == 0 {
    False
  } else {
    sum * 1_000 >= threshold_x10 * count * 100  // compare with scale to avoid floats
  }
}

validator escrow(datum: EscrowDatum, redeemer: Redeemer, ctx: ScriptContext) -> Bool {
  let tx = ctx.transaction

  when datum is {
    Escrow{
      receiver, oracle, net_total, paid_count, paid_out,
      released30, released40, releasedFinal,
      comments, rating_sum, rating_count, all_watch_met,
      first_watch, dispute_by
    } -> {
      when redeemer is {
        Redeemer::AddPayment{ net_amount, watch_met, rating_x10, commented, first_watch_at } -> {
          // Off-chain already removed 25% platform fee; net_amount is what enters script.
          // If payer index >5, allow immediate 30% payout from this net_amount.
          let new_count = paid_count + 1
          let immediate_payout = if new_count > 5 { (net_amount * 30) / 100 } else { 0 }
          // Check receiver gets immediate payout if applicable
          let ok_payout =
            if immediate_payout > 0 {
              list.any(ctx.outputs, fn(o: Output) {
                o.address.credential == receiver && lovelace_of(o) >= immediate_payout
              })
            } else { True }

          ok_payout &&
          continuing_matches(ctx, fn(next: EscrowDatum) {
            when next is {
              Escrow{
                receiver: r2, oracle: o2, net_total: nt2, paid_count: pc2, paid_out: po2,
                released30: rel30, released40: rel40, releasedFinal: relF,
                comments: c2, rating_sum: rs2, rating_count: rc2, all_watch_met: aw2,
                first_watch: fw2, dispute_by: db2
              } ->
                r2 == receiver &&
                o2 == oracle &&
                nt2 == net_total + net_amount - immediate_payout &&
                pc2 == new_count &&
                po2 == paid_out + immediate_payout &&
                rel30 == released30 &&
                rel40 == released40 &&
                relF == releasedFinal &&
                c2 == comments + (if commented { 1 } else { 0 }) &&
                rs2 == rating_sum + rating_x10 &&
                rc2 == rating_count + (if rating_x10 > 0 { 1 } else { 0 }) &&
                aw2 == (all_watch_met && watch_met) ||
                       (paid_count == 0 && watch_met) ||
                       (all_watch_met && !watch_met == False) ||
                       (watch_met && paid_count == pc2 - 1) ||
                       (all_watch_met) || False &&
                // first_watch set to earliest observed
                fw2 == (if first_watch == time.from_posix(0) { first_watch_at } else { first_watch }) &&
                db2 == dispute_by
            }
          })
        }

        Redeemer::ReleaseInitial ->
          expect_signature(receiver, ctx)
            && paid_count >= 5
            && !released30
            && list.any(ctx.outputs, fn(o: Output) {
                 o.address.credential == receiver &&
                 lovelace_of(o) >= (net_total * 30) / 100
               })
            && continuing_matches(ctx, fn(next: EscrowDatum) {
                 when next is {
                   Escrow{ released30: True, paid_out: po2, net_total: nt2, ..old } ->
                     po2 == paid_out + (net_total * 30) / 100 &&
                     nt2 == net_total - (net_total * 30) / 100 &&
                     old.receiver == receiver && old.oracle == oracle
                 }
               })

        Redeemer::ReleaseMetrics40 ->
          expect_signature(receiver, ctx)
            && released30
            && !released40
            && all_watch_met
            && comments >= 3
            && avg_rating_ok(rating_sum, rating_count, 35) // >=3.5
            && list.any(ctx.outputs, fn(o: Output) {
                 o.address.credential == receiver &&
                 lovelace_of(o) >= (net_total * 40) / 100
               })
            && continuing_matches(ctx, fn(next: EscrowDatum) {
                 when next is {
                   Escrow{ released40: True, paid_out: po2, net_total: nt2, ..old } ->
                     po2 == paid_out + (net_total * 40) / 100 &&
                     nt2 == net_total - (net_total * 40) / 100 &&
                     old.receiver == receiver && old.oracle == oracle
                 }
               })

        Redeemer::ReleaseFinal ->
          expect_signature(receiver, ctx)
            && released40
            && !releasedFinal
            && (time.after(dispute_by, tx.valid_range) || time.before(first_watch + time.from_seconds(10 * 24 * 3600), tx.valid_range))
            && list.any(ctx.outputs, fn(o: Output) {
                 o.address.credential == receiver &&
                 lovelace_of(o) >= (net_total * 30) / 100
               })
            // final consumption; state can be burned

        Redeemer::Refund ->
          // Refund allowed if metrics unmet or within dispute window with oracle signature
          (time.before(dispute_by, tx.valid_range) || !all_watch_met || comments < 3 || !avg_rating_ok(rating_sum, rating_count, 35))
            && (expect_signature(oracle, ctx))

        Redeemer::DisputeHold ->
          expect_signature(oracle, ctx)
            && continuing_matches(ctx, fn(next: EscrowDatum) {
                 when next is {
                   Escrow{ receiver: r2, oracle: o2, ..old } ->
                     r2 == receiver && o2 == oracle && old.releasedFinal == False
                 }
               })
      }
    }
  }
}

