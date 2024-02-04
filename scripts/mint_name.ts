import { loadSync as loadEnvSync } from "https://deno.land/std/dotenv/mod.ts"
import { getFullnodeUrl, SuiClient } from 'npm:@mysten/sui.js/client';
import { Ed25519Keypair } from 'npm:@mysten/sui.js/keypairs/ed25519';
import { TransactionBlock } from 'npm:@mysten/sui.js/transactions';

const env = loadEnvSync();
const secret_key_mnemonics = env.SECRET_KEY_ED25519_1_MNEMONICS;
const keypair = Ed25519Keypair.deriveKeypair(secret_key_mnemonics);
console.log(keypair.getPublicKey().toSuiAddress())

const client = new SuiClient({
  url: getFullnodeUrl(env.Network),
});

const MovescriptionPackageId = env.MovescriptionPackageId;
const MovescriptionTicketRecordV2Id = env.MovescriptionNAMETicketRecordV2Id;
const inscription_id = '0x6aff26fd26215b3d2122746512646b1221327b6df9920e7bdebbb34c2a76f7d8';

async function main() {
  const txb = new TransactionBlock();

  const [ins] = txb.moveCall({
    target: `${MovescriptionPackageId}::movescription::do_split`,
    arguments: [txb.object(inscription_id), txb.pure(1001)],
  });

  txb.moveCall({
    target: `${MovescriptionPackageId}::name_factory::mint`,
    arguments: [txb.object(MovescriptionTicketRecordV2Id), ins, txb.pure("FoxGame"), txb.object('0x6')],
  });

  txb.setGasBudget(2_000_000_000)
  txb.setSender(keypair.getPublicKey().toSuiAddress());
  try {
    const result = await client.signAndExecuteTransactionBlock({
      transactionBlock: txb,
      signer: keypair,
      requestType: 'WaitForLocalExecution',
      options: {
        showEffects: false,
      },
    });
    console.log(result);
  } catch (error) {
    console.log(error)
  }
}

main();
