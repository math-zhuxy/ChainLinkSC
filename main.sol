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

    mapping(address => uint256) public userBalances;
    mapping(uint256 => RequestBody) requestList;

    uint256 public constant LIMIT_STAKE_NUM = 80;
    uint256 public constant MAX_SEARCH_NUM = 10;
    uint256 public constant LIMIT_FEE_PRICE = 10;

    constructor() {
        totalRequestNum = 0;
        oracleAddressList = new address[](0);
    }

    // 注册成为预言机节点
    function registerOracleNode(jobType[] memory job_type_list) public returns (bool) {
        require(userBalances[msg.sender] >= LIMIT_STAKE_NUM, "not enough money");
        userBalances[msg.sender] -= LIMIT_STAKE_NUM;
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
        require(userBalances[msg.sender] >= fee, "not enough money");
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
            for (uint256 i = 0; i < requestList[id].givenNum; i++) {
                userBalances[requestList[id].oracleNodes[i]] += requestList[i].Fee / MAX_SEARCH_NUM;
                final_result += requestList[id].searchRes[i];
            }
            TARGET_CONTRACT TargetContract = TARGET_CONTRACT(requestList[id].requester);

            // 调用查询者合约函数，将结果传入
            TargetContract.callData(final_result / MAX_SEARCH_NUM);
        }
        return true;
    }
}
