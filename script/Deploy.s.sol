// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import { BaseScript } from "./Base.s.sol";
import { MintManager } from "../src/token/MintManager.sol";
import { SuperseedToken } from "../src/token/SuperseedToken.sol";
import { TokenClaim } from "../src/claim/TokenClaim.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    struct TokenAddr {
        address superAdmin;
        address minter;
        address tempTreasury;
    }

    struct ClaimAddr {
        address owner;
        address treasury;
    }

    struct Treasuries {
        address privateInvestors;
        address superSale;
        address ecosystemFund;
        address foundationTreasury;
        address networkParticipationRewards;
        address contributors;
    }

    struct TokenSupply {
        uint256 privateInvestors;
        uint256 superSale;
        uint256 bonusSuperSale;
        uint256 ecosystemFund;
        uint256 foundationTreasury;
        uint256 networkParticipationRewards;
        uint256 contributors;
    }

    TokenAddr public tokenAddr;
    ClaimAddr public claimAddr;
    Treasuries public treasuries;
    TokenSupply public tokenSupply;

    mapping(address => uint256) public treasuryBalances;

    // --- CONSTANTS ---
    bytes32 public constant CLAIM_MERKLE_ROOT = 0xcca3bb75653f49bf643e84f801ee49cbec017b2bcffe7fdd03b5625c1448e748;

    function setUp() public {
        // ==================== TREASURIES ====================
        treasuries = Treasuries(
            0x1E4E5e9D0Bb6E0F9F65e9dE460303D7CC8bF639f,
            0x8F522A44157aD7F7D522C48a7F67Dd2413fAbbc8,
            0xF9943Ac07C296fF3D6C90aB5866B151bb887D3bf,
            0xeFb651a2934C7Dd1EA398eb4cCa5e494f44ABcAa,
            0x0b750e026F4a04EF6cD334fC2669605b76e4B747,
            0xc8254f3e7fF702a3Df7d67B204b7f96Aa5E6818F
        );

        tokenAddr = TokenAddr(
            0x8A57e541757F20740FeB48AED8481E525c1034BC, address(0), 0x6418A646Ed5D55D41d9aD8d0B662bEb8db84e995
        );

        claimAddr = ClaimAddr(0x676E30CE725f7458CAFe0294f595862C40905929, treasuries.superSale);
        // ====================================================

        /*
        * ================== TOKEN SUPPLY ==================
        * Total Supply -> 10000000000000000000000000000
        * Source verification doc:
        * https://docs.google.com/spreadsheets/d/1iqJYA2QbasJXXXQWV_YgzNkkicckg5A4MMgIsVj54sE/edit?gid=0#gid=0
        * =================================================
        *
        * Private Investors -> 491000000000000000000000000
        * Supersale -> 478308223640000000000000000
        * Bonus Supersale -> 95661644728000000000000000
        * Ecosystem Fund -> 1800000000000000000000000000
        * Foundation Treasury -> 3435030131632000000000000000
        * Network participation rewards -> 1500000000000000000000000000
        * Contributors -> 2200000000000000000000000000
        */

        tokenSupply = TokenSupply(
            491_000_000_000_000_000_000_000_000,
            478_308_223_640_000_000_000_000_000,
            95_661_644_728_000_000_000_000_000,
            1_800_000_000_000_000_000_000_000_000,
            3_435_030_131_632_000_000_000_000_000,
            1_500_000_000_000_000_000_000_000_000,
            2_200_000_000_000_000_000_000_000_000
        );

        // 10000000000000000000000000000 => 10_000_000_000e18 => 10 Billion Tokens with 18 decimals
        assert(
            10_000_000_000e18
                == (
                    tokenSupply.privateInvestors + tokenSupply.superSale + tokenSupply.bonusSuperSale
                        + tokenSupply.ecosystemFund + tokenSupply.foundationTreasury + tokenSupply.networkParticipationRewards
                        + tokenSupply.contributors
                )
        );

        treasuryBalances[treasuries.privateInvestors] = tokenSupply.privateInvestors;
        treasuryBalances[treasuries.superSale] = tokenSupply.superSale + tokenSupply.bonusSuperSale;
        treasuryBalances[treasuries.ecosystemFund] = tokenSupply.ecosystemFund;
        treasuryBalances[treasuries.foundationTreasury] = tokenSupply.foundationTreasury;
        treasuryBalances[treasuries.networkParticipationRewards] = tokenSupply.networkParticipationRewards;
        treasuryBalances[treasuries.contributors] = tokenSupply.contributors;
    }

    function run() public broadcast returns (MintManager mintManager, SuperseedToken token, TokenClaim claim) {
        // Deploy MintManager
        mintManager = new MintManager();
        tokenAddr.minter = address(mintManager);

        // Deploy SuperseedToken
        token = new SuperseedToken(tokenAddr.superAdmin, tokenAddr.minter, tokenAddr.tempTreasury);

        // Split the initial token supply between the treasuries
        token.transfer(treasuries.privateInvestors, treasuryBalances[treasuries.privateInvestors]);
        token.transfer(treasuries.superSale, treasuryBalances[treasuries.superSale]);
        token.transfer(treasuries.ecosystemFund, treasuryBalances[treasuries.ecosystemFund]);
        token.transfer(treasuries.foundationTreasury, treasuryBalances[treasuries.foundationTreasury]);
        token.transfer(treasuries.networkParticipationRewards, treasuryBalances[treasuries.networkParticipationRewards]);
        token.transfer(treasuries.contributors, treasuryBalances[treasuries.contributors]);

        // Approve the TokenClaim contract to spend all tokens in TOKEN_CLAIM_TREASURY

        // Deploy TokenClaim
        claim = new TokenClaim(claimAddr.owner, address(token), claimAddr.treasury, CLAIM_MERKLE_ROOT);
    }
}
