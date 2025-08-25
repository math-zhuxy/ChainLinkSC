// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract CHAINLINK {
    struct RequestBody {
        uint256 id;
        uint256 kind;
        uint256 Res;
    }

    event reqEvent(uint256 id, uint256 kind);

    address[] public oracleAddressList;
    uint256 public totalRequestNum;

    mapping(address => uint256) public nodeStackBalance;
    mapping(uint256 => RequestBody) public requestMap;

    constructor() {
        totalRequestNum = 0;
        oracleAddressList = new address[](0);
    }

    function registerOracleNode() public returns (bool) {
        for (uint256 i = 0; i < oracleAddressList.length; i++) {
            if (oracleAddressList[i] == msg.sender) {
                return false;
            }
        }
        oracleAddressList.push(msg.sender);
        return true;
    }

    function requestForMsg(uint256 kind) public returns (bool) {

        uint256 req_id = totalRequestNum++;

        requestMap[req_id] = RequestBody({
            id: req_id,
            kind: kind,
            Res: 0
        });
        emit reqEvent(req_id, kind);
        return true;
    }

    function fufillReq(uint256 id, uint256 result) public returns (bool) {
        requestMap[id].Res = result;
        return true;
    }

    function getResult(uint256 id) public  view returns (uint256) {
        return requestMap[id].Res;
    }
}
