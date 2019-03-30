pragma solidity 0.5.6;

import "./Stoppable.sol";
import "./SafeMath.sol";

//@author  Richard Boeve
//@title  Rock Paper Scissors game
contract RockPaperScissors is Stoppable {

    //@notice  Using the SafeMath library
    using SafeMath for uint256;
    
    //@notice  State variables
    uint256 constant gameExpiry = 1 minutes;
    
    //@notice  Defining the move possibilities
    enum Moves { 
        Undefined,
        Rock, 
        Paper, 
        Scissors 
    }

    //@notice  Defining the possible game outcomes
    enum Result {
        msgSenderWins,
        opponentWins,
        Draw
    }

    //@notice  Struct that contains the details of players moves
    struct Plays {
        address opponent;
        uint256 wager;
        bytes32 hashedMove;
        Moves move;
        uint256 timestampSubmit;
        uint256 timestampReveal;
    }
    
    //@notice  Mapping that stores players moves
    mapping(bytes32 => Plays) public plays;

    //@notice  Mapping that stores winnings 
    mapping(address => uint256) public balance;
    
    //@notice  Mapping that stores submitted moves hashes 
    mapping(bytes32 => bool) public submits;

    //@notice  All events resulting from the contracts functions
    event LogDeposit(address indexed sender, uint256 depositAmount);
    event LogSubmittedMove(address indexed sender, address indexed opponent, uint256 wager);
    event LogPlayedGame (address indexed sender, address indexed opponent, Result result, uint256 wager);
    event LogRescindedMove(address indexed sender, address indexed opponent, uint256 wager);
    event LogWithdrawBalance(address indexed sender, uint256 withdrawAmount);
    
    
    //@notice  Function that allows players to deposit to their balance
    function deposit() public onlyIfRunning payable {
        //@dev  Verify that the funds sent are a positive value
        require(msg.value > 0, "A positive value needs to be deposited");
        //@dev  Store the funds against the users balance
        balance[msg.sender] = balance[msg.sender].add(msg.value);
        //@dev  Create logs
        emit LogDeposit (msg.sender, msg.value);
    }    
    
     //@notice  Function that allows a move to be submitted
    function submitMove(address _opponentAddress, bytes32 _hashedMove, uint256 _wager) public onlyIfRunning payable {
        //@dev  Create a unique hash to store the move
        bytes32 storeMove = keccak256(abi.encodePacked(msg.sender, _opponentAddress));
        //@dev  Calculate the hash your opponent has stored his move against (or where he/she will store move)
        bytes32 storeMoveOpponent = keccak256(abi.encodePacked(_opponentAddress, msg.sender));
        //@dev  Verify that the balance and msg.value are equal or greater than the wager
        require(balance[msg.sender].add(msg.value) >= _wager, "You don't have enough funds to submit a move with this wager");
        //@dev  Verify that the password / move combination hasn't been used before
        require(submits[_hashedMove] == false, "You have previously used this move / password combination, please use an unique password");
        //@dev  Verify that there is no existing move for sender against the opponent
        require(plays[storeMove].opponent == address(0), "You have already submitted a move against this opponent");
        //@dev  Verify if the opponent already has submitted a move and if they have, that it has the same wager
        if (plays[storeMoveOpponent].opponent == msg.sender) {
            require(plays[storeMoveOpponent].wager == _wager, "You must wager the same amount as your opponent");
        }
        //@dev  Set the new balance
        balance[msg.sender] = balance[msg.sender].add(msg.value).sub(_wager);
        //@dev  Store the move
        Plays storage currentMove = plays[storeMove];
        currentMove.opponent = _opponentAddress;
        currentMove.wager = _wager;
        currentMove.hashedMove = _hashedMove;
        currentMove.timestampSubmit = now;
        //@dev  Set the hashed submit to true so it can't be used again
        submits[_hashedMove] = true;
        //@dev  Create logs
        emit LogSubmittedMove(msg.sender, _opponentAddress, _wager);
    }
    
    //Function that allows a player to reveal their move, but only if the opponent has also submitted a move
    function revealMove(address _opponentAddress, Moves _move, bytes32 _password) public onlyIfRunning {
        //@dev  Calculate hash against which the move is stored
        bytes32 msgSenderDetails = keccak256(abi.encodePacked(msg.sender, _opponentAddress));
        //@dev  Calculate the hash your opponent has stored his move against
        bytes32 opponentDetails = keccak256(abi.encodePacked(_opponentAddress, msg.sender));
        //@dev  Verify that msg.sender has stored a move against opponent
        require(plays[msgSenderDetails].opponent == _opponentAddress, 
        "There is no move outstanding against opponent which you can reveal");
        //@dev  Verify that the opponent has stored a move against msg.sender
        require(plays[opponentDetails].opponent == msg.sender, 
        "You can't reveal your move until after your opponent has submitted a move");
        //@dev  Verify that the hash is correct
        require(plays[msgSenderDetails].hashedMove == generateHashedMove(_move, _password), 
        "The move you are attempting to reveal is not the same as the one you submited");
        Plays storage saveMove = plays[msgSenderDetails];
        saveMove.move = _move;
        saveMove.timestampReveal = now;
        //If both players have revealed the move, play the game
        if (plays[msgSenderDetails].move != Moves.Undefined && plays[opponentDetails].move != Moves.Undefined) {
            playGame(msgSenderDetails, opponentDetails, _opponentAddress, _move);
        }
    }

    function playGame(bytes32 msgSenderDetails, bytes32 opponentDetails, address _opponent, Moves _move) public onlyIfRunning returns (Result resultOfGame) {
        //@dev  Retrieve opponents move
        Moves moveOpponent = plays[opponentDetails].move;
        //@dev  Retrieve wager
        uint256 wager = plays[msgSenderDetails].wager;
        //@dev  Call function which will determine which player has the winning move
        Result gameResult = calculateWin(_move, moveOpponent); 
        //@dev  Delete the moves of both players (so they can play again)
        delete plays[msgSenderDetails];
        delete plays[opponentDetails];
        //@dev  Create logs
        emit LogPlayedGame(msg.sender, _opponent, gameResult, wager);
        //@dev  Assign wager to winning players balance and decrease balance of losing player
        if (gameResult == Result.msgSenderWins) {
            balance[msg.sender] = balance[msg.sender].add((wager.mul(2)));
            return Result.msgSenderWins;
        } else if (gameResult == Result.opponentWins) {
            balance[_opponent] = balance[_opponent].add((wager.mul(2)));
            return Result.opponentWins;
        } else {
            balance[msg.sender] = balance[msg.sender].add(wager);
            balance[_opponent] = balance[_opponent].add(wager);
            return Result.Draw;
        }
    }
    
    //@notice  Function that allows a played move to be rescinded when opponent doesn't submit move within a week
    //@notice  or when move doesn't get revealed within a week of msg.sender revealing
    function rescindMove(address _opponent) public onlyIfRunning {
        //@dev  Calculate hash against which the move is stored
        bytes32 msgSenderDetails = keccak256(abi.encodePacked(msg.sender, _opponent));
        //@dev  Calculate the hash your opponent has stored his move against
        bytes32 opponentDetails = keccak256(abi.encodePacked(_opponent, msg.sender));
        //@dev  Verify there is a move stored against opponent
        require(plays[msgSenderDetails].opponent == _opponent, "There is no move outstanding against opponent");
        //@dev  If the opponent has not submitted a move
        if (plays[opponentDetails].opponent == address(0)) {
            //@dev Then verfiy if the expiry period has been exceded and if it has, call returnWager function
            require(plays[msgSenderDetails].timestampSubmit.add(gameExpiry) < now, "Submission expiry not exceeded yet"); {
            returnWager(msgSenderDetails, _opponent);
            } 
        }    
        //@dev  If the opponent has submitted a move
        else if (plays[opponentDetails].opponent == msg.sender) {
            //@dev  And if message sender has not revealed his/her move yet, then don't allow to rescind
            if (plays[msgSenderDetails].move == Moves.Undefined) {
                require(plays[msgSenderDetails].move != Moves.Undefined, 
                "You and your opponent have both submitted a move, but not revealed, you can't rescind until after you have revealed and your opponent has expired his/her reveal period");
            //@dev  If the message sender has revealed a move and the opponent hasn't, allow to rescind after expiry has been reached
            } else if (plays[msgSenderDetails].move != Moves.Undefined) {
                require(plays[opponentDetails].move == Moves.Undefined && plays[msgSenderDetails].timestampReveal.add(gameExpiry) < now, 
                "Your opponent still has time to reveal his/her move before you can rescind");
                returnWager(msgSenderDetails, _opponent);
            }
        }
    }
     
    //@notice  Function that allows a player to withdraw his/her balance
    function withdrawBalance(uint256 amount) public onlyIfNotPaused { 
        //@dev  Verify that the amount is positive
        require(amount > 0, "You must withdraw a positive amount");
        //@dev  Verify that the amount is not greater than the balance
        require(balance[msg.sender] >= amount, "You don't have a high enough balance");
        //@dev  Decrease balance 
        balance[msg.sender] = balance[msg.sender].sub(amount);
        //@dev  Transfer balance to sender
        address(msg.sender).transfer(amount);
        //@dev  Create logs
        emit LogWithdrawBalance(msg.sender, amount);
    }    
    
    //@notice  Retrieves contract balance - just for Remix
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
    
    //Function that allows a move with password to be hashed
    function generateHashedMove(Moves _move, bytes32 _password) view public onlyIfRunning returns (bytes32) {
        //Verify that the move and password have been populated
        require(_move == Moves.Rock || _move == Moves.Paper || _move == Moves.Scissors, "You must enter either Rock, Paper or Scissors");
        require(_password != 0, "Entering a password is mandatory");
        return keccak256(abi.encodePacked(this, msg.sender, _move, _password));
    }
    
    //@notice  Function that calculates the winning move
    function calculateWin(Moves _move1, Moves _move2) pure internal returns (Result result) {
        if (_move1 == _move2) {
            return Result.Draw;
        } else if (_move1 == Moves.Rock && _move2 == Moves.Paper) {
            return Result.opponentWins;
        } else if (_move1 == Moves.Paper && _move2 == Moves.Scissors) {
            return Result.opponentWins;
        } else if (_move1 == Moves.Scissors && _move2 == Moves.Rock) {
            return Result.opponentWins;
        } else if (_move1 == Moves.Paper && _move2 == Moves.Rock) {
            return Result.msgSenderWins;
        } else if (_move1 == Moves.Scissors && _move2 == Moves.Paper) {
            return Result.msgSenderWins;
        } else if (_move1 == Moves.Rock && _move2 == Moves.Scissors) {
            return Result.msgSenderWins;
        }
    }
    
    //@notice  Function that returns wagers from rescinded moves to message sender       
    function returnWager(bytes32 _msgSenderDetails, address _opponent) internal {
        //@dev  Delete the move
        uint256 wager = plays[_msgSenderDetails].wager;
        delete plays[_msgSenderDetails];
        //@dev  Return the wager to senders balance
        balance[msg.sender] = balance[msg.sender].add(wager);
        //@dev  Create logs
        emit LogRescindedMove(msg.sender, _opponent, wager);
    }

}