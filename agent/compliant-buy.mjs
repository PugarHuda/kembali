// Capstone: a COMPLIANT, REVERSIBLE, AGENT-driven payment — HashKey's regulated-DeFi thesis, live.
// 1) issuer attests the buyer (KYC + sanctions), 2) gate: only compliant buyers may pay,
// 3) agent opens a recourse-protected escrow, 4) seller doesn't deliver → agent auto-reclaims.
import { ethers } from "ethers";
const RPC="https://mainnet.hsk.xyz", K="0xDea6Da93265871d828B20cace2BADd5F5e70209d",
 USDC="0x481fE34ed995603abdB9998b7eCc8811e2707d87", NFT="0x6091e0111fB0F94fAE4b9D3Bbb0c36dD72D43454",
 REG="0xda0cEB552af13f5a096D8aA4E5A9FceB9cf6D8D0";
const p=new ethers.JsonRpcProvider(RPC,177);
const w=new ethers.Wallet("0x4d98b2d5d5a8f95e58c30fbda021b6f0ec36ee4c1ffa1d0a5b93fa1b9b47cf8c",p); // issuer + buyer (demo)
const KYC=ethers.keccak256(ethers.toUtf8Bytes("attests:kyc:v1")), SANC=ethers.keccak256(ethers.toUtf8Bytes("attests:sanctions:v1"));
const reg=new ethers.Contract(REG,["function attest(address,bytes32,uint64)","function compliant(address,bytes32[]) view returns (bool)"],w);
const MT="(bytes32 nonce,address signer,bytes32 grantRef,bytes32 requirementRef,address recipient,address token,uint256 amount,uint256 chainId,uint256 deadline,bytes32 settlementBinding,bytes32 requiredCapabilitiesHash)";
const ABI=[`function open(${MT} m,bytes signature,address merchant,address asset,uint256 item,uint8 kind,uint64 window) returns (bytes32)`,"function refund(bytes32 id)","function withdraw(address token)","function payments(bytes32) view returns (address,address,address,uint256,address,uint256,uint8,uint64,uint8)"];
const TYPES={Mandate:[{name:"nonce",type:"bytes32"},{name:"signer",type:"address"},{name:"grantRef",type:"bytes32"},{name:"requirementRef",type:"bytes32"},{name:"recipient",type:"address"},{name:"token",type:"address"},{name:"amount",type:"uint256"},{name:"chainId",type:"uint256"},{name:"deadline",type:"uint256"},{name:"settlementBinding",type:"bytes32"},{name:"requiredCapabilitiesHash",type:"bytes32"}]};
const Z="0x"+"00".repeat(32), merchant="0x000000000000000000000000000000000000dEaD", item=9n, kind=0, window=20n, amount=25000000n;
async function main(){
  const buyer=w.address;
  console.log("1) issuer attests buyer KYC + sanctions…");
  await (await reg.attest(buyer,KYC,2000000000n)).wait(); await (await reg.attest(buyer,SANC,2000000000n)).wait();
  const ok=await reg.compliant(buyer,[KYC,SANC]);
  console.log("2) compliance gate: compliant(buyer) =",ok);
  if(!ok){console.log("   BLOCKED (non-compliant)"); return;}
  console.log("3) compliant → agent opens recourse-protected escrow…");
  const usd=new ethers.Contract(USDC,["function mint(address,uint256)","function approve(address,uint256) returns (bool)"],w);
  await (await usd.mint(buyer,amount)).wait(); await (await usd.approve(K,amount)).wait();
  const now=BigInt((await p.getBlock("latest")).timestamp);
  const binding=ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(["address","address","uint256","uint8","uint64"],[merchant,NFT,item,kind,window]));
  const m={nonce:ethers.hexlify(ethers.randomBytes(32)),signer:buyer,grantRef:Z,requirementRef:Z,recipient:K,token:USDC,amount,chainId:177n,deadline:now+window,settlementBinding:binding,requiredCapabilitiesHash:ethers.keccak256("0x")};
  const dom={name:"HSP",version:"1",chainId:177,verifyingContract:K}, id=ethers.TypedDataEncoder.hash(dom,TYPES,m), sig=await w.signTypedData(dom,TYPES,m);
  const k=new ethers.Contract(K,ABI,w);
  let tx=await k.open(Object.values(m),sig,merchant,NFT,item,kind,window); await tx.wait();
  console.log("   OPEN:",tx.hash);
  const escDl=(await k.payments(id))[7];
  console.log("4) seller silent → agent monitors & auto-reclaims…");
  while(BigInt((await p.getBlock("latest")).timestamp) < BigInt(escDl)){ await new Promise(r=>setTimeout(r,4000)); }
  tx=await k.refund(id); await tx.wait(); console.log("   REFUND:",tx.hash);
  tx=await k.withdraw(USDC); await tx.wait(); console.log("   WITHDRAW:",tx.hash);
  console.log("\n✅ COMPLIANT + REVERSIBLE + AGENT payment — full HashKey regulated-DeFi loop, live on mainnet.");
}
main().catch(e=>{console.error("ERR:",e.shortMessage||e.message);process.exit(1);});
