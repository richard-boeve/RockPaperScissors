const Web3 = require("web3");
const truffleContract = require("truffle-contract");
const $ = require("jquery");
const rockPaperScissorsJson = require("../../build/contracts/RockPaperScissors.json");
const Promise = require("bluebird");

require("file-loader?name=../index.html!../index.html");

// Supports Mist, and other wallets that provide 'web3'.
// Use a web3 browser if availble
if (typeof web3 !== 'undefined') {
    console.log('Web3 browser detected! ' + web3.currentProvider.constructor.name)
    window.web3 = new Web3(web3.currentProvider);
    // Otherwise, use a own provider with port 8545  
} else {
    console.log('Web3 browser not detected, setting own provider!')
    window.web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));
}

Promise.promisifyAll(web3.eth, { suffix: "Promise" });
Promise.promisifyAll(web3.version, { suffix: "Promise" });

const RockPaperScissors = truffleContract(rockPaperScissorsJson);
RockPaperScissors.setProvider(web3.currentProvider);

window.addEventListener('load', function () {
    return RockPaperScissors.deployed()
        .then(_rps => {
            rps = _rps;
            return web3.eth.getBalancePromise(rps.address);
        })
        .then(balance => $("#balanceContract").html(web3.fromWei(balance.toString(10))))
        .then(() => $("#sendDeposit").click(deposit))
        .then(() => $("#generateHashedMove").click(generateHashedMove))
        .then(() => $("#submitMove").click(submitMove))
        .then(() => $("#revealMove").click(revealMove))
        .then(() => $("#rescindMove").click(rescindMove))
        .then(() => $("#withdraw").click(withdraw))
        .catch(console.error);
});

//Function that allows a deposit to be made to the in game account of the player
const deposit = function () {
    let rps;
    window.account = $("input[name='sender']").val();
    return RockPaperScissors.deployed()
        .then(_rps => {
            rps = _rps;
            console.log("RPS address: ", rps.address);
            return rps.deposit.sendTransaction(
            {   
                from: window.account,
                value: $("input[name='amount']").val(),
            })
        })    
        .then(txHash => {
            $("#status").html("Transaction on the way " + txHash);
            const tryAgain = () => web3.eth.getTransactionReceiptPromise(txHash)
                .then(receipt => receipt !== null ?
                    receipt :
                    Promise.delay(1000).then(tryAgain));
            return tryAgain();
        }) 
        //Return a success of failure of the transaction
        .then(receipt => {
            if (parseInt(receipt.status) != 1) {
                console.error("Wrong status");
                console.error(receipt);
                $("#status").html("There was an error in the tx execution, status not 1");
            } else if (receipt.logs.length == 0) {
                console.error("Empty logs");
                console.error(receipt);
                $("#status").html("There was an error in the tx execution");
            } else {
                let logDeposit = rps.LogDeposit().formatter(receipt.logs[0]);
                console.log("Sender's address: " + logDeposit.args.sender);
                console.log("Amount deposited: " + logDeposit.args.depositAmount);
                $("#status").html("Transfer executed");
            }
            return web3.eth.getBalancePromise(rps.address);
        })
        //Update the balance of the contract
        .then(balance => {
            $("#balanceContract").html(web3.fromWei(balance.toString(10)))
        })
        //Catch any errors
        .catch(e => {
            $("#status").html(e.toString());
            console.error(e);
        });
}

const generateHashedMove = function () {
    let rps;
    window.account = $("input[name='passwordSender']").val();
    return RockPaperScissors.deployed()
        .then(_rps => {
            rps = _rps;
            console.log("RPS address: ", rps.address);
            return rps.generateHashedMove.call(
                $("input[name='move']").val(), 
                $("input[name='password']").val(),
                { from: window.account, gas: 21000000 });
              
        })
            .then(hash => {
                $("#hashedPassword").html(hash)
            });
}
    
