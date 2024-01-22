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

const FoxGamePackageId = env.FoxGamePackageId;
const FoxGameGlobal = env.FoxGameGlobal;
const EggTreasuryCap = env.EggTreasuryCap;

const MovescriptionPackageId = env.MovescriptionPackageId;
const inscription_id = '0x0d8fd7b5903736ac7b564ec90d31efa4359452370f38f18f41ba27147847abce';

async function main() {
  const txb = new TransactionBlock();
  let amount = 10;
  // == deposit
  const [move] = txb.moveCall({
    target: `${MovescriptionPackageId}::movescription::do_split`,
    arguments: [txb.object(inscription_id), txb.pure(amount * 10000)],
  });
  txb.moveCall({
    target: `${FoxGamePackageId}::fox::mint`,
    arguments: [
      txb.object(FoxGameGlobal),
      txb.pure(amount),
      txb.pure(false),
      txb.object(move),
      txb.object('0x6')
    ],
  });

  txb.setGasBudget(6_000_000_000)
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
