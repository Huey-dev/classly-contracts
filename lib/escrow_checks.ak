use types.{fourteen_days_ms}

// Unit-level gates plus scenario-style simulations for the 30/40/30 escrow flow.
// These tests run off-chain (pure functions), but mirror how funds and gates behave.

// -----------------------------------------------------------------------------
// Basic gate helpers
// -----------------------------------------------------------------------------

fn phase_amounts_ok(total: Int, p1: Int, p2: Int, p3: Int) -> Bool {
  // Enforce 30/40/30 split and non-zero total.
  p1 + p2 + p3 == total && p1 == total * 30 / 100 && p2 == total * 40 / 100 && p3 == total * 30 / 100 && total > 0
}

fn final_ready(dispute_start: Int, current_time: Int) -> Bool {
  // Final 30% time-gate: 14 days after dispute_start/first_watch.
  current_time >= dispute_start + fourteen_days_ms
}

fn refund_amount(
  phase2_released: Bool,
  phase3_released: Bool,
  phase2_amount: Int,
  phase3_amount: Int,
  dispute_start: Int,
  current_time: Int,
) -> Option<Int> {
  // Before metrics (phase2_released = False): refund 70% (phase2 + phase3).
  if !phase2_released {
    Some(phase2_amount + phase3_amount)
  } else if !phase3_released {
    // After metrics but before final: refund 30% only within the 14-day window.
    if current_time < dispute_start + fourteen_days_ms {
      Some(phase3_amount)
    } else {
      None
    }
  } else {
    // After final release: nothing to refund.
    None
  }
}

// -----------------------------------------------------------------------------
// Unit tests for the basic gate helpers
// -----------------------------------------------------------------------------
test splits_enforce_30_40_30() {
  phase_amounts_ok(10_000_000, 3_000_000, 4_000_000, 3_000_000) == True && phase_amounts_ok(
    10_000_000,
    2_000_000,
    4_000_000,
    4_000_000,
  ) == False
}

// -----------------------------------------------------------------------------
// Unit tests for the final_ready and refund_amount functions
// -----------------------------------------------------------------------------
test final_requires_14_days_elapsed() {
  let start = 1_000_000
  final_ready(start, start + fourteen_days_ms - 1) == False && final_ready(
    start,
    start + fourteen_days_ms,
  ) == True
}

test refund_paths_before_and_after_milestone() {
  let ds = 1_000_000
  // Before metrics: 70%
  refund_amount(False, False, 4_000_000, 3_000_000, 0, 0) == Some(7_000_000) && // After metrics, within window: 30%
  refund_amount(
    True,
    False,
    4_000_000,
    3_000_000,
    ds,
    ds + fourteen_days_ms - 1,
  ) == Some(3_000_000) && // After window: none
  refund_amount(
    True,
    False,
    4_000_000,
    3_000_000,
    ds,
    ds + fourteen_days_ms + 1,
  ) == None
}

// -----------------------------------------------------------------------------
// Scenario-style simulations (off-chain)
// -----------------------------------------------------------------------------
// We simulate how the state would change as senders pay, fees are taken off-chain,
// and gates are checked:
// - Gross payment -> 7% platform fee removed -> 93% net counted as locked.
// - Senders 1-4: accumulation only.
// - Sender 5: batch release 30% of total locked so far.
// - Sender 6+: incremental release 30% of that sender's net payment.
// - Metrics gate (watch_all + comments >=3 + avg rating >=3.5) unlocks 40%.
// - Final gate unlocks remaining 30% after 14 days from first watch when 40% is done.

type State {
  locked: Int,
  paid_out: Int,
  paid_count: Int,
  released30: Bool,
  released40: Bool,
  releasedFinal: Bool,
  watch_all: Bool,
  comments: Int,
  rating_sum: Int,
  // x10
  rating_count: Int,
}

fn platform_net(amount: Int) -> Int {
  amount * 93 / 100
  // simulate 7% fee off-chain
}

fn add_sender(
  state: State,
  gross_amount: Int,
  watch: Bool,
  rating_x10: Int,
  commented: Bool,
) -> State {
  let net = platform_net(gross_amount)
  let new_count = state.paid_count + 1
  let immediate =
    if new_count == 5 {
      // batch 30% of total locked so far
      ( state.locked + net ) * 30 / 100
    } else if new_count > 5 {
      // 30% of this sender's payment
      net * 30 / 100
    } else {
      0
    }
  let new_locked = state.locked + net - immediate
  let new_out = state.paid_out + immediate
  let new_released30 = state.released30 || new_count >= 5
  let new_watch =
    if state.paid_count == 0 {
      watch
    } else {
      state.watch_all && watch
    }
  let new_comments =
    state.comments + if commented {
      1
    } else {
      0
    }
  let new_rsum = state.rating_sum + rating_x10
  let new_rcount =
    state.rating_count + if rating_x10 > 0 {
      1
    } else {
      0
    }

  State {
    locked: new_locked,
    paid_out: new_out,
    paid_count: new_count,
    released30: new_released30,
    released40: state.released40,
    releasedFinal: state.releasedFinal,
    watch_all: new_watch,
    comments: new_comments,
    rating_sum: new_rsum,
    rating_count: new_rcount,
  }
}

