// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Kembali} from "../src/Kembali.sol";

// --- mocks ---
contract MockUSDC {
    uint8 public constant decimals = 6;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address to, uint256 a) public virtual returns (bool) { balanceOf[msg.sender] -= a; balanceOf[to] += a; return true; }
    function transferFrom(address f, address t, uint256 a) public returns (bool) { allowance[f][msg.sender] -= a; balanceOf[f] -= a; balanceOf[t] += a; return true; }
}
contract MockNFT {
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
contract NoReturnToken { // USDT-style
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function approve(address s, uint256 a) external { allowance[msg.sender][s] = a; }
    function transfer(address to, uint256 a) external { balanceOf[msg.sender] -= a; balanceOf[to] += a; }
    function transferFrom(address f, address t, uint256 a) external { allowance[f][msg.sender] -= a; balanceOf[f] -= a; balanceOf[t] += a; }
}
contract EvilUSDC is MockUSDC { // reenters withdraw()
    Kembali public k; bool public armed;
    function arm(Kembali _k) external { k = _k; armed = true; }
    function transfer(address to, uint256 a) public override returns (bool) {
        if (armed) { armed = false; try k.withdraw(address(this)) {} catch {} }
        return super.transfer(to, a);
    }
}
contract FeeToken { // 1% fee-on-transfer (J4)
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address to, uint256 a) external returns (bool) { uint256 f = a / 100; balanceOf[msg.sender] -= a; balanceOf[to] += a - f; return true; }
    function transferFrom(address fr, address t, uint256 a) external returns (bool) { allowance[fr][msg.sender] -= a; uint256 f = a / 100; balanceOf[fr] -= a; balanceOf[t] += a - f; return true; }
}
contract MockWallet { // EIP-1271 smart-contract wallet (stand-in for an AI-agent wallet)
    address public owner;
    constructor(address o) { owner = o; }
    function isValidSignature(bytes32 h, bytes calldata sig) external view returns (bytes4) {
        bytes32 r; bytes32 s; uint8 v;
        assembly { r := calldataload(sig.offset) s := calldataload(add(sig.offset, 0x20)) v := byte(0, calldataload(add(sig.offset, 0x40))) }
        if (v < 27) v += 27;
        return ecrecover(h, v, r, s) == owner ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
    function approveToken(address token, address spender, uint256 amt) external { MockUSDC(token).approve(spender, amt); }
}

// malicious ERC721-like deliverable that tries to reenter Kembali during delivery
contract EvilNFT {
    mapping(uint256 => address) public ownerOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    Kembali k; bytes32 target; bool armed;
    function mint(address to, uint256 id) external { ownerOf[id] = to; }
    function setApprovalForAll(address o, bool b) external { isApprovedForAll[msg.sender][o] = b; }
    function arm(Kembali _k, bytes32 _id) external { k = _k; target = _id; armed = true; }
    function transferFrom(address from, address to, uint256 id) external {
        require(ownerOf[id] == from, "NOT_OWNER");
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_AUTH");
        if (armed) { armed = false; try k.fulfill(target) {} catch {} try k.withdraw(address(this)) {} catch {} }
        ownerOf[id] = to;
    }
}

contract FalseToken { // transfers return false instead of reverting
    mapping(address => uint256) public balanceOf;
    function mint(address t, uint256 a) external { balanceOf[t] += a; }
    function approve(address, uint256) external returns (bool) { return true; }
    function transfer(address, uint256) external returns (bool) { return false; }
    function transferFrom(address, address, uint256) external returns (bool) { return false; }
}
contract LyingToken { // returns true but moves nothing (defeated by the balance assert)
    mapping(address => uint256) public balanceOf;
    function mint(address t, uint256 a) external { balanceOf[t] += a; }
    function approve(address, uint256) external returns (bool) { return true; }
    function transfer(address, uint256) external returns (bool) { return true; }
    function transferFrom(address, address, uint256) external returns (bool) { return true; }
}
contract BlacklistToken { // transfer to a blocked address reverts (USDC-style freeze)
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    address public blocked;
    function setBlocked(address b) external { blocked = b; }
    function mint(address t, uint256 a) external { balanceOf[t] += a; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address to, uint256 a) external returns (bool) { require(to != blocked, "BLOCKED"); balanceOf[msg.sender] -= a; balanceOf[to] += a; return true; }
    function transferFrom(address f, address t, uint256 a) external returns (bool) { allowance[f][msg.sender] -= a; balanceOf[f] -= a; balanceOf[t] += a; return true; }
}

contract RevertWallet { function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4) { revert("no"); } }
contract BytesWallet { function isValidSignature(bytes32, bytes calldata) external pure returns (bytes memory) { return hex"1626ba7e"; } } // wrong return length

