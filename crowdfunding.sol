//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract mtcToken {
    string public name = "Metacrafters";
    string public symbol = "mtc";
    uint8 public decimals = 18; // Number of coins to be created.
    uint public totalSupply = 1000000000 * (10 ** decimals);
    address owner;

    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event TransferByOwner(address indexed to, uint value);

    constructor(address _owner) {
        owner = _owner;
        balanceOf[_owner] = totalSupply;
    }

    function transfer(address to, uint value) public returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    function transferByOwner(uint value) internal {
        require(balanceOf[owner] >= value, "Insufficient balance");
        balanceOf[msg.sender] += value;
        balanceOf[owner] -= value;
        emit TransferByOwner(msg.sender, value);
    }

    function approve(address spender, uint value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) public returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Not authorized");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][owner] -= value;
        emit Transfer(from, to, value);
        return true;
    }
}


contract crowdFunding is mtcToken(msg.sender){
    uint public exchangeRate;
    enum timeline {started, goal_achieved, ended} // State of the contract.
    uint private projectCount;  // Keep track of number of projects.
    struct project{
        uint ID;
        string description;
        uint goal_amount;
        uint amount_received;
        timeline project_state;
        uint start_time;
        uint duration;
    }   //contains details of every project.
    mapping(uint=>project) projects;  // keep track of different projects.
    mapping(bytes32=>uint) donatorList;  // keep track of who donated how much. Byte32 not address because one user can donate in multiple project, and we need to distinguish each projects.
    receive() external payable{}

    event changedExchangeRate(uint newRate);
    constructor(){
        owner = msg.sender;
        projectCount = 0;
        exchangeRate = 1;
    }
    modifier onlyOwner{
        require(msg.sender == owner);
        _;
    }
    function setExchangeRate(uint _rate) public onlyOwner{
        require(_rate > 0, "Rate must be greater than 0.");
        exchangeRate = _rate;
        emit changedExchangeRate(exchangeRate);
    }
    function createProject(string memory _description, uint _goal_amount, uint _duration) public onlyOwner{
        projectCount++;
        project memory newproject = project({
            ID: projectCount,
            description: _description,
            goal_amount: _goal_amount,
            amount_received: 0,
            project_state: timeline.started,
            start_time: block.timestamp,
            duration: _duration
        });
        projects[projectCount] = newproject;        
    }
    function donate(uint _projectID) public payable{
        if(projects[_projectID].amount_received >= projects[_projectID].goal_amount){
            projects[_projectID].project_state = timeline.goal_achieved;
        }else if(block.timestamp >= projects[_projectID].start_time + projects[_projectID].duration){
            projects[_projectID].project_state = timeline.ended;
        }
        require(projects[_projectID].project_state == timeline.started, "Donation stopped.");
        (bool sent,) = address(this).call{value: msg.value}("");
        require(sent, "Transaction failed");
        projects[_projectID].amount_received += msg.value;
        donatorList[keccak256(abi.encode(msg.sender, _projectID))] = msg.value;
        mtcToken.transferByOwner(msg.value * exchangeRate);
        
    }
    function withdraw(uint _projectID) public{
        require(projects[_projectID].project_state == timeline.ended, "Project donation is still going on.");
        uint amount_deposited = donatorList[keccak256(abi.encode(msg.sender, _projectID))];
        require(amount_deposited > 0, "No amount is deposited with this address.");
        mtcToken.transfer(owner, amount_deposited * exchangeRate);  //Return the Tokens to owner        
        (bool sent,) = msg.sender.call{value: amount_deposited}("");
        require(sent, "Transaction failed!");
    }
}