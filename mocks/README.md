# MockTail / pseudo-UTxO notes

Place your mock transaction builders and state snapshots here to simulate:
- initial lock (paid_count < 5)
- crossing to paid_count = 5 (initial 30% release)
- additional student payment (>5) with immediate 30% from that payer
- metrics met / unmet for the 40% release
- dispute window vs inactivity for final release
- refund scenarios

These mocks should mirror the datum/redeemer shapes in `lib/classly_escrow_30_40_30_v3.ak`.
