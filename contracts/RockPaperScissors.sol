pragma solidity 0.5.6;

import "./Stoppable.sol";
import "./SafeMath.sol";

//@author  Richard Boeve
//@title  Rock Paper Scissors game
contract RockPaperScissors is Stoppable {

    //@notice  Using the SafeMath library
    using SafeMath for uint256;

    //@notice  Defining the move possibilities
    enum Moves { 
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
        Moves move;
    }
    
    //@notice  Mapping that stores players moves
    mapping(bytes32 => Plays) public plays;

    //@notice  Mapping that stores winnings 
    mapping(address => uint256) public balance;
    
    //@notice  Mapping that keeps count of a players total outstanding wagers
    mapping(address => uint256) public wageredAmount;
    
    //@notice  All events resulting from the contracts functions
    event LogDeposit(address indexed sender, uint256 depositAmount);
    event LogSubmittedMove(address indexed sender, address indexed opponent, Moves move, uint256 wager);
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
    function submitMove(address _opponentAddress, Moves _move, uint256 _wager) public onlyIfRunning payable {
        //@dev  Create a unique hash to store the move
        bytes32 storeMove = keccak256(abi.encodePacked(msg.sender, _opponentAddress));
        //@dev  Calculate the hash your opponent has stored his move against (or where he/she will store move)
        bytes32 storeMoveOpponent = keccak256(abi.encodePacked(_opponentAddress, msg.sender));
        //@dev  If any funds are sent with the move, store these against the players balance
        balance[msg.sender] = balance[msg.sender].add(msg.value);
        //@dev  Verify that the balance is equal or greater than the wager
        require(balance[msg.sender] >= _wager, "You don't have enough funds to submit a move with this wager");
        //@dev  Verify that there is no existing move for sender against the opponent
        require(plays[storeMove].opponent == address(0), "You have already submitted a move against this opponent");
        //@dev  Verify if the opponent already has submitted a move and if they have, that it has the same wager
        if (plays[storeMoveOpponent].opponent == msg.sender) {
            require(plays[storeMoveOpponent].wager == _wager, "You must wager the same amount as your opponent");
        }
        //@dev  Increase the total wagered amount
        wageredAmount[msg.sender] = wageredAmount[msg.sender].add(_wager);
        //@dev  Store the move
        Plays storage currentMove = plays[storeMove];
        currentMove.opponent = _opponentAddress;
        currentMove.wager = _wager;
        currentMove.move = _move;
        //@dev  Create logs
        emit LogSubmittedMove(msg.sender, _opponentAddress, _move, _wager);
    }

    //@notice  Function that plays the game and allocates wager to balance of winner
    function playGame(address _opponent) public onlyIfRunning returns (Result resultOfGame) {
        //@dev  Calculate hash against which the move is stored
        bytes32 msgSenderDetails = keccak256(abi.encodePacked(msg.sender, _opponent));
        //@dev  Calculate the hash your opponent has stored his move against
        bytes32 opponentDetails = keccak256(abi.encodePacked(_opponent, msg.sender));
        //@dev  Retrieve wager 
        uint256 wagerAmount = plays[msgSenderDetails].wager;
        //@dev  Retrieve message sender move
        Moves moveMsgSender = plays[msgSenderDetails].move;
        //@dev  Retrieve opponents move
        Moves moveOpponent = plays[opponentDetails].move;
        //@dev  Call function which will determine which player has the winning move
        Result gameResult = calculateWin(moveMsgSender, moveOpponent); 
        //@dev  Delete the moves of both players (so they can play again)
        delete plays[msgSenderDetails];
        delete plays[opponentDetails];
        //@dev  Decrease wagered amount totals for both players
        wageredAmount[msg.sender] = wageredAmount[msg.sender].sub(wagerAmount);
        wageredAmount[_opponent] = wageredAmount[_opponent].sub(wagerAmount);
        //@dev  Create logs
        emit LogPlayedGame(msg.sender, _opponent, gameResult, wagerAmount);
        //@dev  Assign wager to winning players balance and decrease balance of losing player
        if (gameResult == Result.msgSenderWins) {
            balance[_opponent] = balance[_opponent].sub(wagerAmount);
            balance[msg.sender] = balance[msg.sender].add(wagerAmount);
            return Result.msgSenderWins;
        } else if (gameResult == Result.opponentWins) {
            balance[msg.sender] = balance[msg.sender].sub(wagerAmount);
            balance[_opponent] = balance[_opponent].add(wagerAmount);
            return Result.opponentWins;
        } else {
            return Result.Draw;
        }
    }
    
    //@notice  Function that allows a played move to be rescinded as long as opponent has played a move yet
    function rescindMove(address _opponent) public onlyIfRunning {
        //@dev  Calculate hash against which the move is stored
        bytes32 msgSenderDetails = keccak256(abi.encodePacked(msg.sender, _opponent));
        //@dev  Calculate the hash your opponent has stored his move against
        bytes32 opponentDetails = keccak256(abi.encodePacked(_opponent, msg.sender));
        //@dev  Verify there is a move stored against opponent
        require(plays[msgSenderDetails].opponent == _opponent, "There is no move outstanding against opponent");
        //@dev  Verify that the opponent hasn't stored a move against message sender yet
        require(plays[opponentDetails].opponent == address(0), 
        "Your opponent has already submitted a move against you, you can't rescind anymore");
        //@dev  Delete the move
        uint256 wagerAmount = plays[msgSenderDetails].wager;
        delete plays[msgSenderDetails];
        //@dev  Decrease wagered amount 
        wageredAmount[msg.sender] = wageredAmount[msg.sender].sub(wagerAmount);
        //@dev  Return the wager to senders balance
        balance[msg.sender] = balance[msg.sender].add(wagerAmount);
        //@dev  Create logs
        emit LogRescindedMove(msg.sender, _opponent, wagerAmount);
    } 
    
    //@notice  Function that allows a player to withdraw his/her balance minus outstanding wagers
    function withdrawBalance() public onlyIfNotPaused { 
        //@dev  Outstanding wagers
        uint256 outstandingWagers = wageredAmount[msg.sender];
        uint256 balanceToWithdraw = balance[msg.sender].sub(outstandingWagers);
        //@dev  Verify the sender has a positive balance, not taking into account outstanding wagers
        require(balanceToWithdraw > 0, "After accounting for possible outstanding wagers, there is no balance to withdraw");
        //@dev  Decrease balance 
        balance[msg.sender] = outstandingWagers;
        //@dev  Transfer balance to sender
        address(msg.sender).transfer(balanceToWithdraw);
        //@dev  Create logs
        emit LogWithdrawBalance(msg.sender, balanceToWithdraw);
    }    
    
    //@notice  Retrieves contract balance - just for Remix
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
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
}