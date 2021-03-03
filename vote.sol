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
    
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }
    
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
    uint proposalRegistrationStartTime;
    uint proposalRegistrationEndTime;
    uint votingSessionStartTime;
    uint votingSessionEndTime;
    uint tallingTime;
    address private _owner;
    
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
        
        proposalRegistrationStartTime = block.timestamp + 10;         // 10 seconds after contract has been deployed
        proposalRegistrationEndTime   = proposalRegistrationStartTime + 1 minutes;   // 2 min after registration started
        votingSessionStartTime = proposalRegistrationEndTime + 10;
        votingSessionEndTime = votingSessionStartTime + 1 minutes;
        tallingTime = votingSessionEndTime + 10;
    }
    
    function VoteStatus() public view returns(WorkflowStatus) {
        WorkflowStatus voteStatus;
        
        if (block.timestamp < proposalRegistrationStartTime) voteStatus = WorkflowStatus.RegisteringVoters;
        if (block.timestamp >= proposalRegistrationStartTime &&
            block.timestamp < proposalRegistrationEndTime
        ) voteStatus = WorkflowStatus.ProposalsRegistrationStarted;
        if (block.timestamp >= proposalRegistrationEndTime &&
            block.timestamp < votingSessionStartTime
        ) voteStatus = WorkflowStatus.ProposalsRegistrationEnded;
        if (block.timestamp >= votingSessionStartTime &&
            block.timestamp < votingSessionEndTime
        ) voteStatus = WorkflowStatus.VotingSessionEnded;
        if (block.timestamp >= votingSessionEndTime &&
            block.timestamp < tallingTime
        ) voteStatus = WorkflowStatus.VotingSessionEnded;
        if (block.timestamp >= tallingTime) voteStatus = WorkflowStatus.VotesTallied;
        
        return voteStatus;
    }
    
    function registration(address _address) public onlyOwner {
        require(block.timestamp < proposalRegistrationEndTime, "Registration is over");
        require(!whitelist[_address].isRegistered, "This address is already registered");
        
        whitelist[_address].isRegistered = true;
        
        emit VoterRegistered(_address);
    }
    
    function proposalRegistration(string memory _proposal) public {
        require(block.timestamp >= proposalRegistrationStartTime, "Proposal registration didn't start yet");
        require(block.timestamp < proposalRegistrationEndTime, "Proposal registration is over");
        require(whitelist[msg.sender].isRegistered, "You can't make a proposal cause you're not registered");
        
        Proposal memory newProposal = Proposal({
            description: _proposal,
            voteCount: 0
        });
        
        proposals.push(newProposal);
        whitelist[msg.sender].votedProposalId = proposals.length - 1;
        
        emit ProposalRegistered( proposals.length - 1);
    }
    
    function vote(uint propId) public {
        require(whitelist[msg.sender].isRegistered, "You can't vote cause you're not registered");
        require(block.timestamp >= votingSessionStartTime, "Voting has not started yet.");
        require(block.timestamp < votingSessionEndTime, "Voting is over");
        require(!whitelist[msg.sender].hasVoted, "You voted already");
        
        whitelist[msg.sender].votedProposalId = propId;
        whitelist[msg.sender].hasVoted = true;
        proposals[propId].voteCount++;
        
        emit Voted(msg.sender, propId);
    }
    
    function CountVotes() public onlyOwner {
        require(block.timestamp > tallingTime, "Counting votes...");
        
        winningProposalId = proposals[0].voteCount;
        for (uint index = 1; index < proposals.length; index++) {
            winningProposalId < proposals[index].voteCount ? winningProposalId = index : winningProposalId = winningProposalId;
            
            emit VotesTallied();
        }
    }
    
    function WinningProposalId() public view returns(uint) {
        require(block.timestamp > tallingTime + 10, "waiting for the winning proposal to be proclamed...");
        return winningProposalId;
    }

}