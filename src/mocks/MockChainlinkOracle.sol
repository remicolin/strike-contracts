// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

//import backscholes contract
import "../libraries/OptionPricing.sol";
import "../interfaces/IStrikePoolChainlink.sol";

contract MockChainlinkOracle is OptionPricingSimple {
    uint256 public volatility = 10;
    uint256 public floorPrice = 2 ether;
    uint256 public requestCount = 0;
    mapping(bytes32 => uint256) public requestToPrice;
    mapping(bytes32 => address) public requestToPool;

    constructor(uint256 _volatility) OptionPricingSimple(100, 1) {
        volatility = _volatility;
    }

    function setVolatility(uint256 _volatility) external {
        volatility = _volatility;
    }

    function getVolatility(address _erc721) external view returns (uint256) {
        return volatility;
    }

    function setFloorPrice(uint256 _floorPrice) external {
        floorPrice = _floorPrice;
    }

    function getFloorPrice(address _erc721) external view returns (uint256) {
        return floorPrice;
    }

    function requestOracle(
        address erc721,uint256 strikePrice
    ) external returns (bytes32) {
        requestCount++;
        bytes32 requestId = bytes32(requestCount);
        requestToPrice[requestId] = strikePrice;
        requestToPool[requestId] = msg.sender;
        return (requestId);
    }

    function executeOracle(bytes32 requestId) external {
        uint256 strikePrice = requestToPrice[requestId];
        address pool = requestToPool[requestId];
        uint256 premium = getOptionPrice(
            true,
            strikePrice,
            block.timestamp + 14 days,
            floorPrice,
            volatility
        );
        IStrikePoolChainlink(pool).fullfillOracleRequest(requestId, premium);

    }
}
