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

// tx: GzXoZr7TpYoNn8VQHQdiXSRdR4VBkvFuC2jzR4ewYaoh

async function main() {
  const txb = new TransactionBlock();
  let amount = 1;
  // == deposit
  // const tick_move = '0x889bb82ce46d3e9af0eec1de9439ca86a9c6f718dcefef1ad625510b92a9aeec'; // WOLFi
  const tick_move = '0x034863628feb7cdc0e5d9595f71b053db4926ad52c94eae84edaadf97220f324'; // WOOLi
  txb.moveCall({
    target: `${FoxGamePackageId}::fox::deploy_eggs`,
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
