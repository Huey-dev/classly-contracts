use aiken/builtin.{append_bytearray, blake2b_256}
use aiken/collection/list
use aiken/crypto.{verify_ed25519_signature}
use cardano/address.{VerificationKey}
use cardano/assets.{PolicyId, quantity_of}
use cardano/script_context.{Minting, ScriptContext}
use cardano/transaction.{Output}
use types.{CompletionRedeemer, CompletionProof}
use oracle.{build_completion_message}

// Derive a deterministic asset name from sender and resource to guarantee uniqueness.
fn asset_name_from_proof(proof: CompletionProof) -> ByteArray {
  let seed = append_bytearray(proof.sender_pkh, proof.resource_id)
  blake2b_256(seed)
}

fn has_token_at(
  outputs: List<Output>,
  receiver_pkh: ByteArray,
  policy_id: PolicyId,
  asset_name: ByteArray,
) -> Bool {
  list.any(
    outputs,
    fn(o) {
      when o.address.payment_credential is {
        VerificationKey(pk) ->
          pk == receiver_pkh && quantity_of(o.value, policy_id, asset_name) >= 1
        _ -> False
      }
    },
  )
}

validator completion_nft_policy {
  mint(_ignored: Data, redeemer: CompletionRedeemer, ctx: ScriptContext) {
    when redeemer is {
      CompletionRedeemer.MintCompletion { proof, oracle_pubkey } -> {
        // Must be a full completion proof
        expect proof.completion_percentage == 100

        // Oracle signature over the proof message
        let msg = build_completion_message(
          proof.sender_pkh,
          proof.resource_id,
          proof.timestamp,
          proof.nonce,
        )
        expect verify_ed25519_signature(oracle_pubkey, msg, proof.signature)

        // Validate mint intent and delivery
        when ctx.info is {
          Minting(policy_id) -> {
            let asset_name = asset_name_from_proof(proof)
            expect quantity_of(ctx.transaction.mint, policy_id, asset_name) == 1
            expect has_token_at(
              ctx.transaction.outputs,
              proof.sender_pkh,
              policy_id,
              asset_name,
            )
            True
          }
          _ -> False
        }
      }
    }
  }

  else(_) {
    fail
  }
}
