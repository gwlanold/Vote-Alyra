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
    
    bool votersRegistrationOver = false;
    bool proposalsRegistrationOn = false;
    bool proposalsRegistrationOver = false;
    bool votingTimeOn = false;
    bool votingTimeOver = false;
    bool votesCounted = false;
    uint votersCount; //pour compter le nb d'électeurs ajoutés
    uint votesCount; //pour compter le nb de votes
    
    
    constructor () {
        whitelist[msg.sender].isRegistered = true;
        votersCount = 1;
    }
    
    
    //@notice L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
    function A_votersRegistration(address _address) public onlyOwner {
        require(!votersRegistrationOver, "Registration is over");
        require(!whitelist[_address].isRegistered, "This address is already registered");
        
        whitelist[_address].isRegistered = true;
        votersCount++;
        emit VoterRegistered(_address);
    }
    
    //@notice 
    function B_votersRegistrationTermination() public onlyOwner{
        require(votersCount>2,"Please add at least 1 voter!");
        votersRegistrationOver = true;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters,WorkflowStatus.ProposalsRegistrationStarted);
        updateVoteStatus();
    }
     
    //@notice l'administrateur du vote commence la session d'enregistrement des propositions.
    function C_proposalsRegistrationStart() public onlyOwner{
       proposalsRegistrationOn = true;
       emit ProposalsRegistrationStarted();
       updateVoteStatus();
    }
    
    //@notice Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active.
    function D_proposalRegistration(string memory _proposal) public {
        require(proposalsRegistrationOn,"Proposals registration not open!");
        require(votersRegistrationOver && !proposalsRegistrationOver,"Proposals Registering not open!");
        require(whitelist[msg.sender].isRegistered, "You can't make a proposal cause you're not registered");
        require(whitelist[msg.sender].votedProposalId==0,"You already made a proposal!");
        
        proposals.push(Proposal(_proposal,0));

        //@dev Pour éviter que le premier proposant puisse faire plusieurs propositions 
        if (proposals.length==1) {whitelist[msg.sender].votedProposalId =  proposals.length;}
        else {whitelist[msg.sender].votedProposalId =  proposals.length-1;}
        
        emit ProposalRegistered( whitelist[msg.sender].votedProposalId);
    }
    
    //@notice L'administrateur de vote met fin à la session d'enregistrement des propositions.
    //@notice et en même temps commence la session de vote.
    function E_proposalsRegistrationTermination() public onlyOwner{
        require(proposals.length!=0,"Please add more proposals!");
        proposalsRegistrationOver = true;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted,WorkflowStatus.ProposalsRegistrationEnded);
        emit ProposalsRegistrationEnded();
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded,WorkflowStatus.VotingSessionStarted);
          updateVoteStatus();
    }
    
    function F_votingTimeStart() public onlyOwner{
       votingTimeOn = true;
       emit VotingSessionStarted();
       updateVoteStatus();
    }
    
    //@notice Les électeurs inscrits votent pour leurs propositions préférées.
    function G_vote(uint propId) public {
        require(votingTimeOn,"Vote not open yet!");
        require(whitelist[msg.sender].isRegistered, "You can't vote cause you're not registered");
        require(votersRegistrationOver && proposalsRegistrationOver && !votingTimeOver,"Voting time not open!");
        require(!whitelist[msg.sender].hasVoted, "You voted already");
        
        whitelist[msg.sender].votedProposalId = propId;
        whitelist[msg.sender].hasVoted = true;
        proposals[propId].voteCount++;
        votesCount++;
        
        emit Voted(msg.sender, propId);
    }
    
    //@notice L'administrateur du vote met fin à la session de vote.
    function H_votingTimeTermination() public onlyOwner{
        require(votesCount>0,"Nobody has voted yet!");
        votingTimeOver = true;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted,WorkflowStatus.VotingSessionEnded);
        emit VotingSessionEnded();
        updateVoteStatus();
    }
    
    //@notice L'administrateur du vote comptabilise les votes.
    function I_CountVotes() public onlyOwner {
        require(votersRegistrationOver && proposalsRegistrationOver && votingTimeOver,"Counting votes not open!");
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded,WorkflowStatus.VotesTallied);
        
        for (uint index = 1; index < proposals.length; index++) {
            if (proposals[winningProposalId].voteCount < proposals[index].voteCount) {
                winningProposalId = index ;
            }
            else if (proposals[winningProposalId].voteCount == proposals[index].voteCount) { 
                winningProposalIds[winningProposalId].push(index) ;
            }
        }
        votesCounted = true;
        updateVoteStatus();
        emit VotesTallied();
    }
    
    //@notice Tout le monde peut vérifier les derniers détails de la proposition gagnante.
    function J_WinningProposalId() public view returns(string memory) {
        require(votesCounted,"Votes not counted yet!");
        require(winningProposalIds[winningProposalId].length>1,"Several winning proposals!");
        return proposals[winningProposalId].description;
    }
    
    //@dev permet d'updater le status du vote
    function updateVoteStatus() private {
        
        if (proposalsRegistrationOn && !proposalsRegistrationOver) voteStatus = WorkflowStatus.ProposalsRegistrationStarted;
        if (proposalsRegistrationOver && !votingTimeOn) voteStatus = WorkflowStatus.ProposalsRegistrationEnded;
        if (votingTimeOn && !votingTimeOver) voteStatus = WorkflowStatus.VotingSessionStarted;
        if (votingTimeOver && !votesCounted) voteStatus = WorkflowStatus.VotingSessionEnded;
        if (votesCounted) voteStatus = WorkflowStatus.VotesTallied;
    }
    
    //@dev retourne la phase du vote dans laquelle on se trouve
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

}