const submitMove = function () {
    let rps;
    window.account = $("input[name='moveSender']").val();
    return RockPaperScissors.deployed()
        .then(_rps => {
            rps = _rps;
            console.log("RPS address: ", rps.address);
            return rps.submitMove.sendTransaction(
                $("input[name='opponent']").val(), 
                $("input[name='hashedMove']").val(),
                $("input[name='wager']").val(),
            {   
                from: window.account,
                value: $("input[name='amountSubmit']").val(),
                gas: 2000000,
            })
        })
        .then(txHash => {
            $("#status").html("Transaction on the way " + txHash);
            const tryAgain = () => web3.eth.getTransactionReceiptPromise(txHash)
                .then(receipt => receipt !== null ?
                    receipt :
                    Promise.delay(1000).then(tryAgain));
            return tryAgain();
        }) 
        //Return a success of failure of the transaction
        .then(receipt => {
            if (parseInt(receipt.status) != 1) {
                console.error("Wrong status");
                console.error(receipt);
                $("#status").html("There was an error in the tx execution, status not 1");
            } else if (receipt.logs.length == 0) {
                console.error("Empty logs");
                console.error(receipt);
                $("#status").html("There was an error in the tx execution");
            } else {
                let logSubmittedMove = rps.LogSubmittedMove().formatter(receipt.logs[0]);
                console.log("Sender's address: " + logSubmittedMove.args.sender);
                console.log("Opponent's address: " + logSubmittedMove.args.opponent);
                console.log("Wager: " + logSubmittedMove.args.wager);
                $("#status").html("Transfer executed");
            }
            return web3.eth.getBalancePromise(rps.address);
        })
        //Update the balance of the contract
        .then(balance => {
            $("#balanceContract").html(web3.fromWei(balance.toString(10)))
        })
        //Catch any errors
        .catch(e => {
            $("#status").html(e.toString());
            console.error(e);
        });
}

const revealMove = function () {
    let rps;
    window.account = $("input[name='revealSender']").val();
    return RockPaperScissors.deployed()
        .then(_rps => {
            rps = _rps;
            console.log("RPS address: ", rps.address);
            return rps.revealMove.sendTransaction(
                $("input[name='revealOpponent']").val(), 
                $("input[name='revealMove']").val(),
                $("input[name='revealPassword']").val(),
            {   
                from: window.account,
                gas: 2000000,
            })
        })
        .then(txHash => {
            $("#status").html("Transaction on the way " + txHash);
            const tryAgain = () => web3.eth.getTransactionReceiptPromise(txHash)
                .then(receipt => receipt !== null ?
                    receipt :
                    Promise.delay(1000).then(tryAgain));
            return tryAgain();
        }) 
        //Return a success of failure of the transaction
        .then(receipt => {
            if (parseInt(receipt.status) != 1) {
                console.error("Wrong status");
                console.error(receipt);
                $("#status").html("There was an error in the tx execution, status not 1");
            } else if (receipt.logs.length == 0 && (parseInt(receipt.status) == 1)) {
                $("#status").html("Transfer executed, opponent has not revealed a move yet");
            } else {
                let logPlayedGame = rps.LogPlayedGame().formatter(receipt.logs[0]);
                console.log("Sender's address: " + logPlayedGame.args.sender);
                console.log("Sender's move: " + logPlayedGame.args.move);
                console.log("Opponent's address: " + logPlayedGame.args.opponent);
                console.log("Opponent's move: " + logPlayedGame.args.opponentMove);
                console.log("Result: " + logPlayedGame.args.result);
                if (logPlayedGame.args.result == 0) {
                    $("#status").html("Transfer executed. You played " + logPlayedGame.args.move + " and your opponent played " + logPlayedGame.args.opponentMove + " which means you have won the game!");
                } else if (logPlayedGame.args.result == 1) {
                    $("#status").html("Transfer executed. You played " + logPlayedGame.args.move + " and your opponent played " + logPlayedGame.args.opponentMove + " which means you have lost the game :-(");
                } else {
                    $("#status").html("Transfer executed. You played " + logPlayedGame.args.move + " and your opponent played " + logPlayedGame.args.opponentMove + " which means it's a draw!");
                }
            }
        })
        //Catch any errors
        .catch(e => {
            $("#status").html(e.toString());
            console.error(e);
        });
}
 
