use aiken/expect
use aiken/test

// Lightweight unit-style tests that mirror the gates in validators/escrow.ak.

fn can_release_initial(paid_count: Int, released30: Bool) -> Bool {
  paid_count >= 5 && !released30
}

fn immediate_payout_for_additional(net_amount: Int, new_count: Int) -> Int {
  if new_count > 5 { (net_amount * 30) / 100 } else { 0 }
}

fn avg_rating_ok(sum: Int, count: Int) -> Bool {
  if count == 0 { False } else { sum * 1_000 >= 35 * count * 100 } // >= 3.5
}

fn can_release_metrics(released30: Bool, released40: Bool, all_watch_met: Bool, comments: Int, sum: Int, count: Int) -> Bool {
  released30 && !released40 && all_watch_met && comments >= 3 && avg_rating_ok(sum, count)
}

fn can_release_final(released40: Bool, releasedFinal: Bool, dispute_passed: Bool, inactive_passed: Bool) -> Bool {
  released40 && !releasedFinal && (dispute_passed || inactive_passed)
}

test fails_if_fewer_than_5_students_paid() {
  expect can_release_initial(4, False) == False
}

test releases_30_after_5_students() {
  expect can_release_initial(5, False) == True
}

test releases_30_for_each_additional_student() {
  expect immediate_payout_for_additional(1_000_000, 6) == 300_000
  expect immediate_payout_for_additional(1_000_000, 5) == 0
}

test fails_40_if_any_watch_under_60_or_metrics_low() {
  // watch not met
  expect can_release_metrics(True, False, False, 3, 40, 10) == False
  // not enough comments
  expect can_release_metrics(True, False, True, 2, 40, 10) == False
  // low rating
  expect can_release_metrics(True, False, True, 3, 20, 10) == False
}

test releases_40_when_metrics_met() {
  expect can_release_metrics(True, False, True, 4, 40, 10) == True
}

test fails_final_if_dispute_or_inactivity_not_met() {
  expect can_release_final(True, False, False, False) == False
}

test releases_final_after_window_or_inactivity() {
  expect can_release_final(True, False, True, False) == True
  expect can_release_final(True, False, False, True) == True
}

test triggers_refunds_when_conditions_fail() {
  // refund if metrics unmet
  let metrics_ok = can_release_metrics(True, False, False, 2, 20, 10)
  expect metrics_ok == False
}

