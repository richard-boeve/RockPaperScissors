const RockPaperScissors = artifacts.require("./RockPaperScissors.sol");
const truffleAssert = require('truffle-assertions');
const BN = require('bn.js');

contract('RockPaperScissors', (accounts) => {

    let rps;
    let owner = accounts[0];
    let player1 = accounts[1];
    let player2 = accounts[2];
    let movePlayer1 = 1;
    let movePlayer2 = 2;
    let passwordPlayer1 = "0xaaaaaa";
    let passwordPlayer2 = "0xbbbbbb";
    let winnerPlayer2 = 0;
    let depositAmount = web3.utils.toBN(web3.utils.toWei('10000000', 'wei'));
    let wagerAmount = web3.utils.toBN(web3.utils.toWei('1000000', 'wei'));
    const GAS_PRICE = new BN(1000);

    beforeEach("Create a new instance", async () => {
      rps = await RockPaperScissors.new({from: owner, gasPrice: GAS_PRICE})
    });

    it("Verify a deposit to an in game account can be made", async () => {
      //Submit deposit transaction
      const depositTxReceipt= await rps.deposit({from: player1, value: depositAmount});
      //Checking the transaction event logs
      assert.strictEqual(depositTxReceipt.logs[0].args.sender, player1, "Transaction receipt shows incorrect sender");
      assert.strictEqual(depositTxReceipt.logs[0].args.depositAmount.toString(10), depositAmount.toString(10), "Transaction receipts shows an incorrect amount");
      //Checking the ingame balance of player 1
      assert.strictEqual(depositAmount.toString(10), (await rps.balance(player1)).toString(10), "The in game balance for Player 1 is incorrect")
    })

    it("Verify a move can be submitted", async () => {
      //Submit deposit transaction
      const depositTxReceipt= await rps.deposit({from: player1, value: depositAmount});
      //Generate a hashed move
      const hashedMove = await rps.generateHashedMove(movePlayer1, passwordPlayer1);
      //Submit a move
      const submitTxReceipt = await rps.submitMove(player2, hashedMove, wagerAmount, {from: player1});
      //Calculate the hash against which the move is stored
      const storeMove = await rps.calculateStorageHashMsgSender(player1, player2);
      //Checking the transaction event logs
      assert.strictEqual(submitTxReceipt.logs[0].args.sender, player1, "Transaction receipt shows incorrect sender");
      assert.strictEqual(submitTxReceipt.logs[0].args.opponent, player2, "Transaction receipts shows incorrect opponent");
      assert.strictEqual(submitTxReceipt.logs[0].args.wager.toString(10), wagerAmount.toString(10), "Transaction receipt shows incorrect wager");
      //Verify the submitted move is stored
      assert.strictEqual(hashedMove.toString(), (await rps.plays(storeMove))[2].toString(), "The hashed moved is incorrect");
    })

    it("Verify a move can be revealed and the game played", async () => {
      //Submit deposit transactions
      const depositTxReceiptPlayer1= await rps.deposit({from: player1, value: depositAmount});
      const depositTxReceiptPlayer2= await rps.deposit({from: player2, value: depositAmount});
      //Generate hashed moves
      const hashedMovePlayer1 = await rps.generateHashedMove(movePlayer1, passwordPlayer1, {from: player1});
      const hashedMovePlayer2 = await rps.generateHashedMove(movePlayer2, passwordPlayer2, {from: player2});
      //Submit moves
      const submitMoveTxReceiptPlayer1 = await rps.submitMove(player2, hashedMovePlayer1, wagerAmount, {from: player1});
      const submitMoveTxReceiptPlayer2 = await rps.submitMove(player1, hashedMovePlayer2, wagerAmount, {from: player2});
      //Reveal moves
      const revealMoveTxReceiptPlayer1 = await rps.revealMove(player2, movePlayer1, passwordPlayer1, {from: player1});
      const revealMoveTxReceiptPlayer2 = await rps.revealMove(player1, movePlayer2, passwordPlayer2, {from: player2});
      //Checking the transaction event logs
      assert.strictEqual(revealMoveTxReceiptPlayer2.logs[0].args.result.toString(10), winnerPlayer2.toString(10), "Transaction receipt shows incorrect sender");
    })
})