contract KembaliTest is Test {
    Kembali k;
    MockUSDC usdc;
    MockNFT nft;

    uint256 constant PK = 0xA11CE;
    address payer;
    address merchant = address(0xB0B);
    uint256 constant AMT = 100_000000;
    uint256 constant TID = 7;
    uint64  constant WIN = 1 days;

    event Opened(bytes32 indexed id, address indexed payer, address indexed merchant, address token, uint256 amount, address asset, uint256 item, Kembali.Kind kind, uint64 deadline);
    event Released(bytes32 indexed id, address indexed merchant);
    event Refunded(bytes32 indexed id, address indexed payer);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event Revoked(address indexed signer, bytes32 indexed nonce);

    function setUp() public {
        k = new Kembali();
        usdc = new MockUSDC();
        nft = new MockNFT();
        payer = vm.addr(PK);
        usdc.mint(payer, AMT);
        nft.mint(merchant, TID);
        vm.prank(merchant);
        nft.setApprovalForAll(address(k), true);
    }

    function _build(
        bytes32 nonce, address signer, address token, uint256 amount,
        address merchant_, address asset, uint256 item, Kembali.Kind kind, uint64 window
    ) internal returns (Kembali.Mandate memory m, bytes32 id, bytes memory sig) {
        m = Kembali.Mandate({
            nonce: nonce, signer: signer, grantRef: bytes32(0), requirementRef: bytes32(0),
            recipient: address(k), token: token, amount: amount, chainId: block.chainid,
            deadline: block.timestamp + 1 days,
            settlementBinding: keccak256(abi.encode(merchant_, asset, item, kind, window)),
            requiredCapabilitiesHash: keccak256("")
        });
        id = k.hashMandate(m);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PK, id);
        sig = abi.encodePacked(r, s, v);
    }

    bytes32 ID;
    function _open() internal {
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256("n1"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        ID = id;
        vm.startPrank(payer);
        usdc.approve(address(k), AMT);
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.stopPrank();
    }

    // ---- H2: agent/relayer submission + EIP-1271 ----

    // a relayer/agent submits the payer's signed mandate; funds pulled from the SIGNER, not sender
    function test_Open_ByRelayer_PullsFromSigner() public {
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256("n1"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.prank(payer); usdc.approve(address(k), AMT);
        vm.prank(address(0xA9E27)); // some agent, not the signer
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        (address p,,,,,,,, Kembali.Status st) = k.payments(id);
        assertEq(p, payer, "payer = signer");
        assertEq(usdc.balanceOf(address(k)), AMT, "funds pulled from signer");
        assertEq(uint8(st), uint8(Kembali.Status.HELD));
    }

    // signer is a smart-contract wallet (AI-agent wallet) validating via EIP-1271
    function test_Open_EIP1271Wallet() public {
        MockWallet w = new MockWallet(payer);      // wallet owned by PK
        MockUSDC t = new MockUSDC();
        t.mint(address(w), AMT);
        w.approveToken(address(t), address(k), AMT);
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256("w1"), address(w), address(t), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.prank(address(0xBEEF)); // relayer
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        (address p,,,,,,,,) = k.payments(id);
        assertEq(p, address(w), "payer = wallet");
        assertEq(t.balanceOf(address(k)), AMT);
    }

    // ---- G1 residuals: binding / sig / expiry / dup / H5 window / H3 compliance ----

    function test_Open_RevertsTamperedTerms_BadBinding() public {
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("n1"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.prank(payer);
        vm.expectRevert("BAD_BINDING");
        k.open(m, sig, address(0xE711), address(nft), TID, Kembali.Kind.ERC721, WIN);
    }
    function test_Open_RevertsBadSignature() public {
        (Kembali.Mandate memory m,,) =
            _build(keccak256("n1"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        (, bytes32 r, bytes32 s) = vm.sign(uint256(0xBEEF), k.hashMandate(m));
        bytes memory bad = abi.encodePacked(r, s, uint8(27));
        vm.prank(payer); vm.expectRevert("BAD_SIG");
        k.open(m, bad, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
    }
    function test_Open_RevertsExpiredMandate() public {
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("n1"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.warp(m.deadline + 1);
        vm.prank(payer); vm.expectRevert("MANDATE_EXPIRED");
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
    }
    function test_Open_RevertsZeroWindow() public { // H5
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("zw"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, 0);
        vm.prank(payer); vm.expectRevert("ZERO_WINDOW");
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, 0);
    }
    function test_Open_RevertsCompliantMandate() public { // H3 Public-only
        Kembali.Mandate memory m = Kembali.Mandate({
            nonce: keccak256("c"), signer: payer, grantRef: bytes32(0), requirementRef: bytes32(0),
            recipient: address(k), token: address(usdc), amount: AMT, chainId: block.chainid,
            deadline: block.timestamp + 1 days,
            settlementBinding: keccak256(abi.encode(merchant, address(nft), TID, Kembali.Kind.ERC721, WIN)),
            requiredCapabilitiesHash: keccak256("kyc+sanctions") // non-empty => Compliant
        });
        bytes32 id = k.hashMandate(m);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PK, id);
        vm.prank(payer); vm.expectRevert("COMPLIANCE_UNSUPPORTED");
        k.open(m, abi.encodePacked(r, s, v), merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
    }
    function test_Open_RevertsAfterRevoke() public { // I1
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("n1"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.prank(payer); k.revoke(keccak256("n1"));
        vm.startPrank(payer); usdc.approve(address(k), AMT);
        vm.expectRevert("REVOKED");
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.stopPrank();
    }
    function test_Open_RevertsZeroAsset() public { // I2
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("za"), payer, address(usdc), AMT, merchant, address(0), TID, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); usdc.approve(address(k), AMT);
        vm.expectRevert("ZERO_ADDR");
        k.open(m, sig, merchant, address(0), TID, Kembali.Kind.ERC721, WIN);
        vm.stopPrank();
    }
    function test_Open_EIP1271_InvalidSigner() public { // I3
        MockWallet w = new MockWallet(address(0xDEAD)); // owner != PK
        MockUSDC t = new MockUSDC(); t.mint(address(w), AMT); w.approveToken(address(t), address(k), AMT);
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("w2"), address(w), address(t), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.prank(address(0xBEEF)); vm.expectRevert("BAD_SIG");
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
    }

    function test_Open_RevertsSelfDeal() public { // M1
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("sd"), payer, address(usdc), AMT, payer, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.prank(payer); vm.expectRevert("SELF_DEAL");
        k.open(m, sig, payer, address(nft), TID, Kembali.Kind.ERC721, WIN);
    }

    function test_Open_RevertsFeeToken() public { // J4
        FeeToken fee = new FeeToken(); fee.mint(payer, AMT);
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("fee"), payer, address(fee), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); fee.approve(address(k), AMT);
        vm.expectRevert("FEE_TOKEN");
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.stopPrank();
    }

    function test_Open_RevertsDuplicateId() public {
        _open();
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("n1"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); usdc.mint(payer, AMT); usdc.approve(address(k), AMT);
        vm.expectRevert("ID_EXISTS");
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.stopPrank();
    }

    // ---- happy paths + H4 pull payments ----

    function test_Fulfill_AtomicDvP_Withdraw() public {
        _open();
        vm.prank(merchant); k.fulfill(ID);
        assertEq(nft.ownerOf(TID), payer, "payer got asset");
        assertEq(k.withdrawable(merchant, address(usdc)), AMT, "merchant credited");
        vm.prank(merchant); k.withdraw(address(usdc));
        assertEq(usdc.balanceOf(merchant), AMT, "merchant withdrew");
        assertEq(usdc.balanceOf(address(k)), 0);
    }
    function test_Fulfill_RevertsAfterDeadline() public { // H1
        _open();
        vm.warp(block.timestamp + WIN);
        vm.prank(merchant); vm.expectRevert("WINDOW_CLOSED");
        k.fulfill(ID);
    }
    function test_Fulfill_ERC20Deliverable() public {
        MockUSDC gold = new MockUSDC(); uint256 rwa = 5_000000;
        gold.mint(merchant, rwa);
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256("rwa"), payer, address(usdc), AMT, merchant, address(gold), rwa, Kembali.Kind.ERC20, WIN);
        vm.startPrank(payer); usdc.mint(payer, AMT); usdc.approve(address(k), AMT);
        k.open(m, sig, merchant, address(gold), rwa, Kembali.Kind.ERC20, WIN); vm.stopPrank();
        vm.startPrank(merchant); gold.approve(address(k), rwa); k.fulfill(id); vm.stopPrank();
        assertEq(gold.balanceOf(payer), rwa, "payer got RWA");
        assertEq(k.withdrawable(merchant, address(usdc)), AMT);
    }
    function test_Fulfill_RevertsIfNotMerchant() public { _open(); vm.prank(payer); vm.expectRevert("ONLY_MERCHANT"); k.fulfill(ID); }
    function test_DoubleFulfill_Reverts() public { _open(); vm.prank(merchant); k.fulfill(ID); vm.prank(merchant); vm.expectRevert("BAD_STATE"); k.fulfill(ID); }
    function test_Fulfill_RevertsWrongOwner() public {
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256("wo"), payer, address(usdc), AMT, merchant, address(nft), 999, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); usdc.approve(address(k), AMT);
        k.open(m, sig, merchant, address(nft), 999, Kembali.Kind.ERC721, WIN); vm.stopPrank();
        vm.prank(merchant); vm.expectRevert("NOT_OWNER"); k.fulfill(id);
    }

    function test_Refund_AfterDeadline_Withdraw() public {
        _open();
        vm.warp(block.timestamp + WIN);
        vm.prank(payer); k.refund(ID);
        assertEq(k.withdrawable(payer, address(usdc)), AMT);
        vm.prank(payer); k.withdraw(address(usdc));
        assertEq(usdc.balanceOf(payer), AMT);
        assertEq(usdc.balanceOf(address(k)), 0);
    }
    function test_Refund_RevertsBeforeDeadline() public { _open(); vm.prank(payer); vm.expectRevert("TOO_EARLY"); k.refund(ID); }
    function test_Refund_RevertsIfDelivered() public { _open(); vm.prank(merchant); k.fulfill(ID); vm.warp(block.timestamp + WIN); vm.prank(payer); vm.expectRevert("BAD_STATE"); k.refund(ID); }
    function test_Refund_RevertsIfNotPayer() public { _open(); vm.warp(block.timestamp + WIN); vm.prank(merchant); vm.expectRevert("ONLY_PAYER"); k.refund(ID); }
    function test_Cancel_ByMerchant_Withdraw() public {
        _open();
        vm.prank(merchant); k.cancel(ID);
        vm.prank(payer); k.withdraw(address(usdc));
        assertEq(usdc.balanceOf(payer), AMT);
    }
    function test_Cancel_RevertsIfNotMerchant() public { _open(); vm.prank(payer); vm.expectRevert("ONLY_MERCHANT"); k.cancel(ID); }
    function test_Withdraw_RevertsIfNothing() public { vm.prank(payer); vm.expectRevert("NOTHING"); k.withdraw(address(usdc)); }

    // ---- L3: events (indexers depend on these) ----
    function test_Event_Opened() public {
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256("ev"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); usdc.approve(address(k), AMT);
        vm.expectEmit(true, true, true, false, address(k));
        emit Opened(id, payer, merchant, address(0), 0, address(0), 0, Kembali.Kind.ERC721, 0); // data unchecked
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.stopPrank();
    }
    function test_Event_Released() public {
        _open();
        vm.expectEmit(true, true, false, false, address(k));
        emit Released(ID, merchant);
        vm.prank(merchant); k.fulfill(ID);
    }
    function test_Event_Refunded() public {
        _open(); vm.warp(block.timestamp + WIN);
        vm.expectEmit(true, true, false, false, address(k));
        emit Refunded(ID, payer);
        vm.prank(payer); k.refund(ID);
    }
    function test_Event_Withdrawn() public {
        _open(); vm.warp(block.timestamp + WIN); vm.prank(payer); k.refund(ID);
        vm.expectEmit(true, true, true, true, address(k));
        emit Withdrawn(payer, address(usdc), AMT);
        vm.prank(payer); k.withdraw(address(usdc));
    }
    function test_Event_Revoked() public {
        vm.expectEmit(true, true, false, false, address(k));
        emit Revoked(payer, keccak256("x"));
        vm.prank(payer); k.revoke(keccak256("x"));
    }

    // ---- G2 SafeERC20 on withdraw path (no-return token) ----
    function test_SafeERC20_NoReturnToken() public {
        NoReturnToken usdt = new NoReturnToken();
        usdt.mint(payer, AMT);
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256("usdt"), payer, address(usdt), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); usdt.approve(address(k), AMT);
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN); vm.stopPrank();
        vm.warp(block.timestamp + WIN);
        vm.startPrank(payer); k.refund(id); k.withdraw(address(usdt)); vm.stopPrank();
        assertEq(usdt.balanceOf(payer), AMT);
    }

    // ---- H7 reentrancy on the money-out path (withdraw) ----
    function test_Reentrancy_NoDoubleDrain() public {
        EvilUSDC evil = new EvilUSDC();
        evil.mint(payer, AMT);
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256("evil"), payer, address(evil), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); evil.approve(address(k), AMT);
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN); vm.stopPrank();
        vm.warp(block.timestamp + WIN);
        vm.prank(payer); k.refund(id);
        evil.arm(k);
        vm.prank(payer); k.withdraw(address(evil));
        assertEq(evil.balanceOf(payer), AMT, "single withdraw only");
        assertEq(evil.balanceOf(address(k)), 0);
    }

    // ============ edge cases (various) ============

    function test_Case_MinAmount() public { // amount = 1 wei of token
        usdc.mint(payer, 1);
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256("min"), payer, address(usdc), 1, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); usdc.approve(address(k), 1);
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN); vm.stopPrank();
        vm.prank(merchant); k.fulfill(id);
        assertEq(k.withdrawable(merchant, address(usdc)), 1);
    }

    function test_Case_MinWindow_FulfillWorks() public { // window = 1s, still fulfillable same block
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256("w1"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, 1);
        vm.startPrank(payer); usdc.approve(address(k), AMT);
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, 1); vm.stopPrank();
        vm.prank(merchant); k.fulfill(id);
        assertEq(nft.ownerOf(TID), payer);
    }

    function test_Case_WindowOverflow_Reverts() public { // uint64(now) + max overflows -> checked revert
        uint64 huge = type(uint64).max;
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("ovf"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, huge);
        vm.startPrank(payer); usdc.approve(address(k), AMT);
        vm.expectRevert(); // arithmetic overflow
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, huge);
        vm.stopPrank();
    }

    function test_Case_ERC20_ZeroItem_Rejected() public { // N1: pay-for-nothing footgun blocked
        MockUSDC gold = new MockUSDC();
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("z0"), payer, address(usdc), AMT, merchant, address(gold), 0, Kembali.Kind.ERC20, WIN);
        vm.startPrank(payer); usdc.approve(address(k), AMT);
        vm.expectRevert("ZERO_ITEM");
        k.open(m, sig, merchant, address(gold), 0, Kembali.Kind.ERC20, WIN);
        vm.stopPrank();
    }

    function test_Case_ERC721_ZeroTokenId_Allowed() public { // tokenId 0 is a valid NFT
        nft.mint(merchant, 0);
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256("t0"), payer, address(usdc), AMT, merchant, address(nft), 0, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); usdc.approve(address(k), AMT);
        k.open(m, sig, merchant, address(nft), 0, Kembali.Kind.ERC721, WIN); vm.stopPrank();
        vm.prank(merchant); k.fulfill(id);
        assertEq(nft.ownerOf(0), payer);
    }

    function test_Case_DeadlineBoundary() public { // at t==deadline: fulfill reverts, refund ok (no overlap)
        _open();
        (,,,,,,, uint64 dl,) = k.payments(ID);
        vm.warp(dl); // exactly the deadline
        vm.prank(merchant); vm.expectRevert("WINDOW_CLOSED"); k.fulfill(ID);
        vm.prank(payer); k.refund(ID); // >= deadline
        assertEq(k.withdrawable(payer, address(usdc)), AMT);
    }

    function test_Case_AccumulateWithdraw() public { // two refunds -> single withdraw gets the sum
        _open();
        nft.mint(merchant, 8);
        (Kembali.Mandate memory m2, bytes32 id2, bytes memory sig2) =
            _build(keccak256("n2"), payer, address(usdc), AMT, merchant, address(nft), 8, Kembali.Kind.ERC721, WIN);
        usdc.mint(payer, AMT);
        vm.startPrank(payer); usdc.approve(address(k), AMT);
        k.open(m2, sig2, merchant, address(nft), 8, Kembali.Kind.ERC721, WIN); vm.stopPrank();
        vm.warp(block.timestamp + WIN);
        vm.startPrank(payer); k.refund(ID); k.refund(id2); vm.stopPrank();
        assertEq(k.withdrawable(payer, address(usdc)), 2 * AMT);
        vm.prank(payer); k.withdraw(address(usdc));
        assertEq(usdc.balanceOf(payer), 2 * AMT);
    }

    function test_Case_RevokeBlocksReusedNonce() public { // revoke keys on nonce -> blocks any mandate with it
        bytes32 nonce = keccak256("shared");
        (Kembali.Mandate memory m1,, bytes memory s1) =
            _build(nonce, payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.prank(payer); k.revoke(nonce);
        vm.startPrank(payer); usdc.approve(address(k), AMT);
        vm.expectRevert("REVOKED");
        k.open(m1, s1, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.stopPrank();
    }

    function test_Case_UnapprovedNFT_FulfillReverts() public { // merchant revokes NFT approval -> fulfill fails, refund saves payer
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256("na"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); usdc.approve(address(k), AMT);
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN); vm.stopPrank();
        vm.prank(merchant); nft.setApprovalForAll(address(k), false); // merchant pulls approval
        vm.prank(merchant); vm.expectRevert("NOT_AUTH"); k.fulfill(id);
        vm.warp(block.timestamp + WIN);
        vm.prank(payer); k.refund(id); // payer still protected
        assertEq(k.withdrawable(payer, address(usdc)), AMT);
    }

    function testFuzz_OpenFulfill_AnyValues(uint96 amt, uint64 win, uint256 tid) public {
        amt = uint96(bound(uint256(amt), 1, 1e30));
        win = uint64(bound(uint256(win), 1, 3650 days));
        MockUSDC u = new MockUSDC(); MockNFT n = new MockNFT();
        u.mint(payer, amt); n.mint(merchant, tid);
        vm.prank(merchant); n.setApprovalForAll(address(k), true);
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256(abi.encode(amt, win, tid)), payer, address(u), amt, merchant, address(n), tid, Kembali.Kind.ERC721, win);
        vm.startPrank(payer); u.approve(address(k), amt);
        k.open(m, sig, merchant, address(n), tid, Kembali.Kind.ERC721, win); vm.stopPrank();
        vm.prank(merchant); k.fulfill(id);
        assertEq(n.ownerOf(tid), payer);
        assertEq(k.withdrawable(merchant, address(u)), amt);
    }

    // ============ edge cases round 2 (sig / 1271 / multi-token) ============
    uint256 constant SECP_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    function test_Case_MultiTokenWithdraw() public { // two escrows in different pay tokens
        MockUSDC usdc2 = new MockUSDC(); usdc2.mint(payer, AMT);
        _open(); // escrow 1 in usdc
        nft.mint(merchant, 8);
        (Kembali.Mandate memory m2, bytes32 id2, bytes memory sig2) =
            _build(keccak256("mt2"), payer, address(usdc2), AMT, merchant, address(nft), 8, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); usdc2.approve(address(k), AMT);
        k.open(m2, sig2, merchant, address(nft), 8, Kembali.Kind.ERC721, WIN); vm.stopPrank();
        vm.startPrank(merchant); k.fulfill(ID); k.fulfill(id2); vm.stopPrank();
        assertEq(k.withdrawable(merchant, address(usdc)), AMT);
        assertEq(k.withdrawable(merchant, address(usdc2)), AMT);
        vm.startPrank(merchant); k.withdraw(address(usdc)); k.withdraw(address(usdc2)); vm.stopPrank();
        assertEq(usdc.balanceOf(merchant), AMT);
        assertEq(usdc2.balanceOf(merchant), AMT);
    }

    function test_Case_EIP1271_RevertingWallet() public { // wallet reverts in isValidSignature -> BAD_SIG
        RevertWallet w = new RevertWallet();
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("rw"), address(w), address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.expectRevert("BAD_SIG");
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
    }

    function test_Case_EIP1271_MalformedReturn() public { // wallet returns non-32-byte data -> BAD_SIG
        BytesWallet w = new BytesWallet();
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("bw"), address(w), address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.expectRevert("BAD_SIG");
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
    }

    function test_Case_Sig_LowV_Normalized() public { // v in {0,1} must be accepted (normalized to 27/28)
        (Kembali.Mandate memory m, bytes32 id,) =
            _build(keccak256("lv"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PK, id);
        bytes memory lowV = abi.encodePacked(r, s, uint8(v - 27)); // 0 or 1
        vm.startPrank(payer); usdc.approve(address(k), AMT);
        k.open(m, lowV, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN); vm.stopPrank();
        (,,,,,,,, Kembali.Status st) = k.payments(id);
        assertEq(uint8(st), uint8(Kembali.Status.HELD));
    }

    function test_Case_Sig_HighS_Rejected() public { // malleated high-s signature -> SIG_S
        (Kembali.Mandate memory m, bytes32 id,) =
            _build(keccak256("hs"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PK, id);
        bytes32 sHigh = bytes32(SECP_N - uint256(s));
        uint8 vFlip = v == 27 ? 28 : 27;
        bytes memory mall = abi.encodePacked(r, sHigh, vFlip); // valid recovery, but high-s
        vm.prank(payer); vm.expectRevert("SIG_S");
        k.open(m, mall, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
    }

    function test_Case_Sig_WrongLength() public { // 64-byte sig -> SIG_LEN
        (Kembali.Mandate memory m, bytes32 id,) =
            _build(keccak256("wl"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        (, bytes32 r, bytes32 s) = vm.sign(PK, id);
        bytes memory short = abi.encodePacked(r, s); // 64 bytes, no v
        vm.prank(payer); vm.expectRevert("SIG_LEN");
        k.open(m, short, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
    }

    function test_Case_Sig_ZeroR_Rejected() public { // r=0 -> ecrecover returns address(0) -> SIG_ZERO
        (Kembali.Mandate memory m, bytes32 id,) =
            _build(keccak256("zr"), payer, address(usdc), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        (uint8 v,, bytes32 s) = vm.sign(PK, id);
        bytes memory badR = abi.encodePacked(bytes32(0), s, v); // r = 0
        vm.prank(payer); vm.expectRevert("SIG_ZERO");
        k.open(m, badR, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
    }

    function test_Case_ZeroAmount_Rejected() public {
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("za2"), payer, address(usdc), 0, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.prank(payer); vm.expectRevert("ZERO_AMOUNT");
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
    }

    function test_Case_BadRecipient_Rejected() public { // mandate.recipient != Kembali
        Kembali.Mandate memory m = Kembali.Mandate({
            nonce: keccak256("br"), signer: payer, grantRef: bytes32(0), requirementRef: bytes32(0),
            recipient: address(0xDEAD), token: address(usdc), amount: AMT, chainId: block.chainid,
            deadline: block.timestamp + 1 days,
            settlementBinding: keccak256(abi.encode(merchant, address(nft), TID, Kembali.Kind.ERC721, WIN)),
            requiredCapabilitiesHash: keccak256("")
        });
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PK, k.hashMandate(m));
        vm.prank(payer); vm.expectRevert("BAD_RECIPIENT");
        k.open(m, abi.encodePacked(r, s, v), merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
    }

    // malicious deliverable asset cannot reenter fulfill/withdraw to double-spend
    function test_Case_Reentrancy_ViaDeliverableAsset() public {
        EvilNFT evil = new EvilNFT();
        evil.mint(merchant, TID);
        vm.prank(merchant); evil.setApprovalForAll(address(k), true);
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256("evilnft"), payer, address(usdc), AMT, merchant, address(evil), TID, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); usdc.approve(address(k), AMT);
        k.open(m, sig, merchant, address(evil), TID, Kembali.Kind.ERC721, WIN); vm.stopPrank();
        evil.arm(k, id);
        vm.prank(merchant); k.fulfill(id);
        // exactly one settlement despite the reentry attempts
        assertEq(evil.ownerOf(TID), payer, "delivered once");
        assertEq(k.withdrawable(merchant, address(usdc)), AMT, "single credit, no double-spend");
        (,,,,,,,, Kembali.Status st) = k.payments(id);
        assertEq(uint8(st), uint8(Kembali.Status.RELEASED));
    }

    function test_Case_FalseToken_OpenReverts() public { // transferFrom returns false -> caught
        FalseToken ft = new FalseToken(); ft.mint(payer, AMT);
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("ft"), payer, address(ft), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); ft.approve(address(k), AMT);
        vm.expectRevert("TRANSFER_FROM_FAIL");
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.stopPrank();
    }

    function test_Case_LyingToken_OpenReverts() public { // returns true but moves nothing -> balance assert catches it
        LyingToken lt = new LyingToken(); lt.mint(payer, AMT);
        (Kembali.Mandate memory m,, bytes memory sig) =
            _build(keccak256("lt"), payer, address(lt), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); lt.approve(address(k), AMT);
        vm.expectRevert("FEE_TOKEN"); // delta 0 != amount
        k.open(m, sig, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        vm.stopPrank();
    }

    // H4 isolation: a blacklisted merchant can't freeze an unrelated payer's refund
    function test_Case_Blacklist_IsolatesBlastRadius() public {
        BlacklistToken bt = new BlacklistToken();
        bt.mint(payer, 2 * AMT);
        nft.mint(merchant, 8);
        // escrow A: will be fulfilled -> merchant credited
        (Kembali.Mandate memory mA, bytes32 idA, bytes memory sA) =
            _build(keccak256("bkA"), payer, address(bt), AMT, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        // escrow B: will be refunded -> payer credited
        (Kembali.Mandate memory mB, bytes32 idB, bytes memory sB) =
            _build(keccak256("bkB"), payer, address(bt), AMT, merchant, address(nft), 8, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer);
        bt.approve(address(k), 2 * AMT);
        k.open(mA, sA, merchant, address(nft), TID, Kembali.Kind.ERC721, WIN);
        k.open(mB, sB, merchant, address(nft), 8, Kembali.Kind.ERC721, WIN);
        vm.stopPrank();
        vm.prank(merchant); k.fulfill(idA);       // merchant credited
        vm.warp(block.timestamp + WIN);
        vm.prank(payer); k.refund(idB);            // payer credited

        bt.setBlocked(merchant);                   // merchant gets frozen by the token issuer
        vm.prank(merchant); vm.expectRevert("TRANSFER_FAIL"); k.withdraw(address(bt)); // merchant's own payout stuck (BLOCKED wrapped by SafeERC20)
        vm.prank(payer); k.withdraw(address(bt));   // payer UNAFFECTED
        assertEq(bt.balanceOf(payer), AMT, "payer withdrew despite merchant being blacklisted");
    }

    // ---- conservation ----
    function testFuzz_Conservation(uint96 amt) public {
        vm.assume(amt > 0);
        MockUSDC u = new MockUSDC(); MockNFT n = new MockNFT();
        u.mint(payer, amt); n.mint(merchant, 1);
        vm.prank(merchant); n.setApprovalForAll(address(k), true);
        (Kembali.Mandate memory m, bytes32 id, bytes memory sig) =
            _build(keccak256(abi.encode(amt)), payer, address(u), amt, merchant, address(n), 1, Kembali.Kind.ERC721, WIN);
        vm.startPrank(payer); u.approve(address(k), amt);
        k.open(m, sig, merchant, address(n), 1, Kembali.Kind.ERC721, WIN); vm.stopPrank();
        vm.prank(merchant); k.fulfill(id);
        // funds still in escrow, credited to merchant (pull); conservation holds
        assertEq(u.balanceOf(payer) + u.balanceOf(merchant) + u.balanceOf(address(k)), amt);
        assertEq(u.balanceOf(address(k)), amt);
        assertEq(n.ownerOf(1), payer);
        vm.prank(merchant); k.withdraw(address(u));
        assertEq(u.balanceOf(merchant), amt);
        assertEq(u.balanceOf(address(k)), 0);
    }
}
