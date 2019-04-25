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