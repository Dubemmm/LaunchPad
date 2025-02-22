# LaunchPad

LaunchPad is a decentralized crowdfunding platform built on Stacks blockchain that enables milestone-based funding for innovative projects. The platform ensures transparency and security through smart contracts, allowing creators to receive funding in phases while protecting backers' interests.

## Features

- **Phased Funding**: Projects receive funding in multiple phases based on milestone completion
- **Secure Funds**: All funds are held in smart contracts until milestones are verified
- **Backer Protection**: Automatic refund mechanism if deadlines are missed
- **Transparent Progress**: Real-time tracking of project metrics and milestone completion
- **Decentralized Governance**: All funds and milestone verifications are managed by smart contracts

## Smart Contract Functions

### For Project Creators

1. `create-launch`
   - Initialize a new project with funding goal and timeline
   - Parameters: funding-goal, end-height, phase-count, phase-deadline
   - Returns: launch-id

2. `add-phase`
   - Add milestone details for each project phase
   - Parameters: launch-id, phase-id, details, required-funds, time-limit
   - Must be called by project creator

3. `complete-phase`
   - Mark a phase as completed
   - Parameters: launch-id, phase-id
   - Triggers fund release for the phase

### For Backers

1. `back-launch`
   - Contribute STX to a project
   - Parameters: launch-id
   - Automatically tracks contribution amount

2. `withdraw-funds`
   - Request refund if project misses deadlines
   - Parameters: launch-id
   - Available only after deadline expiration

### Read-Only Functions

1. `get-launch`
   - View project details
   - Parameters: launch-id

2. `get-phase`
   - View phase/milestone details
   - Parameters: launch-id, phase-id

3. `get-backer`
   - View contribution details
   - Parameters: launch-id, supporter

4. `get-launch-metrics`
   - View project progress metrics
   - Parameters: launch-id

5. `get-withdrawal-eligibility`
   - Check if refund is available
   - Parameters: launch-id, supporter

## Error Codes

- `ERR-UNAUTHORIZED (u100)`: Caller not authorized
- `ERR-INITIALIZED (u101)`: Already initialized
- `ERR-MISSING (u102)`: Resource not found
- `ERR-BAD-AMOUNT (u103)`: Invalid amount
- `ERR-MILESTONE-INCOMPLETE (u104)`: Milestone not completed
- `ERR-LAUNCH-ENDED (u105)`: Project has ended
- `ERR-TIME-EXPIRED (u106)`: Deadline has passed
- `ERR-NO-WITHDRAWAL (u107)`: No refund available
- `ERR-BAD-LAUNCH (u108)`: Invalid project
- `ERR-BAD-MILESTONE (u109)`: Invalid milestone

## Getting Started

### Prerequisites

- Stacks wallet
- STX tokens for deployment and interaction
- Clarity SDK for development

### Deployment

1. Clone the repository
2. Deploy the contract to Stacks blockchain
3. Initialize project parameters

### Usage Example

```clarity
;; Create a new project
(contract-call? .launchpad create-launch u1000000 u1000 u3 u900)

;; Add a phase
(contract-call? .launchpad add-phase u1 u1 "Initial prototype" u300000 u300)

;; Back a project
(contract-call? .launchpad back-launch u1)
```

## Security Considerations

- All funds are held in smart contracts
- Milestone completion must be verified before fund release
- Automatic refund mechanism protects backers
- Time-locked phases prevent premature fund release
- Phase deadlines ensure project progress

