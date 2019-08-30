pragma solidity ^0.5.8;

import  "./Owned.sol";

contract Stoppable is Owned {

    //State variable
    rockPapersScissorsState public state;

    //Defining the possible states of the contract
    enum rockPapersScissorsState {
        Operational,
        Paused,
        Deactivated
    }

    //Constructor, setting initial state upon contract creation
    constructor() public {
       state = rockPapersScissorsState.Operational;
    }

    //Event logs for when a state changes
    event LogSetState(address indexed sender, rockPapersScissorsState indexed newState);

    //Modifiers
    modifier onlyIfRunning {
        require(state == rockPapersScissorsState.Operational, "The contract is not operational");
        _;
    }

    modifier onlyIfNotPaused {
        require(state != rockPapersScissorsState.Paused, "The contract is paused and can't be interacted with");
        _;
    }

    //Function that allows owner to change the state of the contract
    function setState(rockPapersScissorsState newState) public onlyOwner {
        //Verify if the state is Deactivated, if so, don't allow update to the state;
        require(state != rockPapersScissorsState.Deactivated, "The contract is deactivated and can't be made operational or paused");
        //Set the state of the Contract
        state = newState;
        //Create logs
        emit LogSetState(msg.sender, newState);
    }
}