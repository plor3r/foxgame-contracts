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
const FoCManagerCap = env.FoCManagerCap;

const MovescriptionPackageId = env.MovescriptionPackageId;
const MovescriptionDeployRecord = env.MovescriptionDeployRecord;
const MovescriptionTICKTicketRecordV2Id = env.MovescriptionTICKTicketRecordV2Id;
const inscription_id = '0x5d84c32e1e0b9946e12c9278401a9b5f102bb8381d9d75c55068f04fae52fdd6';

// tx: GzXoZr7TpYoNn8VQHQdiXSRdR4VBkvFuC2jzR4ewYaoh

async function main() {
  const txb = new TransactionBlock();
  let amount = 1;
  // == deposit
  const tick_move = '0x16920d0e491485cc76f62cbe0814530707bc5b8d6577e03ff6fd92a430b59715';
  txb.moveCall({
    target: `${FoxGamePackageId}::fox::deploy`,
    arguments: [
      txb.object(FoCManagerCap),
      txb.object(MovescriptionDeployRecord),
      txb.object(MovescriptionTICKTicketRecordV2Id),
      txb.object(tick_move),
      txb.object('0x6')
    ],
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
