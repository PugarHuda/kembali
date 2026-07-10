// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Kembali} from "../src/Kembali.sol";
import {DemoUSDC} from "../src/mocks/DemoUSDC.sol";
import {DemoNFT} from "../src/mocks/DemoNFT.sol";

/// Deploy Kembali + demo deliverables to HashKey Chain mainnet (177), seeded for a 2-account demo.
///   PAYER=0x<payer> forge script script/Deploy.s.sol --rpc-url hashkey --broadcast --verify
/// Needs env PRIVATE_KEY (funded with HSK for gas). PAYER = a SECOND wallet (the buyer).
///
/// Roles after deploy:
///   - deployer  = MERCHANT: owns demo NFT #1 and has pre-approved Kembali to deliver it.
///   - PAYER     = BUYER: seeded with 1000 kUSD to pay with.
/// (Escrow forbids payer == merchant, so the demo uses two accounts.)
contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(pk);
        address payer = vm.envOr("PAYER", me); // buyer account; defaults to deployer (mint kUSD there).
        // Note: the escrow forbids payer == merchant at open() time — for the live 2-account demo,
        // mint kUSD to your second wallet via DemoUSDC.mint (it is public).

        vm.startBroadcast(pk);
        Kembali k = new Kembali();
        DemoUSDC usd = new DemoUSDC();
        DemoNFT nft = new DemoNFT();

        usd.mint(payer, 1_000_000000);           // buyer gets 1000 kUSD
        uint256 demoId = nft.mint(me);           // deployer (merchant) owns the deliverable
        nft.setApprovalForAll(address(k), true); // merchant pre-approves Kembali to pull it
        vm.stopBroadcast();

        console.log("Kembali  :", address(k));
        console.log("DemoUSDC :", address(usd));
        console.log("DemoNFT  :", address(nft));
        console.log("merchant :", me);
        console.log("payer    :", payer);
        console.log("demo NFT id (merchant owns):", demoId);
    }
}
