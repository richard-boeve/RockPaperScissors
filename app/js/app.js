const Web3 = require("web3");
const truffleContract = require("truffle-contract");
const $ = require("jquery");
const rockPaperScissorsJson = require("../../build/contracts/RockPaperScissors.json");
const Promise = require("bluebird");

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

web3.eth.getAccounts(accounts => console.log(accounts[0]));

Promise.promisifyAll(web3.eth, { suffix: "Promise" });
Promise.promisifyAll(web3.version, { suffix: "Promise" });

const RockPaperScissors = truffleContract(rockPaperScissorsJson);
RockPaperScissors.setProvider(web3.currentProvider);

require("file-loader?name=../index.html!../index.html");

window.addEventListener('load', function () {
    return RockPaperScissors.deployed()
        .then(_rps => {
            rps = _rps;
            return web3.eth.getBalancePromise(rps.address);
        })
        .then(balance => $("#balanceContract").html(web3.fromWei(balance.toString(10))))
        .then(web3.eth.accounts[0])
        //.then(() => $("#send").click(deposit))
        //.then(() => $("#withdraw").click(withdrawFunds))
        .catch(console.error);
        // var account = web3.eth.accounts[0];
        // var accountInterval = setInterval(function() {
        //   if (web3.eth.accounts[0] !== account) {
        //     account = web3.eth.accounts[0];
        //     document.getElementById("address").innerHTML = account;
        //   }
        // }, 100);

});







