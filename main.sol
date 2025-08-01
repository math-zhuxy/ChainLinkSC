// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface TARGET_CONTRACT {
    function callData(uint256 result) external returns (bool);
}

contract CHAINLINK {
    enum jobType {
        finance,
        weather,
        api_call
    }
    struct RequestBody {
        uint256 id;
        address requester;
        jobType job_type;
        string url;
        address[] oracles_list;
        uint256 Fee;
        uint256[] searchRes;
        address[] oracleNodes;
        uint256 givenNum;
    }

    event oracleRequestEvent(uint256 indexed requestID, address[] node_list, jobType job_type, string url, uint256 fee);
    event requestFulfulledEvent(uint256 indexed requestID, string result, uint256 nodeID);

    mapping(address => jobType[]) public oracleNodeJobType;

    address[] public oracleAddressList;
    uint256 public totalRequestNum;

    mapping(address => uint256) public nodeStackBalance;
    mapping(uint256 => RequestBody) requestList;

    uint256 public constant LIMIT_STAKE_NUM = 80;
    uint256 public constant MAX_SEARCH_NUM = 10;
    uint256 public constant LIMIT_FEE_PRICE = 10;
    uint256 public constant DEDUCE_PRICE = 40;

    constructor() {
        totalRequestNum = 0;
        oracleAddressList = new address[](0);
    }

    // 注册成为预言机节点
    function registerOracleNode(jobType[] memory job_type_list) public returns (bool) {
        // To do: 判断节点是否余额足够，扣除余额
        // require(nodeStackBalance[msg.sender] >= LIMIT_STAKE_NUM, "not enough money");
        nodeStackBalance[msg.sender] = LIMIT_STAKE_NUM;
        oracleNodeJobType[msg.sender] = job_type_list;
        oracleAddressList.push(msg.sender);
        return (true);
    }

    function calculateReqNode(jobType job_type) private view returns (address[] memory) {
        uint256 num_count = 0;
        for (uint256 i = 0; i < oracleAddressList.length; i++) {
            address oracle_addr = oracleAddressList[i];
            jobType[] memory job_type_list = oracleNodeJobType[oracle_addr];
            for (uint256 j = 0; j < job_type_list.length; j++) {
                if (job_type_list[j] == job_type) {
                    num_count++;
                    break;
                }
            }
        }

        address[] memory node_addr_list = new address[](num_count);
        uint256 index = 0;

        for (uint256 i = 0; i < oracleAddressList.length; i++) {
            address oracle_addr = oracleAddressList[i];
            jobType[] memory job_type_list = oracleNodeJobType[oracle_addr];
            bool isJob = false;
            for (uint256 j = 0; j < job_type_list.length; j++) {
                if (job_type_list[j] == job_type) {
                    isJob = true;
                    break;
                }
            }
            if (isJob) {
                node_addr_list[index] = oracle_addr;
                index++;
            }
        }

        return node_addr_list;
    }

    // 查询者查询函数
    function requestForMsg(
        string memory url,
        jobType jobtype,
        uint256 fee
    ) public returns (bool) {
        require(fee >= LIMIT_FEE_PRICE && fee % MAX_SEARCH_NUM == 0, "too less fee");
        require(nodeStackBalance[msg.sender] >= fee, "not enough money");
        address[] memory node_lists = calculateReqNode(jobtype);
        uint256 req_id = totalRequestNum++;

        requestList[req_id] = RequestBody({
            id: req_id,
            requester: msg.sender,
            job_type: jobtype,
            url: url,
            oracles_list: node_lists,
            Fee: fee,
            searchRes: new uint256[](node_lists.length),
            oracleNodes: new address[](node_lists.length),
            givenNum: 0
        });
        emit oracleRequestEvent(req_id, node_lists, jobtype, url, fee);
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
        for (uint256 i = 0; i < num; i++) {
            if (requestList[id].oracleNodes[i] == addr) {
                return true;
            }
        }
        return false;
    }

    // 删除oracle list中的一个元素
    function removeItem(uint256 index) private returns (bool) {
        require(index < oracleAddressList.length, "index out of bounds");
        oracleAddressList[index] = oracleAddressList[oracleAddressList.length - 1];
        oracleAddressList.pop();
        return true;
    }

    // 判断节点结果是否正确
    function evaluateNodePerf(
        uint256 id,
        uint256 final_result,
        uint256 std_num
    ) private returns (bool) {
        for (uint256 i = 0; i < MAX_SEARCH_NUM; i++) {
            uint256 node_res = requestList[id].searchRes[i];
            if (final_result - std_num >= node_res || final_result + std_num <= node_res) {
                // 扣除代币
                nodeStackBalance[requestList[id].oracles_list[i]] -= DEDUCE_PRICE;
            }
            // 移除节点
            if (nodeStackBalance[requestList[id].oracles_list[i]] <= 0) {
                address node_name = requestList[id].oracles_list[i];
                for (uint256 j = 0; j < oracleAddressList.length; j++) {
                    if (oracleAddressList[j] == node_name) {
                        removeItem(j);
                        break;
                    }
                }
            }
        }
        return true;
    }

    // 预言机节点查询传入的函数
    function fufillReqEvent(uint256 id, uint256 result) public returns (bool) {
        if (isInReqList(id, msg.sender)) {
            return false;
        }
        uint256 num = requestList[id].givenNum;
        requestList[id].searchRes[num] = result;
        requestList[id].oracleNodes[num] = msg.sender;
        requestList[id].givenNum++;

        // 如果预言机返回的数量足够，结算余额和最终结果
        if (requestList[id].givenNum == MAX_SEARCH_NUM) {
            uint256 final_result = 0;
            uint256 std_num = 0;
            for (uint256 i = 0; i < requestList[id].givenNum; i++) {
                nodeStackBalance[requestList[id].oracleNodes[i]] += requestList[i].Fee / MAX_SEARCH_NUM;
                final_result += requestList[id].searchRes[i];
                std_num += requestList[id].searchRes[i]**2;
            }
            TARGET_CONTRACT TargetContract = TARGET_CONTRACT(requestList[id].requester);

            evaluateNodePerf(id, final_result, std_num);

            final_result = final_result / MAX_SEARCH_NUM;

            std_num -= final_result * final_result;
            std_num = std_num / MAX_SEARCH_NUM;

            // 调用查询者合约函数，将结果传入
            TargetContract.callData(final_result);
        }
        return true;
    }
}
