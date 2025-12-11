// On-chain style tests for completion NFT policy and escrow validator.
// These build minimal ScriptContexts and Transactions to exercise success
// and failure paths.

use aiken/builtin.{append_bytearray}
use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{Signature, VerificationKey, blake2b_256}
use aiken/interval.{Interval, IntervalBound, IntervalBoundType}
use cardano/address.{Address, Credential}
use cardano/assets.{
  AssetName, PolicyId, Value, ada_asset_name, ada_policy_id, from_asset, zero,
}
use cardano/script_context.{Minting, ScriptContext}
use cardano/transaction.{
  Datum, Input, Output, OutputReference, Transaction, ValidityRange,
}
use types
use validators/completion_nft_policy as completion_nft_policy
use validators/escrow as escrow

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
fn inf_interval() -> ValidityRange {
  Interval {
    lower_bound: IntervalBound {
      bound_type: IntervalBoundType.NegativeInfinity,
      is_inclusive: True,
    },
    upper_bound: IntervalBound {
      bound_type: IntervalBoundType.PositiveInfinity,
      is_inclusive: True,
    },
  }
}

fn mk_tx(
  outputs: List<Output>,
  mint: Value,
  validity: ValidityRange,
  extra_sigs: List<VerificationKey>,
) -> Transaction {
  Transaction {
    inputs: [],
    reference_inputs: [],
    outputs,
    fee: 0,
    mint,
    certificates: [],
    withdrawals: [],
    validity_range: validity,
    extra_signatories: extra_sigs,
    redeemers: [],
    datums: dict.empty,
    id: #"00",
    votes: [],
    proposal_procedures: [],
    current_treasury_amount: None,
    treasury_donation: None,
  }
}

fn mk_address_from_pkh(pkh: VerificationKey) -> Address {
  Address {
    payment_credential: Credential.VerificationKey(pkh),
    stake_credential: None,
  }
}

fn mk_script_address(hash: ByteArray) -> Address {
  Address {
    payment_credential: Credential.Script(hash),
    stake_credential: None,
  }
}

// Precomputed values for minting policy happy path
const sender_pkh: ByteArray =
  #"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const resource_id: ByteArray = #"01"

const oracle_pk: VerificationKey =
  #"38cfe74f7da0cf491401adf9602f09dc0f6504325df15e12ed8a1c2270ad7303"

const good_sig: Signature =
  #"06983452aacee411a729a54021a4b751c5f16f2374ab65f2c7fb88e83fe7652ac69717397f7e0ba7dd2569d60577a020ce318931e2b95311ecfc656bb4306e04"

const policy_id: PolicyId = #"111111111111111111111111111111111111111111111111"

const completion_asset_name: AssetName =
  blake2b_256(append_bytearray(sender_pkh, resource_id))

fn minted_value(qty: Int) -> Value {
  from_asset(policy_id, completion_asset_name, qty)
}

fn minted_output_to_sender(qty: Int) -> Output {
  Output {
    address: mk_address_from_pkh(sender_pkh),
    value: from_asset(policy_id, completion_asset_name, qty),
    datum: Datum.NoDatum,
    reference_script: None,
  }
}

// ---------------------------------------------------------------------------
// Completion NFT policy tests
// ---------------------------------------------------------------------------
test mint_happy_path() {
  let proof =
    types.CompletionProof {
      sender_pkh,
      resource_id,
      completion_percentage: 100,
      timestamp: 1,
      nonce: #"02",
      signature: good_sig,
    }

  let redeemer =
    types.CompletionRedeemer.MintCompletion { proof, oracle_pubkey: oracle_pk }

  let tx =
    mk_tx([minted_output_to_sender(1)], minted_value(1), inf_interval(), [])

  let ctx =
    ScriptContext {
      transaction: tx,
      redeemer: Datum.NoDatum,
      info: Minting(policy_id),
    }

  completion_nft_policy.mint(redeemer, ctx)
}

test mint_bad_signature() fail {
  let proof =
    types.CompletionProof {
      sender_pkh,
      resource_id,
      completion_percentage: 100,
      timestamp: 1,
      nonce: #"02",
      signature: #"00",
    }

  let redeemer =
    types.CompletionRedeemer.MintCompletion { proof, oracle_pubkey: oracle_pk }

  let tx =
    mk_tx([minted_output_to_sender(1)], minted_value(1), inf_interval(), [])

  let ctx =
    ScriptContext {
      transaction: tx,
      redeemer: Datum.NoDatum,
      info: Minting(policy_id),
    }

  completion_nft_policy.mint(redeemer, ctx)
}

