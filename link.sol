// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface TARGET_CONTRACT {
    function callData(uint256 result) external returns (bool);
}

contract CHAINLINK {
    struct RequestBody {
        uint256 id;
        address requester;
        string url;
        uint256 Fee;
        uint256 Res;
    }

    event oracleRequestEvent(uint256 indexed requestID, string url, uint256 fee);
    event requestFulfulledEvent(uint256 indexed requestID, string result, uint256 nodeID);

    address[] public oracleAddressList;
    uint256 public totalRequestNum;

    mapping(address => uint256) public nodeStackBalance;
    mapping(uint256 => RequestBody) requestMap;

    constructor() {
        totalRequestNum = 0;
        oracleAddressList = new address[](0);
    }

    // 注册成为预言机节点
    function registerOracleNode() public returns (bool) {
        // 判断是否已经存在
        for (uint256 i = 0; i < oracleAddressList.length; i++) {
            if (oracleAddressList[i] == msg.sender) {
                return false;
            }
        }
        oracleAddressList.push(msg.sender);
        return true;
    }

    // 查询者查询函数
    function requestForMsg(string memory url, uint256 fee) public returns (bool) {
        if (oracleAddressList.length <= 1) {
            return false;
        }

        uint256 req_id = totalRequestNum++;

        requestMap[req_id] = RequestBody({
            id: req_id,
            requester: msg.sender,
            url: url,
            Fee: fee,
            Res: 0
        });
        emit oracleRequestEvent(req_id, url, fee);
        return true;
    }

    function fufillReqEvent(uint256 id, uint256 result) public returns (bool) {
        requestMap[id].Res = result;
        return true;
    }
}
