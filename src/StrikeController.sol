// SPDX-License-Identifier: MIT
import "./interfaces/IStrikePool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

pragma solidity ^0.8.13;

contract StrikeController is Ownable, ProxyAdmin {
    address public erc20;
    mapping(address => TransparentUpgradeableProxy) public pools;
    address[] public erc721;
    event PoolDeployed(address erc721, address erc20, address pool);
    address auctionManager;
    address optionPricing;
    address volatilityOracle;
    address poolImplementation;

    constructor(address _erc20) {
        erc20 = _erc20;
    }
    
    function deployPoolChainlink(
        address _erc721
    ) public onlyOwner returns (address pool) {
        require(address(pools[_erc721]) == address(0));
        TransparentUpgradeableProxy strikePoolProxy = new TransparentUpgradeableProxy(
                poolImplementation,
                address(this),
                abi.encodeWithSignature(
                    "initialize(address,address,address,address,address)",
                    _erc721,
                    erc20,
                    auctionManager,
                    volatilityOracle,
                    msg.sender
                )
            );
        pools[_erc721] = strikePoolProxy;
        erc721.push(_erc721);
        emit PoolDeployed(_erc721, erc20, address(strikePoolProxy));
        return address(strikePoolProxy);
    }

    function upgradePool(
        address _pool,
        address _newPoolImplementation
    ) public onlyOwner {
        pools[_pool].upgradeTo(_newPoolImplementation);
    }


    function getPoolFromTokenAddress(
        address _tokenAddress
    ) public view returns (address) {
        return address(pools[_tokenAddress]);
    }

    function setAuctionManager(address _auctionManager) public onlyOwner {
        auctionManager = _auctionManager;
    }

    function getAuctionManager() public view returns (address) {
        return auctionManager;
    }

    /***    Option Pricing relatives functions     ***/
    function setOptionPricing(address _optionPricing) public onlyOwner {
        optionPricing = _optionPricing;
    }

    function getOptionPricing() public view returns (address) {
        return optionPricing;
    }

    function setOracle(address _volatilityOracle) public onlyOwner {
        volatilityOracle = _volatilityOracle;
    }

    function getVolatilityOracle() public view returns (address) {
        return volatilityOracle;
    }

    /*** Call PoolContract - setters functions  ***/
    function setPoolAuctionManager(
        address _pool,
        address _auctionManager
    ) public onlyOwner {
        IStrikePool(_pool).setAuctionManager(_auctionManager);
    }

    /*** Call PoolContract - getters functions  ***/

    function getFloorPrice(
        address _pool,
        uint256 _epoch
    ) public view returns (uint256) {
        return IStrikePool(_pool).getFloorPrice(_epoch);
    }

    function getEpoch_2e(address _pool) public view returns (uint256) {
        return IStrikePool(_pool).getEpoch_2e();
    }

    function getSharesAtOf(
        address _pool,
        uint256 _epoch,
        uint256 _strikePrice,
        address _add
    ) public view returns (uint256) {
        return IStrikePool(_pool).getSharesAtOf(_epoch, _strikePrice, _add);
    }

    function getAmountLockedAt(
        address _pool,
        uint256 _epoch,
        uint256 _strikePrice
    ) public view returns (uint256) {
        return IStrikePool(_pool).getAmountLockedAt(_epoch, _strikePrice);
    }

    function getOptionAvailableAt(
        address _pool,
        uint256 _epoch,
        uint256 _strikePrice
    ) public view returns (uint256) {
        return IStrikePool(_pool).getOptionAvailableAt(_epoch, _strikePrice);
    }

    function getEpochDuration(
        address _pool
    ) public view returns (uint256 epochduration) {
        return IStrikePool(_pool).getEpochDuration();
    }

    function getInterval(address _pool) public view returns (uint256 interval) {
        return IStrikePool(_pool).getInterval();
    }

    function setPoolImplementation(address _poolImplementation) public {
        poolImplementation = _poolImplementation;
    }
}
