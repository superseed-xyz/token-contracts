// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28 <0.9.0;

import { console } from "forge-std/src/Script.sol";

import { BaseDeployerScript } from "./BaseDeployer.s.sol";
import { SuperseedToken } from "../src/token/SuperseedToken.sol";
import { TokenClaim } from "../src/claim/TokenClaim.sol";
import { ERC20Mock } from "../src/supersale/mocks/ERC20Mock.sol";
import { SuperSaleDeposit } from "../src/supersale/SuperSaleDeposit.sol";
import { IERC20 } from "../src/supersale/dependencies/openzeppelin/token/ERC20/IERC20.sol";

contract DeployStaging is BaseDeployerScript {
    struct TokenParams {
        address superAdmin;
        address minter;
        address tempTreasury;
    }

    struct ClaimParams {
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

    struct TokenSupplyDistribution {
        uint256 privateInvestors;
        uint256 superSale;
        uint256 bonusSuperSale;
        uint256 ecosystemFund;
        uint256 foundationTreasury;
        uint256 networkParticipationRewards;
        uint256 contributors;
    }

    struct AccountFileItemWithProof {
        address purchaseAddress;
        bytes32[] proof;
        uint256 privateKey;
    }

    TokenParams public tokenParams;
    ClaimParams public claimParams;
    Treasuries public treasuries;
    TokenSupplyDistribution public tokenSupply;
    ERC20Mock public usdc;
    ERC20Mock public usdt;
    SuperSaleDeposit public ssd;

    mapping(address => uint256) public treasuryBalances;

    // ================== CONSTANTS ==================
    // Token Constants
    string public constant TOKEN_NAME = "SSTestToken";
    string public constant TOKEN_SYMBOL = "SST2";
    address public admin = 0xFf23CF95Cec5339d4bc3EA9fad4c5eEb585ae2e4;
    uint256 public adminPrivateKey = vm.envUint("PRIVATE_KEY_STAGING");
    uint256 public constant MIN_DEPOSIT = 250e6;
    uint256 public constant MAX_DEPOSIT = 20_000_000e6;

    // Claim Constants
    bytes32 public constant CLAIM_MERKLE_ROOT = 0x0dd2dd8116b44e0e2011caeef2f55f49049b65d0ee42b0f1822d25a8ebbe27e2;
    bytes32 public constant DEPOSIT_MERKLE_ROOT = 0xf5ad00285c2699e22454e4f95e21c094fa12640b3778577bddc35f4759d8c9e4;

    constructor() BaseDeployerScript(Environment.Staging) { }

    function run() public broadcast returns (SuperseedToken token, TokenClaim claim) {
        vm.stopBroadcast();
        vm.selectFork(vm.createFork(vm.rpcUrl("sepolia")));
        vm.startBroadcast(privateKey);

        // ==================== TREASURIES ====================
        treasuries = Treasuries(
            0xe928FFfd98eD3347A0d3a2245b928cFa733C99f2,
            admin,
            0xa0673CaC20C7F7f5FD6065BF523ECefA281c0FFc,
            0xc9aD5763255a99631a1c3D7a37E197192e6d3Af3,
            0x4D8f821F8Cd4C963704eA6e8687852D15792459D,
            0xBB0599B3DBe99a43e9646636DE165be06440412f
        );

        tokenSupply = TokenSupplyDistribution(
            491_000_000_000_000_000_000_000_000,
            478_308_223_640_000_000_000_000_000,
            95_661_644_728_000_000_000_000_000,
            1_800_000_000_000_000_000_000_000_000,
            3_435_030_131_632_000_000_000_000_000,
            1_500_000_000_000_000_000_000_000_000,
            2_200_000_000_000_000_000_000_000_000
        );

        tokenParams = TokenParams(admin, address(0), broadcaster);

        claimParams = ClaimParams(admin, treasuries.superSale);

        // ==================== ERC20 Mocks ====================
        usdc = new ERC20Mock("USD Circle", "USDC", 6);
        console.log("USDC address: %s", address(usdc));
        usdt = new ERC20Mock("USD Tether", "USDT", 6);
        console.log("USDT address: %s", address(usdt));

        // ==================== Supersale Deposit ====================
        ssd = new SuperSaleDeposit(
            admin, admin, admin, admin, IERC20(address(usdc)), IERC20(address(usdt)), DEPOSIT_MERKLE_ROOT
        );
        console.log("SuperSaleDeposit address: %s", address(ssd));

        ssd.setSaleSchedule(block.timestamp - 2 days, block.timestamp - 1 days, block.timestamp + 30 days);
        ssd.setSaleParameters(MIN_DEPOSIT, MAX_DEPOSIT);
        ssd.unpause();

        // ==================== Read Accounts from file ====================
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script/accounts.json");

        string memory json = vm.readFile(path);
        address[] memory addresses = abi.decode(vm.parseJson(json), (address[]));
        uint256 itemCount = addresses.length; // Number of items in the JSON array

        AccountFileItemWithProof[] memory accountFileItems = new AccountFileItemWithProof[](itemCount);

        for (uint256 i = 0; i < accountFileItems.length; i++) {
            for (uint256 j = 0; j < itemCount; j++) {
                string memory basePath = string.concat("[", vm.toString(i), "]");
                string memory addressPath = string.concat(basePath, ".purchaseAddress");
                string memory proofPath = string.concat(basePath, ".proof");
                string memory keyPath = string.concat(basePath, ".privateKey");

                address purchaseAddress = abi.decode(vm.parseJson(json, addressPath), (address));
                bytes32[] memory proof = vm.parseJsonBytes32Array(json, proofPath);
                uint256 userPrivateKey = vm.parseJsonUint(json, keyPath);

                accountFileItems[i] = AccountFileItemWithProof({
                    privateKey: userPrivateKey,
                    proof: proof,
                    purchaseAddress: purchaseAddress
                });
            }
        }

        // ==================== Mint tokens to accounts ====================
        for (uint256 i = 0; i < accountFileItems.length; i++) {
            usdc.mint(accountFileItems[i].purchaseAddress, MAX_DEPOSIT);
        }
        vm.stopBroadcast();

        // ==================== Deposit from user accounts ====================
        for (uint256 i = 0; i < accountFileItems.length; i++) {
            // User approve spending of tokens by SD
            vm.startBroadcast(accountFileItems[i].privateKey);
            // @TODO Send ETH to this addresses
            usdc.approve(address(ssd), type(uint256).max);
            ssd.depositUSDC(MIN_DEPOSIT, accountFileItems[i].proof);
            vm.stopBroadcast();
        }

        vm.selectFork(vm.createFork(vm.rpcUrl("superseed_sepolia")));

        vm.startBroadcast(privateKey);

        // Deploy MintManager
        // @TODO - use MintManager when ready, for now rollback to admin address
        // mintManager = new MintManager();
        // tokenParams.minter = address(mintManager);
        tokenParams.minter = admin;

        // Deploy SuperseedToken
        token = new SuperseedToken(
            TOKEN_NAME, TOKEN_SYMBOL, tokenParams.superAdmin, tokenParams.minter, tokenParams.tempTreasury
        );

        // Deploy TokenClaim
        claim = new TokenClaim(claimParams.owner, address(token), claimParams.treasury, CLAIM_MERKLE_ROOT);

        // Mint and approve
        token.mint(treasuries.superSale, tokenSupply.superSale);
        token.approve(address(claim), type(uint256).max);
    }
}
