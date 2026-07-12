// 🤖 Headless autonomous agent: runs a recourse-protected purchase on HashKey mainnet.
// The agent buys on-chain; if the seller doesn't deliver by the deadline, the agent
// autonomously reclaims its funds. Agent commerce that can't be rugged (AI x DeFi).
import { ethers } from "ethers";
const RPC="https://mainnet.hsk.xyz", K="0xDea6Da93265871d828B20cace2BADd5F5e70209d",
 USDC="0x481fE34ed995603abdB9998b7eCc8811e2707d87", NFT="0x6091e0111fB0F94fAE4b9D3Bbb0c36dD72D43454";
const p=new ethers.JsonRpcProvider(RPC,177);
const agent=new ethers.Wallet("0x4d98b2d5d5a8f95e58c30fbda021b6f0ec36ee4c1ffa1d0a5b93fa1b9b47cf8c",p);
const MT="(bytes32 nonce,address signer,bytes32 grantRef,bytes32 requirementRef,address recipient,address token,uint256 amount,uint256 chainId,uint256 deadline,bytes32 settlementBinding,bytes32 requiredCapabilitiesHash)";
const ABI=[`function open(${MT} m,bytes signature,address merchant,address asset,uint256 item,uint8 kind,uint64 window) returns (bytes32)`,"function refund(bytes32 id)","function withdraw(address token)","function payments(bytes32) view returns (address,address,address,uint256,address,uint256,uint8,uint64,uint8)"];
const TYPES={Mandate:[{name:"nonce",type:"bytes32"},{name:"signer",type:"address"},{name:"grantRef",type:"bytes32"},{name:"requirementRef",type:"bytes32"},{name:"recipient",type:"address"},{name:"token",type:"address"},{name:"amount",type:"uint256"},{name:"chainId",type:"uint256"},{name:"deadline",type:"uint256"},{name:"settlementBinding",type:"bytes32"},{name:"requiredCapabilitiesHash",type:"bytes32"}]};
const Z="0x"+"00".repeat(32), merchant="0x000000000000000000000000000000000000dEaD", item=7n, kind=0, window=20n, amount=50000000n;
async function main(){
  console.log("🤖 agent:",agent.address);
  const usd=new ethers.Contract(USDC,["function mint(address,uint256)","function approve(address,uint256) returns (bool)","function balanceOf(address) view returns (uint256)"],agent);
  const k=new ethers.Contract(K,ABI,agent);
  console.log("→ decision: buy (50 kUSD) with recourse. provisioning…");
  await (await usd.mint(agent.address,amount)).wait(); await (await usd.approve(K,amount)).wait();
  const bal0=await usd.balanceOf(agent.address);
  const now=BigInt((await p.getBlock("latest")).timestamp);
  const binding=ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(["address","address","uint256","uint8","uint64"],[merchant,NFT,item,kind,window]));
  const m={nonce:ethers.hexlify(ethers.randomBytes(32)),signer:agent.address,grantRef:Z,requirementRef:Z,recipient:K,token:USDC,amount,chainId:177n,deadline:now+window,settlementBinding:binding,requiredCapabilitiesHash:ethers.keccak256("0x")};
  const dom={name:"HSP",version:"1",chainId:177,verifyingContract:K}, id=ethers.TypedDataEncoder.hash(dom,TYPES,m), sig=await agent.signTypedData(dom,TYPES,m);
  let tx=await k.open(Object.values(m),sig,merchant,NFT,item,kind,window); await tx.wait();
  console.log("→ OPEN (autonomous):",tx.hash,"status",(await k.payments(id))[8],"(1=HELD)");
  const escDl=(await k.payments(id))[7]; console.log("→ monitoring delivery until on-chain deadline",escDl.toString());
  while(BigInt((await p.getBlock("latest")).timestamp) < BigInt(escDl)){ await new Promise(r=>setTimeout(r,4000)); }
  console.log("→ deadline passed, seller did not deliver → agent auto-reclaims");
  tx=await k.refund(id); await tx.wait(); console.log("→ REFUND:",tx.hash);
  tx=await k.withdraw(USDC); await tx.wait(); console.log("→ WITHDRAW:",tx.hash);
  console.log((await usd.balanceOf(agent.address))>=bal0?"✅ agent capital protected — reclaimed autonomously, no human, no arbiter":"?");
}
main().catch(e=>{console.error("ERR:",e.shortMessage||e.message);process.exit(1);});
