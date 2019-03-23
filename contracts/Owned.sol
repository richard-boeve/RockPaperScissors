pragma solidity 0.5.6;

contract Owned {
    
    //State variable
    address private owner;
    
    //Constructor, setting the owner upon contract creation
    constructor() public {
        owner = msg.sender;
    }
    
    //Events
    event LogChangeOwner(address indexed oldOwner, address indexed newOwner); 
    
    //Modifiers
    modifier onlyOwner {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    //Function that queries the current owner
    function getOwner() public view returns(address) {
        return owner;
    }
    
    //Function that changes the owner
    function changeOwner(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "No address provided");
        require(_newOwner != owner, "Current owner can't be new owner");
        owner = _newOwner;
        emit LogChangeOwner(msg.sender, _newOwner);
    }
}