// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Kembali} from "../src/Kembali.sol";

// minimal mocks (inlined; test-only)
contract IMockUSDC {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address to, uint256 a) external returns (bool) { balanceOf[msg.sender] -= a; balanceOf[to] += a; return true; }
    function transferFrom(address f, address t, uint256 a) external returns (bool) { allowance[f][msg.sender] -= a; balanceOf[f] -= a; balanceOf[t] += a; return true; }
}
contract IMockNFT {
    mapping(uint256 => address) public ownerOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    function mint(address to, uint256 id) external { ownerOf[id] = to; }
    function setApprovalForAll(address op, bool ok) external { isApprovedForAll[msg.sender][op] = ok; }
    function transferFrom(address from, address to, uint256 id) external {
        require(ownerOf[id] == from, "NOT_OWNER");
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTH");
        ownerOf[id] = to;
    }
}

/// Drives random open/fulfill/refund/withdraw sequences and tracks ghost accounting.
contract Handler is Test {
    Kembali public k;
    IMockUSDC public token;
    IMockNFT public nft;
    uint256 constant PK = 0xA11CE;
    address public payer;
    address public constant MERCHANT = address(0xB0B);
    uint64 constant WIN = 1 days;

    bytes32[] public ids;
    mapping(bytes32 => uint256) public amtOf;
    mapping(bytes32 => bool) public held;
    uint256 public ghostHeld;   // sum of amounts still HELD (funds owed but not yet credited)
    uint256 private nonceCtr;
    uint256 private tid;

    constructor(Kembali _k, IMockUSDC _t, IMockNFT _n) {
        k = _k; token = _t; nft = _n; payer = vm.addr(PK);
        vm.prank(MERCHANT); nft.setApprovalForAll(address(k), true);
    }

    function open(uint96 a) external {
        uint256 amt = bound(uint256(a), 1, 1e12);
        token.mint(payer, amt);
        uint256 myTid = ++tid; nft.mint(MERCHANT, myTid);
        bytes32 nonce = keccak256(abi.encode(++nonceCtr));
        Kembali.Mandate memory m = Kembali.Mandate({
            nonce: nonce, signer: payer, grantRef: bytes32(0), requirementRef: bytes32(0),
            recipient: address(k), token: address(token), amount: amt, chainId: block.chainid,
            deadline: block.timestamp + 3650 days,
            settlementBinding: keccak256(abi.encode(MERCHANT, address(nft), myTid, Kembali.Kind.ERC721, WIN)),
            requiredCapabilitiesHash: keccak256("")
        });
        bytes32 id = k.hashMandate(m);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PK, id);
        vm.startPrank(payer);
        token.approve(address(k), amt);
        k.open(m, abi.encodePacked(r, s, v), MERCHANT, address(nft), myTid, Kembali.Kind.ERC721, WIN);
        vm.stopPrank();
        ids.push(id); amtOf[id] = amt; held[id] = true; ghostHeld += amt;
    }

    function fulfill(uint256 seed) external {
        if (ids.length == 0) return;
        bytes32 id = ids[seed % ids.length];
        if (!held[id]) return;
        vm.prank(MERCHANT); k.fulfill(id); // reverts (window closed) => whole call reverts, ghost untouched
        held[id] = false; ghostHeld -= amtOf[id];
    }

    function refund(uint256 seed) external {
        if (ids.length == 0) return;
        bytes32 id = ids[seed % ids.length];
        if (!held[id]) return;
        vm.warp(block.timestamp + WIN + 1);
        vm.prank(payer); k.refund(id);
        held[id] = false; ghostHeld -= amtOf[id];
    }

    function cancel(uint256 seed) external {
        if (ids.length == 0) return;
        bytes32 id = ids[seed % ids.length];
        if (!held[id]) return;
        vm.prank(MERCHANT); k.cancel(id); // merchant bows out -> payer credited
        held[id] = false; ghostHeld -= amtOf[id];
    }

    function withdrawMerchant() external { vm.prank(MERCHANT); try k.withdraw(address(token)) {} catch {} }
    function withdrawPayer() external { vm.prank(payer); try k.withdraw(address(token)) {} catch {} }
}

contract InvariantKembali is Test {
    Kembali k;
    IMockUSDC token;
    IMockNFT nft;
    Handler h;

    function setUp() public {
        k = new Kembali();
        token = new IMockUSDC();
        nft = new IMockNFT();
        h = new Handler(k, token, nft);
        targetContract(address(h));
    }

    /// Contract's token balance == funds still held + funds credited-but-unwithdrawn. Always.
    function invariant_accounting() public view {
        uint256 credited = k.withdrawable(h.payer(), address(token)) + k.withdrawable(address(0xB0B), address(token));
        assertEq(token.balanceOf(address(k)), h.ghostHeld() + credited);
    }
}
