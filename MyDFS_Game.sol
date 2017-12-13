pragma solidity ^0.4.16;

interface Token {
    function transfer(address to, uint256 value) public returns (bool success);
    function transferFrom(address from, address to, uint256 value) public returns (bool success);
    function balanceOf(address owner) public constant returns (uint256 balance);
    function approve(address spender, uint256 value) public returns (bool success);
} 

interface Stats {
	function approve(address gameContract) public;
	function incStat(address user, bool win, uint256 entrySum, uint256 prize) public;
}

interface Broker {
	function transferFrom(address beneficiary, address user, address to, uint256 value) public returns (bool success);
	function allowance(address owner, address spender) public constant returns (uint256 remaining);
	function getUserFee(address beneficiary, address user) public constant returns (uint16 fee);
}

contract MyDFSGame {

	struct Player {
		address user;
		address beneficiary;
		int48[] team;
		int48 score;
		uint48 prize;
	}

	enum State { TeamCreation, InProgress, Finished, Canceled }

	uint64 gameId;
	uint32 public gameEntry;

	Player[] public players;
	Player tmpPlayer;

	address gameServer;
	Token gameToken;
	Stats stats;
	Broker broker;

	uint8 public serviceFee;

	uint8[] smallGameRules;
	uint8[] largeGameRules;
	
	uint8[] public activeRule;

	State public gameState;

	mapping(int48 => int48) public scores;
	mapping(int48 => mapping (int48 => int48)) public rules;

	function MyDFSGame(
		uint64 id,
		uint32 gameEntryValue,
		address gameTokenAddress,
		address statsAddress,
		address brokerAddress,
		uint8 serviceFeeValue,
		uint8[] smallGameWinnersPercents,
		uint8[] largeGameWinnersPercents) public {
		gameId = id;
		gameEntry = gameEntryValue;
		serviceFee = serviceFeeValue;
		gameServer = msg.sender;
		gameToken = Token(gameTokenAddress);

		stats = Stats(statsAddress);

		broker = Broker(brokerAddress);

		smallGameRules = smallGameWinnersPercents;
		largeGameRules = largeGameWinnersPercents;
        
		gameState = State.TeamCreation;
	}
	//call after create
	//stats.approve(<game address>);


	modifier owned() { if (msg.sender == gameServer) _; }
	modifier beforeStart() { if (gameState == State.TeamCreation) _; }
	modifier inProgress() { if (gameState == State.InProgress) _; }

	//call this method before participate
	//gameToken.approve(<game address>, gameEntry);
	function participate(int48[] team) public beforeStart {
		if (gameToken.balanceOf(msg.sender) >= gameEntry){
			gameToken.transferFrom(msg.sender, address(this), gameEntry);
			players.push(Player(msg.sender, address(0x0), team, 0, 0));
		} else {
			revert();
		}
	}

	function participateBeneficiary(int48[] team, address beneficiary) public beforeStart {
		if (broker.allowance(beneficiary, msg.sender) >= gameEntry){
			broker.transferFrom(beneficiary, msg.sender, address(this), gameEntry);
			players.push(Player(msg.sender, beneficiary, team, 0, 0));
		} else {
			revert();
		}
	}

	function startGame() public owned {
		if (players.length > 0){
			gameState = State.InProgress;
		} else {
			gameState = State.Finished;
		}
	}

	function cancelGame() public owned {
		gameState = State.Canceled;
		for (uint32 i = 0; i < players.length; i++){
			gameToken.transfer(players[i].user, gameEntry);
		}
	}

	function finishGame(int48[] sportsmenFlatData, int48[] rulesFlat) public owned inProgress {
	    compileRules(rulesFlat);
		compileGameStats(sportsmenFlatData);
		calculatePlayersScores();
		sortPlayers();
		calculateWinners();
		updateUsersStats();
		gameState = State.Finished;
	}

    function compileRules(int48[] rulesFlat) internal {
        for (uint32 i = 0; i < rulesFlat.length; i+=3) {
			rules[rulesFlat[i + 1]][rulesFlat[i]] = rulesFlat[i + 2];
		}
    }
    
    function compileGameStats(int48[] sportsmenFlatData) internal {
        uint32 i = 0;
		while (i < sportsmenFlatData.length) {
			int48 sportsmanId = sportsmenFlatData[i];
			int48 roleId = sportsmenFlatData[i + 1];
			uint32 actionsCount = (uint32)(sportsmenFlatData[i + 2]);
			for (uint32 j = i + 3; j < i + actionsCount + 3; j += 2){
				int48 actionId = sportsmenFlatData[j];
				int48 count = sportsmenFlatData[j + 1];
				scores[sportsmanId] += rules[roleId][actionId] * count;
			}
			i += actionsCount + 2 + 1;
		}
    }
    
    function calculatePlayersScores() internal {
        for (uint32 i = 0; i < players.length; i++){
			for (uint32 j = 0; j < players[i].team.length; j++){
				players[i].score += scores[players[i].team[j]];
			}
		}
    }
    
    function calculateWinners() internal {
        uint256 prize = totalPrize();
        uint32 place = 0;
		uint32 counter = 0;
		uint32[] memory tmpArray = new uint32[](players.length);
        uint32 tmpArraySize;
	    activeRule = players.length > 100 ? largeGameRules : smallGameRules;
		while (place < activeRule.length && counter < players.length) {
			uint32 current = counter;
			counter++;
			tmpArraySize = 1;
			tmpArray[tmpArraySize - 1] = current;
			while (counter < players.length && players[current].score == players[counter].score){
				tmpArraySize++;
                tmpArray[tmpArraySize - 1] = counter;
				counter++;
			}
			uint48 placePrizePercent = 0;
			for (uint32 pIndex = place; pIndex < place + tmpArraySize; pIndex++) {
				if (pIndex < activeRule.length) {
					placePrizePercent += activeRule[pIndex];
				}
			}
			for (uint32 wIndex = 0; wIndex < tmpArraySize; wIndex++) {
				players[tmpArray[wIndex]].prize = (uint48)(prize) * placePrizePercent / (100 * tmpArraySize);
				if (players[tmpArray[wIndex]].beneficiary > 0){
					uint256 userPrize = broker.getUserFee(players[tmpArray[wIndex]].beneficiary, players[tmpArray[wIndex]].user) * players[tmpArray[wIndex]].prize / 100;
					uint256 beneficiaryPrize = players[tmpArray[wIndex]].prize - userPrize;
					gameToken.transfer(players[tmpArray[wIndex]].user, userPrize);
					gameToken.transfer(players[tmpArray[wIndex]].beneficiary, beneficiaryPrize);
				} else {
					gameToken.transfer(players[tmpArray[wIndex]].user, players[tmpArray[wIndex]].prize);
				}
			}
			place += tmpArraySize;
		}
		gameToken.transfer(gameServer, gameToken.balanceOf(address(this)));
    }
    
    function updateUsersStats() internal {
        for (uint32 i = 0; i < players.length; i++){
            stats.incStat(players[i].user, players[i].prize > 0, gameEntry, players[i].prize);
        }
    }

	function sortPlayers() internal {
        if (players.length == 0)
            return;
        quickSort(0, players.length - 1);
    }
    
    function quickSort(uint256 left, uint256 right) internal {
        uint256 i = left;
        uint256 j = right;
        while (i <= j) {
            while (i < players.length && players[i].score > players[left + (right - left) / 2].score) i++;
            while (j >= 0 && players[left + (right - left) / 2].score > players[j].score) j--;
            if (i <= j) {
                tmpPlayer = players[i];
                players[i] = players[j];
                players[j] = tmpPlayer;
                i++;
                if (j > 0) {
                    j--;
                }
            }
        }
        if (left < j)
            quickSort(left, j);
        if (i < right)
            quickSort(i, right);
    }

	function abs(int48 a) internal constant returns (int48) {
		return (a < 0) ? -a : a;
	}

	function gameState() public constant returns (State) {
		return gameState;
	}

	function totalPrize() public constant returns (uint256 prize){
		return gameToken.balanceOf(address(this)) * (100 - serviceFee) / 100;
	} 
}

