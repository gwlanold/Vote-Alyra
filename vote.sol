// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";

//@notice Ce contrat gère un système de vote pour une petite communauté. L'administrateur qui 
//@notice déploie le contrat, est en charge d'ajouter les participants, et de démarrer et terminer 
//@notice chaque phase du processus de vote. Les participants font des propositions et les votent.

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
    
    uint votersCount; //pour compter le nb d'électeurs ajoutés
    uint votesCount; //pour compter le nb de votes
    
    
    constructor () {
        whitelist[msg.sender].isRegistered = true;
        votersCount = 1;
    }
    
    //@notice L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
    function A_votersRegistration(address _address) public onlyOwner {
        require(voteStatus==WorkflowStatus.RegisteringVoters, "Registration is over");
        require(!whitelist[_address].isRegistered, "This address is already registered");
        whitelist[_address].isRegistered = true;
        votersCount++;
        emit VoterRegistered(_address);
    }
    
    //@notice L'administrateur du vote commence la session d'enregistrement des propositions.
    function B_proposalsRegistrationStart() public onlyOwner{
        require(votersCount>2,"Please add at least 1 voter!");
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters,WorkflowStatus.ProposalsRegistrationStarted);
        emit ProposalsRegistrationStarted();
        voteStatus = WorkflowStatus.ProposalsRegistrationStarted;
    }
    
    //@notice Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active.
    function C_proposalRegistration(string memory _proposal) public {
        require(keccak256(abi.encodePacked((_proposal)))!=keccak256(abi.encodePacked((""))),"Your proposal is empty!");
        require(voteStatus==WorkflowStatus.ProposalsRegistrationStarted,"Proposals registration not open!");
        require(whitelist[msg.sender].isRegistered, "You can't make a proposal cause you're not registered");
        require(whitelist[msg.sender].votedProposalId==0,"You already made a proposal!");
        
        proposals.push(Proposal(_proposal,0));

        //@dev Pour éviter que le premier proposant puisse faire plusieurs propositions 
        if (proposals.length==1) {whitelist[msg.sender].votedProposalId =  proposals.length;}
        else {whitelist[msg.sender].votedProposalId =  proposals.length-1;}
        
        emit ProposalRegistered( whitelist[msg.sender].votedProposalId);
    }
    
    //@notice L'administrateur met fin à la session d'enregistrement des propositions.
    function D_proposalsRegistrationTermination() public onlyOwner{
        require(voteStatus==WorkflowStatus.ProposalsRegistrationStarted,"Proposals registration not open!");
        require(proposals.length!=0,"Please add more proposals!");
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted,WorkflowStatus.ProposalsRegistrationEnded);
        voteStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit ProposalsRegistrationEnded();
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded,WorkflowStatus.VotingSessionStarted);
    }
    
    //@notice L'administrateur commence la session de vote.
    function E_votingTimeStart() public onlyOwner{
        require(voteStatus==WorkflowStatus.ProposalsRegistrationEnded,"Proposals registration not ended!");
        voteStatus = WorkflowStatus.VotingSessionStarted;
        emit VotingSessionStarted();
    }
    
    //@notice Les électeurs inscrits votent pour leurs propositions préférées.
    function F_vote(uint propId) public {
        require(voteStatus == WorkflowStatus.VotingSessionStarted,"Vote not open!");
        require(whitelist[msg.sender].isRegistered, "You can't vote cause you're not registered");
        require(!whitelist[msg.sender].hasVoted, "You voted already");
        
        whitelist[msg.sender].votedProposalId = propId;
        whitelist[msg.sender].hasVoted = true;
        proposals[propId].voteCount++;
        votesCount++;
        
        emit Voted(msg.sender, propId);
    }
    
    //@notice L'administrateur du vote met fin à la session de vote.
    function G_votingTimeTermination() public onlyOwner{
        require(voteStatus == WorkflowStatus.VotingSessionStarted,"Vote not open!");
        require(votesCount>0,"Nobody has voted yet!");
        voteStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted,WorkflowStatus.VotingSessionEnded);
        emit VotingSessionEnded();
    }
    
    //@notice L'administrateur du vote comptabilise les votes.
    function H_CountVotes() public onlyOwner {
        require(voteStatus == WorkflowStatus.VotingSessionEnded,"Counting votes not open!");
        
        //@dev on prend en compte la possibilité de plusieurs propositions gagnantes 
        //@dev dont les indexes sont stockés dans winningProposalIds
        for (uint index = 1; index < proposals.length; index++) {
            if (proposals[winningProposalId].voteCount < proposals[index].voteCount) {
                winningProposalId = index ;
                winningProposalIds[winningProposalId].push(winningProposalId);
            }
            else if (proposals[winningProposalId].voteCount == proposals[index].voteCount) { 
                winningProposalIds[winningProposalId].push(index) ;
            }
        }
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded,WorkflowStatus.VotesTallied);
        voteStatus = WorkflowStatus.VotesTallied;
        emit VotesTallied();
    }
    
    //@notice Tout le monde peut vérifier les derniers détails de la proposition gagnante.
    function I_WinningProposalId() public view returns(uint[] memory) {
        require(voteStatus == WorkflowStatus.VotesTallied,"Votes not counted yet!");
        //@dev on retourne un tableau avec les indices des propositions gagnantes
        return winningProposalIds[winningProposalId];
    }
    
    //@dev retourne la phase du vote dans laquelle on se trouve
    function getVoteStatus() public view returns (string memory) {
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

}