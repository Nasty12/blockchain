var Game = artifacts.require("Game");

contract('Game', function(accounts){

	it("game work correctly", function(){
		var game;

		var account_one = accounts[0];

		var team_one = [1, 2, 3];
		var team_two = [3, 4, 5];

		var sportsmanFlat = [1, 2, 2, 1, 2, 2, 2, 6, 1, 3, 2, 2, 3, 1, 3, 2, 4, 1, 1, 2, 3, 4, 1, 4, 1, 1, 2, 2, 5, 1, 4, 1, 1, 2, 3];
		var rulesFlat = [1, 1, 40, 1, 2, 40, 2, 1, 10, 2, 2, 80, 3, 1, 100, 3, 2, 10, 4, 1, 20, 4, 2, 80];

		return Game.deployed().then(function(instance){
			game = instance;
			return game.dispatcher.call();
		}).then(function(result){
			console.log("dispatcher:" + result);
			return game.service.call();
		}).then(function(result){
			console.log("service   :" + result);
			return game.gameToken.call();
		}).then(function(result){
			console.log("GameToken :" + result);
			return game.stats.call();
		}).then(function(result){
			console.log("Stats     :" + result);
			return game.broker.call();
		}).then(function(result){
			console.log("Broker    :" + result);
			return game.gameState.call();
		}).then(function(state){
			console.log("state     :" + state.toNumber());
			assert.equal(state.toNumber(), 0, "game state is team creation");
			return game.serviceFee.call();
		}).then(function(serviceFee){
			console.log("fee       :" + serviceFee.valueOf());
			return game.addParticipant(account_one, team_one);
		}).then(function(){
			return game.teamsCountOf.call(account_one);
		}).then(function(count){
			console.log("count     :" + count);
			assert.equal(count, 1, "account_one has 1 team");
			return game.addParticipant(account_one, team_two);
		}).then(function(){
			return game.teamsCountOf.call(account_one);
		}).then(function(count){
			console.log("count     :" + count);
			assert.equal(count, 2, "account_one has 2 teams");
			return game.gameState.call();
		}).then(function(state){
			console.log("state     :" + state.toNumber());
			assert.equal(state.toNumber(), 0, "game state is still team creation");
			return game.startGame();
		}).then(function(){
			return game.gameState.call();
		}).then(function(state){
			console.log("state     :" + state.toNumber());
			assert.equal(state.toNumber(), 1, "game state is In Progress");
			return game.finishGame(sportsmanFlat, rulesFlat)
		}).then(function(){
			console.log("game finished");
			return game.gameState.call();
		}).then(function(state){
			console.log("state     :" + state.toNumber());
			assert.equal(state.toNumber(), 3, "game state is finished");
		});;
	});
});