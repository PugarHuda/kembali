// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Minimal ERC-721-style demo deliverable (tokenized RWA / receipt NFT).
/// Enforces approval the way a real ERC-721 does: Kembali.fulfill() pulls the asset from the
/// merchant, so the merchant must approve Kembali first (approve or setApprovalForAll).
contract DemoNFT {
    string public name = "Kembali Demo RWA";
    string public symbol = "kRWA";
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    uint256 public nextId;

    function mint(address to) external returns (uint256 id) { id = ++nextId; ownerOf[id] = to; }
    function approve(address to, uint256 id) external { require(ownerOf[id] == msg.sender, "NOT_OWNER"); getApproved[id] = to; }
    function setApprovalForAll(address op, bool ok) external { isApprovedForAll[msg.sender][op] = ok; }

    function transferFrom(address from, address to, uint256 id) external {
        require(ownerOf[id] == from, "WRONG_FROM");
        require(
            msg.sender == from || getApproved[id] == msg.sender || isApprovedForAll[from][msg.sender],
            "NOT_AUTH"
        );
        ownerOf[id] = to;
        getApproved[id] = address(0);
    }
}
