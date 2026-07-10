// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Kembali — reversible stablecoin payments on HashKey Chain
/// @notice HSP settles payments finally. Kembali adds the missing recourse:
///         funds sit in escrow against an agreed ON-CHAIN deliverable + deadline.
///         Merchant delivers the exact asset before the deadline -> atomic DvP.
///         Merchant fails to deliver by the deadline -> payer reclaims funds. Money "kembali".
///
/// @dev id = HSP paymentId = EIP-712 mandate digest. open() verifies the payer's mandate
///      on-chain (EOA via ecrecover OR smart wallet / AI-agent via EIP-1271), so an agent or
///      relayer can SUBMIT a principal-signed mandate — funds are always pulled from the signer,
///      never the submitter. Terms are committed in `settlementBinding` (no front-running).
///      Payouts use pull-payments (withdraw) so one blacklisted party can't freeze the other.
///
/// ponytail: Public payments only (requiredCapabilitiesHash must be empty). Compliant payments
/// (KYC/sanctions attestations) need a trusted issuer/verifier — out of scope, see README.
/// Standing agent budgets (agent signs its own mandate under a principal grant) need the HSP
/// DelegationGrant verification path — also a documented extension.

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}
interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
}
interface IERC1271 {
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4);
}

contract Kembali {
    enum Status { NONE, HELD, RELEASED, REFUNDED }
    enum Kind   { ERC721, ERC20 }

    struct Payment {
        address payer;      // = mandate signer (principal); refunds/reclaim go here
        address merchant;
        address token;
        uint256 amount;
        address asset;
        uint256 item;       // ERC721: tokenId; ERC20: amount
        Kind    kind;
        uint64  deadline;   // escrow reclaim deadline
        Status  status;
    }

    // HSP wire v1 Mandate (docs/guide.md): domain {name:"HSP",version:"1"}, 11 fields.
    struct Mandate {
        bytes32 nonce;
        address signer;
        bytes32 grantRef;
        bytes32 requirementRef;
        address recipient;
        address token;
        uint256 amount;
        uint256 chainId;
        uint256 deadline;
        bytes32 settlementBinding;
        bytes32 requiredCapabilitiesHash;
    }

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant MANDATE_TYPEHASH = keccak256(
        "Mandate(bytes32 nonce,address signer,bytes32 grantRef,bytes32 requirementRef,address recipient,address token,uint256 amount,uint256 chainId,uint256 deadline,bytes32 settlementBinding,bytes32 requiredCapabilitiesHash)"
    );
    bytes32 private constant NAME_HASH = keccak256("HSP");
    bytes32 private constant VERSION_HASH = keccak256("1");
    bytes4  private constant EIP1271_MAGIC = 0x1626ba7e;
    bytes32 private constant EMPTY_CAPS = keccak256(""); // Public payment marker

    mapping(bytes32 => Payment) public payments;
    mapping(address => mapping(address => uint256)) public withdrawable; // user => token => amount (pull payments)
    mapping(address => mapping(bytes32 => bool)) public revoked;         // signer => nonce => revoked (I1)

    uint256 private _locked = 1;
    modifier lock() { require(_locked == 1, "REENTRANT"); _locked = 2; _; _locked = 1; }

    event Opened(bytes32 indexed id, address indexed payer, address indexed merchant, address token, uint256 amount, address asset, uint256 item, Kind kind, uint64 deadline);
    event Released(bytes32 indexed id, address indexed merchant);
    event Refunded(bytes32 indexed id, address indexed payer);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event Revoked(address indexed signer, bytes32 indexed nonce);

    /// @notice Cancel a signed-but-unopened mandate. A signed mandate is a bearer authorization
    ///         (anyone can submit it until its deadline); revoke it here if you change your mind.
    ///         ponytail: also keep mandate deadlines short and approve exact amounts, not infinite.
    function revoke(bytes32 nonce) external {
        revoked[msg.sender][nonce] = true;
        emit Revoked(msg.sender, nonce);
    }

    // ---- EIP-712 ----
    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_TYPEHASH, NAME_HASH, VERSION_HASH, block.chainid, address(this)));
    }
    function hashMandate(Mandate memory m) public view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(
            MANDATE_TYPEHASH, m.nonce, m.signer, m.grantRef, m.requirementRef,
            m.recipient, m.token, m.amount, m.chainId, m.deadline,
            m.settlementBinding, m.requiredCapabilitiesHash
        ));
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
    }

    /// @dev EOA (ecrecover) or smart-contract wallet / AI-agent wallet (EIP-1271).
    function _validSig(address signer, bytes32 digest, bytes calldata sig) internal view returns (bool) {
        if (signer.code.length > 0) {
            (bool ok, bytes memory ret) = signer.staticcall(
                abi.encodeWithSelector(IERC1271.isValidSignature.selector, digest, sig)
            );
            // forge-lint: disable-next-line(unsafe-typecast) — intentional: first 4 bytes = the EIP-1271 selector
            return ok && ret.length == 32 && bytes4(ret) == EIP1271_MAGIC;
        }
        return _recover(digest, sig) == signer;
    }

    function _recover(bytes32 digest, bytes calldata sig) internal pure returns (address) {
        require(sig.length == 65, "SIG_LEN");
        bytes32 r; bytes32 s; uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 0x20))
            v := byte(0, calldataload(add(sig.offset, 0x40)))
        }
        if (v < 27) v += 27;
        require(v == 27 || v == 28, "SIG_V");
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "SIG_S");
        address signer = ecrecover(digest, v, r, s);
        require(signer != address(0), "SIG_ZERO");
        return signer;
    }

    // ---- SafeERC20 (tolerate no-bool tokens like USDT) ----
    function _safeTransfer(address token, address to, uint256 amt) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amt));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAIL");
    }
    function _safeTransferFrom(address token, address from, address to, uint256 amt) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amt));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FROM_FAIL");
    }

    // ---- core ----

    /// @notice Open a reversible escrow from a signed HSP mandate. Callable by the signer OR by an
    ///         agent/relayer on the signer's behalf — funds are pulled from the signer either way.
    function open(
        Mandate calldata m,
        bytes calldata signature,
        address merchant,
        address asset,
        uint256 item,
        Kind    kind,
        uint64  window
    ) external lock returns (bytes32 id) {
        require(window > 0, "ZERO_WINDOW");                                  // H5
        require(m.recipient == address(this), "BAD_RECIPIENT");
        require(m.chainId == block.chainid, "BAD_CHAIN");
        // forge-lint: disable-next-line(block-timestamp) — deadlines are hour/day scale; sub-minute validator skew is irrelevant
        require(block.timestamp <= m.deadline, "MANDATE_EXPIRED");
        require(m.amount > 0, "ZERO_AMOUNT");
        require(m.requiredCapabilitiesHash == EMPTY_CAPS, "COMPLIANCE_UNSUPPORTED"); // H3 Public-only
        require(merchant != address(0) && m.token != address(0) && asset != address(0), "ZERO_ADDR"); // I2
        require(m.signer != merchant, "SELF_DEAL");                          // M1
        require(kind == Kind.ERC721 || item > 0, "ZERO_ITEM");               // N1: ERC20 must deliver > 0
        require(!revoked[m.signer][m.nonce], "REVOKED");                     // I1
        require(
            m.settlementBinding == keccak256(abi.encode(merchant, asset, item, kind, window)),
            "BAD_BINDING"
        );

        id = hashMandate(m);
        require(_validSig(m.signer, id, signature), "BAD_SIG");              // H2 EOA or EIP-1271
        require(payments[id].status == Status.NONE, "ID_EXISTS");

        uint64 reclaim = uint64(block.timestamp) + window;
        payments[id] = Payment({
            payer: m.signer, merchant: merchant, token: m.token, amount: m.amount,
            asset: asset, item: item, kind: kind, deadline: reclaim, status: Status.HELD
        });

        uint256 bal = IERC20(m.token).balanceOf(address(this));
        _safeTransferFrom(m.token, m.signer, address(this), m.amount);       // H2 pull from signer
        require(IERC20(m.token).balanceOf(address(this)) - bal == m.amount, "FEE_TOKEN"); // J4 no fee-on-transfer
        emit Opened(id, m.signer, merchant, m.token, m.amount, asset, item, kind, reclaim); // H6
    }

    /// @notice Merchant delivers the EXACT agreed deliverable BEFORE the deadline -> atomic DvP.
    function fulfill(bytes32 id) external lock {
        Payment storage p = payments[id];
        require(p.status == Status.HELD, "BAD_STATE");
        require(msg.sender == p.merchant, "ONLY_MERCHANT");
        // forge-lint: disable-next-line(block-timestamp) — day-scale window; sub-minute skew irrelevant
        require(block.timestamp < p.deadline, "WINDOW_CLOSED");              // H1

        p.status = Status.RELEASED;
        if (p.kind == Kind.ERC721) {
            IERC721(p.asset).transferFrom(p.merchant, p.payer, p.item);
        } else {
            uint256 bal = IERC20(p.asset).balanceOf(p.payer);
            _safeTransferFrom(p.asset, p.merchant, p.payer, p.item);
            require(IERC20(p.asset).balanceOf(p.payer) - bal == p.item, "FEE_TOKEN"); // J4 exact RWA delivery
        }
        withdrawable[p.merchant][p.token] += p.amount;                       // H4 credit, pull later
        emit Released(id, p.merchant);
    }

    /// @notice Payer reclaims funds after the deadline if the merchant never delivered.
    function refund(bytes32 id) external lock {
        Payment storage p = payments[id];
        require(p.status == Status.HELD, "BAD_STATE");
        require(msg.sender == p.payer, "ONLY_PAYER");
        // forge-lint: disable-next-line(block-timestamp) — day-scale window; sub-minute skew irrelevant
        require(block.timestamp >= p.deadline, "TOO_EARLY");

        p.status = Status.REFUNDED;
        withdrawable[p.payer][p.token] += p.amount;                          // H4
        emit Refunded(id, p.payer);
    }

    /// @notice Merchant bows out early -> payer refunded.
    function cancel(bytes32 id) external lock {
        Payment storage p = payments[id];
        require(p.status == Status.HELD, "BAD_STATE");
        require(msg.sender == p.merchant, "ONLY_MERCHANT");

        p.status = Status.REFUNDED;
        withdrawable[p.payer][p.token] += p.amount;                          // H4
        emit Refunded(id, p.payer);
    }

    /// @notice Pull your credited funds. Isolates blast radius: a blacklisted counterparty can't
    ///         freeze your payout — only their own.
    function withdraw(address token) external lock {
        uint256 amt = withdrawable[msg.sender][token];
        require(amt > 0, "NOTHING");
        withdrawable[msg.sender][token] = 0;
        _safeTransfer(token, msg.sender, amt);
        emit Withdrawn(msg.sender, token, amt);
    }
}
