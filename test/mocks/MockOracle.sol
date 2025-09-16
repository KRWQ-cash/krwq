// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

import {AggregatorV3Interface} from "../../src/interfaces/AggregatorV3Interface.sol";

contract MockOracle is AggregatorV3Interface {
    uint8 private _decimals;
    string private _description;
    uint256 private _version;

    int256 public answer;
    uint256 public updatedAt;
    uint80 public roundId;

    constructor(uint8 decimals_, string memory description_, uint256 version_) {
        _decimals = decimals_;
        _description = description_;
        _version = version_;
        roundId = 1;
        updatedAt = block.timestamp;
    }

    function setAnswer(int256 _answer) external {
        answer = _answer;
        updatedAt = block.timestamp;
        roundId += 1;
    }

    function setStale(uint256 newUpdatedAt) external {
        updatedAt = newUpdatedAt;
        roundId += 1;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external view returns (string memory) {
        return _description;
    }

    function version() external view returns (uint256) {
        return _version;
    }

    function getRoundData(uint80 _roundId) external view returns (uint80, int256, uint256, uint256, uint80) {
        return (_roundId, answer, updatedAt, updatedAt, _roundId);
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, answer, updatedAt, updatedAt, roundId);
    }
}