test mint_wrong_quantity() fail {
  let proof =
    types.CompletionProof {
      sender_pkh,
      resource_id,
      completion_percentage: 100,
      timestamp: 1,
      nonce: #"02",
      signature: good_sig,
    }

  let redeemer =
    types.CompletionRedeemer.MintCompletion { proof, oracle_pubkey: oracle_pk }

  let tx =
    mk_tx([minted_output_to_sender(2)], minted_value(2), inf_interval(), [])

  let ctx =
    ScriptContext {
      transaction: tx,
      redeemer: Datum.NoDatum,
      info: Minting(policy_id),
    }

  completion_nft_policy.mint(redeemer, ctx)
}

test mint_wrong_recipient() fail {
  let proof =
    types.CompletionProof {
      sender_pkh,
      resource_id,
      completion_percentage: 100,
      timestamp: 1,
      nonce: #"02",
      signature: good_sig,
    }

  let redeemer =
    types.CompletionRedeemer.MintCompletion { proof, oracle_pubkey: oracle_pk }

  let wrong_recipient =
    Output {
      address: mk_address_from_pkh(
        #"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      ),
      value: from_asset(policy_id, completion_asset_name, 1),
      datum: Datum.NoDatum,
      reference_script: None,
    }

  let tx = mk_tx([wrong_recipient], minted_value(1), inf_interval(), [])

  let ctx =
    ScriptContext {
      transaction: tx,
      redeemer: Datum.NoDatum,
      info: Minting(policy_id),
    }

  completion_nft_policy.mint(redeemer, ctx)
}

// ---------------------------------------------------------------------------
// Escrow validator tests (one per redeemer path)
// ---------------------------------------------------------------------------
fn base_datum() -> escrow.EscrowDatum {
  escrow.EscrowDatum {
    receiver: #"999999999999999999999999999999999999999999999999",
    oracle: #"888888888888888888888888888888888888888888888888",
    net_total: 0,
    paid_count: 0,
    paid_out: 0,
    released30: False,
    released40: False,
    releasedFinal: False,
    comments: 0,
    rating_sum: 0,
    rating_count: 0,
    all_watch_met: False,
    first_watch: 0,
    dispute_by: 0,
  }
}

fn script_addr() -> Address {
  mk_script_address(#"deadbeef")
}

fn own_ref0() -> OutputReference {
  OutputReference { transaction_id: #"00", output_index: 0 }
}

test escrow_add_payment_releases_30_on_5th() {
  let base = base_datum()
  let datum =
    escrow.EscrowDatum {
      receiver: base.receiver,
      oracle: base.oracle,
      net_total: 40,
      paid_count: 4,
      paid_out: 0,
      released30: False,
      released40: False,
      releasedFinal: False,
      comments: 0,
      rating_sum: 0,
      rating_count: 0,
      all_watch_met: True,
      first_watch: 0,
      dispute_by: 0,
    }

  let redeemer =
    escrow.Redeemer.AddPayment {
      net_amount: 10,
      watch_met: True,
      rating_x10: 0,
      commented: False,
      first_watch_at: 0,
    }

  let payout =
    Output {
      address: mk_address_from_pkh(datum.receiver),
      value: from_asset(ada_policy_id, ada_asset_name, 15),
      datum: Datum.NoDatum,
      reference_script: None,
    }

  let continuing_datum =
    escrow.EscrowDatum {
      receiver: datum.receiver,
      oracle: datum.oracle,
      net_total: 35,
      paid_count: 5,
      paid_out: 15,
      released30: True,
      released40: False,
      releasedFinal: False,
      comments: 0,
      rating_sum: 0,
      rating_count: 0,
      all_watch_met: True,
      first_watch: 0,
      dispute_by: 0,
    }

  let continuing =
    Output {
      address: script_addr(),
      value: from_asset(ada_policy_id, ada_asset_name, 35),
      datum: Datum.InlineDatum(continuing_datum),
      reference_script: None,
    }

  let own_input =
    Input {
      output_reference: own_ref0(),
      output: Output {
        address: script_addr(),
        value: from_asset(ada_policy_id, ada_asset_name, 40),
        datum: Datum.InlineDatum(datum),
        reference_script: None,
      },
    }

  let tx =
    Transaction {
      inputs: [own_input],
      reference_inputs: [],
      outputs: [payout, continuing],
      fee: 0,
      mint: zero,
      certificates: [],
      withdrawals: [],
      validity_range: inf_interval(),
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"00",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  escrow.spend(Some(datum), redeemer, own_ref0(), tx)
}

test escrow_release_metrics_40() {
  let base = base_datum()
  let datum =
    escrow.EscrowDatum {
      receiver: base.receiver,
      oracle: base.oracle,
      net_total: 100,
      paid_count: 5,
      paid_out: 30,
      released30: True,
      released40: False,
      releasedFinal: False,
      comments: 1,
      rating_sum: 10,
      rating_count: 1,
      all_watch_met: True,
      first_watch: 0,
      dispute_by: 0,
    }

  let redeemer = escrow.Redeemer.ReleaseMetrics40

  let payout =
    Output {
      address: mk_address_from_pkh(datum.receiver),
      value: from_asset(ada_policy_id, ada_asset_name, 40),
      datum: Datum.NoDatum,
      reference_script: None,
    }

  let continuing_datum =
    escrow.EscrowDatum {
      receiver: datum.receiver,
      oracle: datum.oracle,
      net_total: 60,
      paid_count: 5,
      paid_out: 70,
      released30: True,
      released40: True,
      releasedFinal: False,
      comments: 1,
      rating_sum: 10,
      rating_count: 1,
      all_watch_met: True,
      first_watch: 0,
      dispute_by: 0,
    }

  let continuing =
    Output {
      address: script_addr(),
      value: from_asset(ada_policy_id, ada_asset_name, 60),
      datum: Datum.InlineDatum(continuing_datum),
      reference_script: None,
    }

  let own_input =
    Input {
      output_reference: own_ref0(),
      output: Output {
        address: script_addr(),
        value: from_asset(ada_policy_id, ada_asset_name, 100),
        datum: Datum.InlineDatum(datum),
        reference_script: None,
      },
    }

  let tx =
    Transaction {
      inputs: [own_input],
      reference_inputs: [],
      outputs: [payout, continuing],
      fee: 0,
      mint: zero,
      certificates: [],
      withdrawals: [],
      validity_range: inf_interval(),
      extra_signatories: [datum.receiver],
      redeemers: [],
      datums: dict.empty,
      id: #"00",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  escrow.spend(Some(datum), redeemer, own_ref0(), tx)
}

test escrow_release_final_time_ok() {
  let base = base_datum()
  let datum =
    escrow.EscrowDatum {
      receiver: base.receiver,
      oracle: base.oracle,
      net_total: 60,
      paid_count: 5,
      paid_out: 70,
      released30: True,
      released40: True,
      releasedFinal: False,
      comments: 1,
      rating_sum: 10,
      rating_count: 1,
      all_watch_met: True,
      first_watch: 0,
      dispute_by: 1_000,
    }

  let redeemer = escrow.Redeemer.ReleaseFinal

  let payout =
    Output {
      address: mk_address_from_pkh(datum.receiver),
      value: from_asset(ada_policy_id, ada_asset_name, 60),
      datum: Datum.NoDatum,
      reference_script: None,
    }

  let validity =
    Interval {
      lower_bound: IntervalBound {
        bound_type: IntervalBoundType.Finite(2_000),
        is_inclusive: True,
      },
      upper_bound: IntervalBound {
        bound_type: IntervalBoundType.PositiveInfinity,
        is_inclusive: True,
      },
    }

  let own_input =
    Input {
      output_reference: own_ref0(),
      output: Output {
        address: script_addr(),
        value: from_asset(ada_policy_id, ada_asset_name, 60),
        datum: Datum.InlineDatum(datum),
        reference_script: None,
      },
    }

  let tx =
    Transaction {
      inputs: [own_input],
      reference_inputs: [],
      outputs: [payout],
      fee: 0,
      mint: zero,
      certificates: [],
      withdrawals: [],
      validity_range: validity,
      extra_signatories: [datum.receiver],
      redeemers: [],
      datums: dict.empty,
      id: #"00",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  escrow.spend(Some(datum), redeemer, own_ref0(), tx)
}

test escrow_refund_metrics_unmet() {
  let base = base_datum()
  let datum =
    escrow.EscrowDatum {
      receiver: base.receiver,
      oracle: base.oracle,
      net_total: 60,
      paid_count: 5,
      paid_out: 30,
      released30: True,
      released40: False,
      releasedFinal: False,
      comments: 0,
      // metrics unmet (no comments)
      rating_sum: 0,
      rating_count: 0,
      all_watch_met: False,
      // metrics unmet (watch not met)
      first_watch: 0,
      dispute_by: 1_000,
    }

  let redeemer = escrow.Redeemer.Refund

  let validity =
    Interval {
      lower_bound: IntervalBound {
        bound_type: IntervalBoundType.NegativeInfinity,
        is_inclusive: True,
      },
      upper_bound: IntervalBound {
        bound_type: IntervalBoundType.Finite(500),
        is_inclusive: True,
      },
    }

  let own_input =
    Input {
      output_reference: own_ref0(),
      output: Output {
        address: script_addr(),
        value: from_asset(ada_policy_id, ada_asset_name, 60),
        datum: Datum.InlineDatum(datum),
        reference_script: None,
      },
    }

  let tx =
    Transaction {
      inputs: [own_input],
      reference_inputs: [],
      outputs: [],
      fee: 0,
      mint: zero,
      certificates: [],
      withdrawals: [],
      validity_range: validity,
      extra_signatories: [datum.oracle],
      redeemers: [],
      datums: dict.empty,
      id: #"00",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }

  escrow.spend(Some(datum), redeemer, own_ref0(), tx)
}
