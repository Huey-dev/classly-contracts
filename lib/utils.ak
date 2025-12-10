use aiken/collection/list
use aiken/interval.{Finite}
use cardano/address.{Address, VerificationKey}
use cardano/assets.{Value, ada_asset_name, ada_policy_id, quantity_of}
use cardano/transaction.{Output, ValidityRange}

// Generic helpers shared across validators.

pub fn lovelace_of(val: Value) -> Int {
  quantity_of(val, ada_policy_id, ada_asset_name)
}

pub fn payment_key(address: Address) -> Option<ByteArray> {
  when address.payment_credential is {
    VerificationKey(pk) -> Some(pk)
    _ -> None
  }
}

pub fn expect_signature(addr: Address, extra_sigs: List<ByteArray>) -> Bool {
  when payment_key(addr) is {
    Some(pk) -> list.has(extra_sigs, pk)
    None -> False
  }
}

pub fn has_output_to_address(outputs: List<Output>, addr: Address, min_amount: Int) -> Bool {
  list.any(outputs, fn(o) { o.address == addr && lovelace_of(o.value) >= min_amount })
}

pub fn find_output_to_address(outputs: List<Output>, addr: Address) -> Option<Output> {
  list.find(outputs, fn(o) { o.address == addr })
}

pub fn lower_bound_ms(range: ValidityRange) -> Option<Int> {
  when range.lower_bound.bound_type is {
    Finite(t) -> Some(t)
    _ -> None
  }
}

pub fn upper_bound_ms(range: ValidityRange) -> Option<Int> {
  when range.upper_bound.bound_type is {
    Finite(t) -> Some(t)
    _ -> None
  }
}
