// utils.ak - SIMPLIFIED
use aiken/collection/list
use aiken/interval.{Finite}
use cardano/address.{Address, VerificationKey}
use cardano/assets.{Value, ada_asset_name, ada_policy_id, quantity_of}
use cardano/transaction.{Output, ValidityRange}

pub fn lovelace_of(val: Value) -> Int {
  quantity_of(val, ada_policy_id, ada_asset_name)
}

pub fn payment_key(address: Address) -> Option<ByteArray> {
  when address.payment_credential is {
    VerificationKey(pk) -> Some(pk)
    _ -> None
  }
}

pub fn expect_signature(pkh: ByteArray, extra_sigs: List<ByteArray>) -> Bool {
  list.has(extra_sigs, pkh)
}

pub fn has_output_to_pkh(
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

pub fn find_continuing(
  outputs: List<Output>,
  script_addr: Address,
) -> Option<Output> {
  list.find(outputs, fn(o) { o.address == script_addr })
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