const rescindMove = function () {
    let rps;
    window.account = $("input[name='rescindSender']").val();
    return RockPaperScissors.deployed()
        .then(_rps => {
            rps = _rps;
            console.log("RPS address: ", rps.address);
            return rps.rescindMove.sendTransaction(
                $("input[name='rescindOpponent']").val(), 
            {   
                from: window.account,
                gas: 2000000,
            })
        })
        .then(txHash => {
            $("#status").html("Transaction on the way " + txHash);
            const tryAgain = () => web3.eth.getTransactionReceiptPromise(txHash)
                .then(receipt => receipt !== null ?
                    receipt :
                    Promise.delay(1000).then(tryAgain));
            return tryAgain();
        }) 
        //Return a success of failure of the transaction
        .then(receipt => {
            if (parseInt(receipt.status) != 1) {
                console.error("Wrong status");
                console.error(receipt);
                $("#status").html("There was an error in the tx execution, status not 1");
            } else if (receipt.logs.length == 0 && (parseInt(receipt.status) == 1)) {
                $("#status").html("Transfer executed, but no move was rescinded as either there is no move outstanding against opponent or you can't rescind as both you and your opponent have a move outstanding");
            } else {
                let logRescindedMove = rps.LogRescindedMove().formatter(receipt.logs[0]);
                console.log("Sender's address: " + logRescindedMove.args.sender);
                console.log("Opponent's address: " + logRescindedMove.args.opponent);
                console.log("Wager: " + logRescindedMove.args.wager);
                $("#status").html("Transfer executed. Your move has been successfully rescinded");
            }
            return web3.eth.getBalancePromise(rps.address);
        })
        //Update the balance of the contract
        .then(balance => {
            $("#balanceContract").html(web3.fromWei(balance.toString(10)))
        })
        //Catch any errors
        .catch(e => {
            $("#status").html(e.toString());
            console.error(e);
        });
}

const withdraw = function () {
    let rps;
    window.account = $("input[name='withdrawSender']").val();
    return RockPaperScissors.deployed()
        .then(_rps => {
            rps = _rps;
            console.log("RPS address: ", rps.address);
            return rps.withdrawBalance.sendTransaction(
                $("input[name='withdrawAmount']").val(), 
            {   
                from: window.account,
                gas: 2000000,
            })
        })
        .then(txHash => {
            $("#status").html("Transaction on the way " + txHash);
            const tryAgain = () => web3.eth.getTransactionReceiptPromise(txHash)
                .then(receipt => receipt !== null ?
                    receipt :
                    Promise.delay(1000).then(tryAgain));
            return tryAgain();
        }) 
        //Return a success of failure of the transaction
        .then(receipt => {
            if (parseInt(receipt.status) != 1) {
                console.error("Wrong status");
                console.error(receipt);
                $("#status").html("There was an error in the tx execution, status not 1");
            } else if (receipt.logs.length == 0) {
                console.error("Empty logs");
                console.error(receipt);
                $("#status").html("There was an error in the tx execution");
            } else {
                let logWithdrawal = rps.LogWithdrawBalance().formatter(receipt.logs[0]);
                console.log("Sender's address: " + logWithdrawal.args.sender);
                console.log("Amount withdrawn: " + logWithdrawal.args.withdrawAmount);
                $("#status").html("Transfer executed");
            }
            return web3.eth.getBalancePromise(rps.address);
        })
        //Update the balance of the contract
        .then(balance => {
            $("#balanceContract").html(web3.fromWei(balance.toString(10)))
        })
        //Catch any errors
        .catch(e => {
            $("#status").html(e.toString());
            console.error(e);
        });
}