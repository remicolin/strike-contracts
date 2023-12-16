// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "../libraries/OptionPricingNonOwnable.sol";
import "../interfaces/IStrikePoolChainlink.sol";

contract StrikeOracle is ChainlinkClient, ConfirmedOwner, OptionPricingSimpleNonOwnable {
    using Chainlink for Chainlink.Request;

    uint256 public ORACLE_PAYMENT;

    uint256 public value;

    event RequestValue(bytes32 indexed requestId, uint256 indexed value);

    string constant jobId = "bf82c315fcb84cd2b8cb2ca1bf91b24c";

    uint256 public volatil = 10;
    uint256 public expiry =  14 days;
    mapping(bytes32 => uint256) public requestToPrice;
    mapping(bytes32 => address) public requestToPool;
    mapping(bytes32 => uint256) public requestToFloor;
    mapping(bytes32 => uint256) public requestToOptionPrice;

    string public url = "https://api.metaquants.xyz/v1/nft-pricing/0xed5af388653567af2f388e6224dc7c4b3241c544/8868";
    int256 public multiply = 1000000000000000000;
    string public path = "price_eth";
    constructor() OptionPricingSimpleNonOwnable(100, 1) ConfirmedOwner(msg.sender) {
        setChainlinkToken(0xd14838A68E8AFBAdE5efb411d5871ea0011AFd28);
        setChainlinkOracle(0xB7a5181B507B3c7A70Bb633E118cd0f3d919143a);
        setOraclePayment(((5 * LINK_DIVISIBILITY) / 100));
    }

    function requestOracle(address _erc721,uint256 _strikePrice
    ) external returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            stringToBytes32(jobId),
            address(this),
            this.fulfillValue.selector
        );
        req.add("get", url);
        req.add("path", path);
        req.addInt("multiply", multiply);
        requestId = sendChainlinkRequest(req, ORACLE_PAYMENT);
        requestToPool[requestId] = msg.sender;
        requestToPrice[requestId] = _strikePrice;
        return requestId;
    }

    function fulfillValue(
        bytes32 _requestId,
        uint256 _value
    ) public recordChainlinkFulfillment(_requestId) {
        require(msg.sender == chainlinkOracleAddress(), "Only oracle");
        requestToFloor[_requestId] = _value;
        emit RequestValue(_requestId, _value);
        value = _value;
        uint256 optionPrice = getOptionPrice(
            false,
            block.timestamp + expiry,
            requestToPrice[_requestId],
            _value,
            volatil
        );
        requestToOptionPrice[_requestId] = optionPrice;
        IStrikePoolChainlink(requestToPool[_requestId]).fullfillOracleRequest(
            _requestId,
            optionPrice
        );
    }

    function stringToBytes32(
        string memory source
    ) private pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            // solhint-disable-line no-inline-assembly
            result := mload(add(source, 32))
        }
    }

    function getOracleAddress() external view returns (address) {
        return chainlinkOracleAddress();
    }

    function setOracle(address _oracle) external onlyOwner {
        setChainlinkOracle(_oracle);
    }

    function setOraclePayment(uint256 _payment) public onlyOwner {
        ORACLE_PAYMENT = _payment;
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface linkToken = LinkTokenInterface(
            chainlinkTokenAddress()
        );
        require(
            linkToken.transfer(msg.sender, linkToken.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    // non native vol relative function
    function setMockVolatility(uint256 _volatility) public {
        volatil = _volatility;
    }
    function setMockOracleParams(string calldata _url, string calldata _path, int256 _multiply) public {
        url = _url;
        path = _path;
        multiply = _multiply;
    }

    //getters

    function  getRequestToFloor(bytes32 _requestId) public view returns (uint256) {
        return requestToFloor[_requestId];
    }
    function  getRequestToOptionPrice(bytes32 _requestId) public view returns (uint256) {
        return requestToOptionPrice[_requestId];
    }
    
}