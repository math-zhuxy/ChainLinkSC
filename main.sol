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
        uint256[] searchRes;
        address[] resOracleNodes;
        uint256 givenNum;
    }

    event oracleRequestEvent(uint256 indexed requestID, string url, uint256 fee);
    event requestFulfulledEvent(uint256 indexed requestID, string result, uint256 nodeID);

    address[] public oracleAddressList;
    uint256 public totalRequestNum;

    mapping(address => uint256) public nodeStackBalance;
    mapping(uint256 => RequestBody) requestList;

    uint256 public constant LIMIT_STAKE_NUM = 80;
    uint256 public constant LIMIT_FEE_PRICE = 10;
    uint256 public constant DEDUCE_PRICE = 40;

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
        nodeStackBalance[msg.sender] = LIMIT_STAKE_NUM;
        oracleAddressList.push(msg.sender);
        return true;
    }

    // 查询者查询函数
    function requestForMsg(string memory url, uint256 fee) public returns (bool) {
        require(fee >= LIMIT_FEE_PRICE, "too less fee");
        if (oracleAddressList.length <= 1) {
            return false;
        }

        uint256 req_id = totalRequestNum++;

        requestList[req_id] = RequestBody({
            id: req_id,
            requester: msg.sender,
            url: url,
            Fee: fee,
            searchRes: new uint256[](oracleAddressList.length),
            resOracleNodes: new address[](oracleAddressList.length),
            givenNum: 0
        });
        emit oracleRequestEvent(req_id, url, fee);
        return true;
    }

    // 判断是否已在查询列表中，防止预言机节点多次返回结果
    function isInReqList(uint256 id, address addr) private view returns (bool) {
        if (requestList[id].id == 0) {
            return false;
        }
        uint256 num = requestList[id].givenNum;
        if (num == 0) {
            return false;
        }
        for (uint256 index = 0; index < num; index++) {
            if (requestList[id].resOracleNodes[index] == addr) {
                return true;
            }
        }
        return false;
    }

    // 删除oracle list中的一个元素
    function removeItem(address node_name) private returns (bool) {
        for (uint256 i = 0; i < oracleAddressList.length; i++) {
            if (oracleAddressList[i] == node_name) {
                oracleAddressList[i] = oracleAddressList[oracleAddressList.length - 1];
                oracleAddressList.pop();
                break;
            }
        }
        return true;
    }

    // 判断节点结果是否正确
    function evaluateNodePerf(
        uint256 id,
        uint256 final_result,
        uint256 square_sum
    ) private returns (bool) {
        uint256 std_num = square_sum / requestList[id].givenNum - final_result * final_result;
        for (uint256 index = 0; index < requestList[id].givenNum; index++) {
            address node_name = requestList[id].resOracleNodes[index];
            uint256 node_res = requestList[id].searchRes[index];
            if (final_result + std_num <= node_res || final_result - std_num >= node_res) {
                // 扣除代币
                nodeStackBalance[node_name] -= DEDUCE_PRICE;
            }
            // 移除节点
            if (nodeStackBalance[node_name] <= 0) {
                removeItem(node_name);
            }
        }
        return true;
    }

    // 预言机节点查询传入的函数
    function fufillReqEvent(uint256 id, uint256 result) public returns (uint256, bool) {
        if (isInReqList(id, msg.sender)) {
            return (0, false);
        }
        uint256 num = requestList[id].givenNum;
        requestList[id].searchRes[num] = result;
        requestList[id].resOracleNodes[num] = msg.sender;
        requestList[id].givenNum++;

        // 如果预言机返回的数量足够，结算余额和最终结果
        if (requestList[id].givenNum * 3 >= 2 * oracleAddressList.length) {
            uint256 final_result = 0;
            uint256 square_sum = 0;
            for (uint256 index = 0; index < requestList[id].givenNum; index++) {
                address node_name = requestList[id].resOracleNodes[index];
                nodeStackBalance[node_name] += requestList[index].Fee / requestList[id].givenNum;
                final_result += requestList[id].searchRes[index];
                square_sum += requestList[id].searchRes[index]**2;
            }
            TARGET_CONTRACT TargetContract = TARGET_CONTRACT(requestList[id].requester);
            final_result = final_result / requestList[id].givenNum;

            // 评估节点信息
            evaluateNodePerf(id, final_result, square_sum);

            // 调用查询者合约函数，将结果传入
            TargetContract.callData(final_result);
            return (final_result, true);
        }
        return (0, false);
    }
}
