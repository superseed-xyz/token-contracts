// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/src/Test.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { SuperseedToken } from "../src/token/SuperseedToken.sol";
import { TokenClaim } from "../src/claim/TokenClaim.sol";

contract TokenClaimTest is Test {
    TokenClaim public tokenClaim;
    SuperseedToken public superseedToken;

    string public constant TOKEN_NAME = "Superseed";
    string public constant TOKEN_SYMBOL = "SUPR";

    address public initialOwner = makeAddr("Initial Owner");
    address public alice = makeAddr("Alice");
    address public bob = makeAddr("Bob");
    address public charlie = makeAddr("Charlie");
    address public defaultAdmin = makeAddr("Admin");
    address public minter = makeAddr("Minter");
    address public treasury = makeAddr("Treasury");

    uint256 public amountAlice = 112_751e18;
    uint256 public amountBob = 3_567_135e18;
    uint256 public amountCharlie = 1_120_909e18;

    bytes32 public merkleRoot;
    bytes32[] public proofAlice;
    bytes32[] public proofBob;

    function setUp() public {
        // Prepare merkle tree
        merkleRoot = 0x10c9473b3e65b8a2bcbed2a47203744bc7099e609a9eee68a6037e0cee6b221c;

        // Deploy contracts
        superseedToken = new SuperseedToken(TOKEN_NAME, TOKEN_SYMBOL, defaultAdmin, minter, treasury);
        tokenClaim = new TokenClaim(initialOwner, address(superseedToken), treasury, merkleRoot);

        // 0 -> Alice
        proofAlice.push(0xcea4170b255563d3af595d2dcc2b83b7a44b74f66767f6e2d7b739db64a66068);
        // 1 -> Bob
        proofBob.push(0xd86d36bd89afed8f7e28a043ed51af118e3ef1147dbe684c90f51ae68910f00d);

        vm.prank(initialOwner);
        tokenClaim.setMerkleRoot(merkleRoot);

        // Mint tokens to treasury
        vm.prank(minter);
        superseedToken.mint(treasury, amountAlice + amountBob);

        // Set allowance for tokenClaim
        vm.prank(treasury);
        superseedToken.approve(address(tokenClaim), amountAlice + amountBob);
    }

    function test1_setMerkleRoot() public view {
        assertEq(tokenClaim.merkleRoot(), merkleRoot);
    }

    function test2_claimTokens() public {
        vm.prank(alice);
        tokenClaim.claim(amountAlice, proofAlice);
        assertEq(superseedToken.balanceOf(alice), amountAlice);

        vm.roll(3);

        assert(tokenClaim.hasClaimed(alice));
        vm.prank(alice);
        vm.expectRevert(TokenClaim.AlreadyClaimed.selector);

        tokenClaim.claim(amountAlice, proofAlice);
    }

    function test4_claimTokens_InvalidMerkleProof() public {
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = keccak256(abi.encode(alice, amountAlice + 1));

        vm.prank(alice);
        vm.expectRevert(TokenClaim.InvalidMerkleProof.selector);
        tokenClaim.claim(amountAlice, invalidProof);
    }

    function test5_claimTokens_InvalidInput() public {
        uint256 amount = 0;

        vm.prank(alice);
        vm.expectRevert(TokenClaim.AmountIsZero.selector);
        tokenClaim.claim(amount, proofAlice);
    }

    function test6_withdraw_OnlyOwner() public {
        uint256 amount = 3_561_723e18;

        vm.prank(minter);
        superseedToken.mint(address(charlie), amount);
        vm.prank(charlie);
        superseedToken.transfer(address(tokenClaim), amount);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        tokenClaim.withdraw(treasury, superseedToken);
    }

    function test7_withdraw() public {
        uint256 amount = 3_561_723e18;
        uint256 currentTreasuryBalance = superseedToken.balanceOf(treasury);

        vm.prank(minter);
        superseedToken.mint(address(charlie), amount);
        vm.prank(charlie);
        superseedToken.transfer(address(tokenClaim), amount);

        vm.prank(initialOwner);
        tokenClaim.withdraw(treasury, superseedToken);
        assertEq(superseedToken.balanceOf(treasury), currentTreasuryBalance + amount);
    }

    function testFuzz_withdraw(uint208 amount) public {
        uint256 preTotalSupply = superseedToken.totalSupply();
        vm.assume(amount > 0);
        vm.assume(amount < type(uint208).max - preTotalSupply);

        uint256 preBalance = superseedToken.balanceOf(treasury);

        vm.prank(minter);
        superseedToken.mint(address(tokenClaim), amount);

        vm.prank(initialOwner);
        tokenClaim.withdraw(treasury, superseedToken);
        assertEq(superseedToken.balanceOf(treasury), preBalance + amount);
    }
}