fn can_release40(state: State) -> Bool {
  let avg_ok =
    if state.rating_count == 0 {
      False
    } else {
      state.rating_sum * 1_000 >= 35 * state.rating_count * 100
    }
  // avg >= 3.5
  state.released30 && !state.released40 && state.watch_all && state.comments >= 3 && avg_ok
}

fn release40(state: State) -> State {
  if can_release40(state) {
    let payout = state.locked * 40 / 100
    State {
      ..state,
      locked: state.locked - payout,
      paid_out: state.paid_out + payout,
      released40: True,
    }
  } else {
    state
  }
}

fn can_release_final(state: State, first_watch: Int, now: Int) -> Bool {
  now >= first_watch + fourteen_days_ms && state.released40 && !state.releasedFinal
}

fn release_final(state: State) -> State {
  State {
    ..state,
    paid_out: state.paid_out + state.locked,
    locked: 0,
    releasedFinal: True,
  }
}

// Happy path: 6 senders, batch 30%, incremental 30%, metrics ok -> 40%, final after 14d
test scenario_pass_full_happy_path() {
  let s0 =
    State {
      locked: 0,
      paid_out: 0,
      paid_count: 0,
      released30: False,
      released40: False,
      releasedFinal: False,
      watch_all: True,
      comments: 0,
      rating_sum: 0,
      rating_count: 0,
    }

  // Accumulate to 4 senders (no release)
  let s1 = add_sender(s0, 10_000_000, True, 40, True)
  let s2 = add_sender(s1, 10_000_000, True, 40, True)
  let s3 = add_sender(s2, 10_000_000, True, 40, True)
  let s4 = add_sender(s3, 10_000_000, True, 40, True)
  // Sender 5: batch 30% of total
  let s5 = add_sender(s4, 10_000_000, True, 40, True)
  // Sender 6: incremental 30% of this payment
  let s6 = add_sender(s5, 10_000_000, True, 40, True)

  // Metrics gate -> 40%
  let s7 = release40(s6)
  // Final gate -> remaining 30% after 14 days
  let final_ok = can_release_final(s7, 1_000_000, 1_000_000 + fourteen_days_ms)
  let s8 =
    if final_ok {
      release_final(s7)
    } else {
      s7
    }

  s8.locked == 0 && s8.paid_out > 0 && s8.releasedFinal
}

// Fail: metrics/watch/comments insufficient for 40%
test scenario_fail_release40_due_to_metrics() {
  let s0 =
    State {
      locked: 100_000_000,
      paid_out: 30_000_000,
      paid_count: 6,
      released30: True,
      released40: False,
      releasedFinal: False,
      watch_all: False,
      // fails here
      comments: 2,
      // too low
      rating_sum: 100,
      // avg ~1.6
      rating_count: 6,
    }
  can_release40(s0) == False
}

// Fail: final before 14 days (time lock not yet satisfied)
test scenario_fail_final_before_14_days() {
  let s0 =
    State {
      locked: 30_000_000,
      paid_out: 70_000_000,
      paid_count: 6,
      released30: True,
      released40: True,
      releasedFinal: False,
      watch_all: True,
      comments: 5,
      rating_sum: 200,
      rating_count: 5,
    }
  can_release_final(s0, 1_000_000, 1_000_000 + fourteen_days_ms - 1) == False
}

// Refund scenarios: 70% before metrics, 30% within window after metrics, none after window
test scenario_refund_paths() {
  let before_metrics =
    refund_amount(False, False, 40_000_000, 30_000_000, 0, 0) == Some(
      70_000_000,
    )

  let within_window =
    refund_amount(
      True,
      False,
      40_000_000,
      30_000_000,
      1_000_000,
      1_000_000 + fourteen_days_ms - 1,
    ) == Some(30_000_000)

  let after_window =
    refund_amount(
      True,
      False,
      40_000_000,
      30_000_000,
      1_000_000,
      1_000_000 + fourteen_days_ms + 1,
    ) == None

  before_metrics && within_window && after_window
}
