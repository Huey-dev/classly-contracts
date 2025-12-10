// use aiken/builtin.{blake2b_256, concat_bytearray, serialise_data}
// use aiken/collection/list
// use aiken/crypto.{verify_ed25519_signature}
// use cardano/address.{Address}
// use cardano/assets.{quantity_of}
// use cardano/transaction.{Minting, Output, Transaction}
// use types.{CompletionRedeemer, CompletionProof}
// use oracle.{build_completion_message}

// fn asset_name_from_proof(proof: CompletionProof) -> ByteArray {
//   blake2b_256(
//     concat_bytearray(
//       serialise_data(proof.sender_address),
//       proof.resource_id,
//     ),
//   )
// }

// fn has_token_at(outputs: List<Output>, addr: Address, policy_id: ByteArray, asset_name: ByteArray) -> Bool {
//   list.any(
//     outputs,
//     fn(o) {
//       o.address == addr && quantity_of(o.value, policy_id, asset_name) >= 1
//     },
//   )
// }

// validator completion_nft_policy {
//   mint(redeemer: CompletionRedeemer, tx: Transaction) -> Bool {
//     when redeemer is {
//       MintCompletion { proof, oracle_pubkey } -> {
//         expect proof.completion_percentage == 100

//         let msg = build_completion_message(
//           proof.sender_address,
//           proof.resource_id,
//           proof.timestamp,
//           proof.nonce,
//         )
//         expect verify_ed25519_signature(oracle_pubkey, msg, proof.signature)

//         expect tx.purpose is {
//           Minting(policy_id) -> {
//             let asset_name = asset_name_from_proof(proof)
//             expect quantity_of(tx.mint, policy_id, asset_name) == 1
//             expect has_token_at(tx.outputs, proof.sender_address, policy_id, asset_name)
//             True
//           }
//           _ -> False
//         }
//       }
//     }
//   }
// }
