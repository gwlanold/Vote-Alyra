// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Voting is Ownable {
    
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }
    
    struct Proposal {
        string description;
        uint voteCount;
    }
    
    mapping(address => Voter) whitelist;
    
    mapping (uint => uint[]) winningProposalIds;
    
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }
    
    WorkflowStatus voteStatus = WorkflowStatus.RegisteringVoters;
    
    event VoterRegistered(address voterAddress);
    event ProposalsRegistrationStarted();
    event ProposalsRegistrationEnded();
    event ProposalRegistered(uint proposalId);
    event VotingSessionStarted();
    event VotingSessionEnded();
    event Voted (address voter, uint proposalId);
    event VotesTallied();
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    
    uint private winningProposalId;
    Proposal[] public proposals;
    // uint proposalRegistrationStartTime;
    // uint proposalRegistrationEndTime;
    // uint votingSessionStartTime;
    // uint votingSessionEndTime;
    // uint tallingTime;
    address private _owner;
    
    bool votersRegistrationOver = false;
    bool proposalsRegistrationOver = false;
    bool votingTimeOver = false;
    bool votesCounted = false;
    uint votersCount;
    
    
    constructor () {
        whitelist[msg.sender].isRegistered = true;
        votersCount = 1;

        // proposalRegistrationStartTime = block.timestamp + 10;         // 10 seconds after contract has been deployed
        // proposalRegistrationEndTime   = proposalRegistrationStartTime + 1 minutes;   // 2 min after registration started
        // votingSessionStartTime = proposalRegistrationEndTime + 10;
        // votingSessionEndTime = votingSessionStartTime + 1 minutes;
        // tallingTime = votingSessionEndTime + 10;
    }
    
    function b_votersRegistrationTermination() public onlyOwner{
        require(votersCount>2,"Please add at least 1 voter!");
        votersRegistrationOver = true;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters,WorkflowStatus.ProposalsRegistrationStarted);
        emit ProposalsRegistrationStarted();
        updateVoteStatus();
    }
    
    function d_proposalsRegistrationTermination() public onlyOwner{
        require(proposals.length!=0,"Please add more proposals!");
        proposalsRegistrationOver = true;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted,WorkflowStatus.ProposalsRegistrationEnded);
        emit ProposalsRegistrationEnded();
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded,WorkflowStatus.VotingSessionStarted);
        emit VotingSessionStarted();
        updateVoteStatus();
    }
    
    function f_votingTimeTermination() public onlyOwner{
        votingTimeOver = true;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted,WorkflowStatus.VotingSessionEnded);
        emit VotingSessionEnded();
        updateVoteStatus();
    }
    
    function updateVoteStatus() private {
        //WorkflowStatus voteStatus;
        
        //if (block.timestamp < proposalRegistrationStartTime) voteStatus = WorkflowStatus.RegisteringVoters;
        // if (block.timestamp >= proposalRegistrationStartTime &&
        //     block.timestamp < proposalRegistrationEndTime
        // ) voteStatus = WorkflowStatus.ProposalsRegistrationStarted;
        if (votersRegistrationOver && !proposalsRegistrationOver) voteStatus = WorkflowStatus.ProposalsRegistrationStarted;
        
        // if (block.timestamp >= proposalRegistrationEndTime &&
        //     block.timestamp < votingSessionStartTime
        // ) voteStatus = WorkflowStatus.ProposalsRegistrationEnded;
        if (proposalsRegistrationOver && !votingTimeOver) voteStatus = WorkflowStatus.ProposalsRegistrationEnded;
        
        // if (block.timestamp >= votingSessionStartTime &&
        //     block.timestamp < votingSessionEndTime
        // ) voteStatus = WorkflowStatus.VotingSessionEnded;
        if (votingTimeOver) voteStatus = WorkflowStatus.VotingSessionEnded;
        
        // if (block.timestamp >= votingSessionEndTime &&
        //     block.timestamp < tallingTime
        // ) voteStatus = WorkflowStatus.VotingSessionEnded;
        
        // if (block.timestamp >= tallingTime) voteStatus = WorkflowStatus.VotesTallied;
        if (votesCounted) voteStatus = WorkflowStatus.VotesTallied;
    }
    
    function getVoteStatus() public view returns (string memory) {
        // if (voteStatus == WorkflowStatus.RegisteringVoters){ return "RegisteringVoters";}
        // else if (voteStatus == WorkflowStatus.ProposalsRegistrationStarted) {return "ProposalsRegistrationStarted";}
        // else if (voteStatus == WorkflowStatus.ProposalsRegistrationEnded) {return "ProposalsRegistrationEnded";}
        // else if (voteStatus == WorkflowStatus.VotingSessionStarted) {return "VotingSessionStarted";}
        // else if (voteStatus == WorkflowStatus.VotingSessionEnded) {return "VotingSessionEnded";}
        // else {return "VotingSessionEnded";}
        
        string[6] memory Status=[
        "RegisteringVoters",
        "ProposalsRegistrationStarted",
        "ProposalsRegistrationEnded",
        "VotingSessionStarted",
        "VotingSessionEnded",
        "VotesTallied"
        ];
        return Status[uint(voteStatus)];
    }
    
    function a_votersRegistration(address _address) public onlyOwner {
       // require(block.timestamp < proposalRegistrationEndTime, "Registration is over");
        require(!votersRegistrationOver, "Registration is over");
        require(!whitelist[_address].isRegistered, "This address is already registered");
        
        whitelist[_address].isRegistered = true;
        votersCount++;
        emit VoterRegistered(_address);
    }
    
    function c_proposalRegistration(string memory _proposal) public {
        // require(block.timestamp >= proposalRegistrationStartTime, "Proposal registration didn't start yet");
        // require(block.timestamp < proposalRegistrationEndTime, "Proposal registration is over");
        require(votersRegistrationOver && !proposalsRegistrationOver,"Proposals Registering not open!");
        require(whitelist[msg.sender].isRegistered, "You can't make a proposal cause you're not registered");
        require(whitelist[msg.sender].votedProposalId==0,"You already made a proposal!");
        
        Proposal memory newProposal = Proposal({
            description: _proposal,
            voteCount: 0
        });
        
        proposals.push(newProposal);
        // whitelist[msg.sender].votedProposalId = proposals.push(Proposal(_proposal,0))-1;
        whitelist[msg.sender].votedProposalId =  proposals.length - 1;
        
        emit ProposalRegistered( whitelist[msg.sender].votedProposalId);
    }
    
    function e_vote(uint propId) public {
        require(whitelist[msg.sender].isRegistered, "You can't vote cause you're not registered");
        // require(block.timestamp >= votingSessionStartTime, "Voting has not started yet.");
        // require(block.timestamp < votingSessionEndTime, "Voting is over");
        require(votersRegistrationOver && proposalsRegistrationOver && !votingTimeOver,"Voting time not open!");
        require(!whitelist[msg.sender].hasVoted, "You voted already");
        
        whitelist[msg.sender].votedProposalId = propId;
        whitelist[msg.sender].hasVoted = true;
        proposals[propId].voteCount++;
        
        emit Voted(msg.sender, propId);
    }
    
    function g_CountVotes() public onlyOwner {
        // require(block.timestamp > tallingTime, "Counting votes...");
        require(votersRegistrationOver && proposalsRegistrationOver && votingTimeOver,"Counting votes not open!");
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded,WorkflowStatus.VotesTallied);
        // mapping (uint => uint[]) winningProposalIds; //proposals[0].voteCount;
        for (uint index = 1; index < proposals.length; index++) {
            if (winningProposalId < proposals[index].voteCount) {
                winningProposalId = index ;
            }
            else if (winningProposalId == proposals[index].voteCount) { 
                winningProposalIds[winningProposalId].push(index) ;
            }
        }
        votesCounted = true;
        updateVoteStatus();
        emit VotesTallied();
    }
    
    function WinningProposalId() public view returns(string memory) {
        // require(block.timestamp > tallingTime + 10, "waiting for the winning proposal to be proclamed...");
        require(votesCounted,"Votes not counted yet!");
        require(winningProposalIds[winningProposalId].length==1,"Several winning proposals!");
        return proposals[winningProposalId].description;
    }

}