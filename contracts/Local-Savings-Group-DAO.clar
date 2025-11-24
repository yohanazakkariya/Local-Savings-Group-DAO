(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1))
(define-constant ERR_MEMBER_NOT_FOUND (err u2))
(define-constant ERR_MEMBER_ALREADY_EXISTS (err u3))
(define-constant ERR_INSUFFICIENT_FUNDS (err u4))
(define-constant ERR_INVALID_AMOUNT (err u5))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u6))
(define-constant ERR_ALREADY_VOTED (err u7))
(define-constant ERR_VOTING_PERIOD_ENDED (err u8))
(define-constant ERR_PROPOSAL_NOT_APPROVED (err u9))
(define-constant ERR_LOAN_NOT_FOUND (err u10))
(define-constant ERR_LOAN_NOT_ACTIVE (err u11))
(define-constant ERR_PAUSED (err u12))
(define-constant MIN_CONTRIBUTION u1000000)
(define-constant VOTING_PERIOD u1008)
(define-constant INTEREST_RATE u10)
(define-constant INITIAL_REPUTATION u100)
(define-constant MIN_REPUTATION u0)
(define-constant MAX_REPUTATION u200)
(define-constant REPUTATION_VOTE_BONUS u5)
(define-constant REPUTATION_LOAN_PENALTY u20)
(define-constant REPUTATION_LOAN_BONUS u10)

(define-data-var next-member-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var next-loan-id uint u1)
(define-data-var total-funds uint u0)
(define-data-var total-members uint u0)
(define-data-var paused bool false)

(define-map members
    { member-id: uint }
    {
        address: principal,
        contribution: uint,
        join-height: uint,
        active: bool,
        reputation: uint,
    }
)

(define-map member-address-to-id
    { address: principal }
    { member-id: uint }
)

(define-map member-metrics
    { address: principal }
    {
        contributions: uint,
        proposals: uint,
        votes: uint,
        loans: uint,
    }
)

(define-map proposals
    { proposal-id: uint }
    {
        proposer: principal,
        proposal-type: (string-ascii 20),
        amount: uint,
        recipient: principal,
        description: (string-ascii 500),
        votes-for: uint,
        votes-against: uint,
        voting-end-height: uint,
        executed: bool,
        created-height: uint,
    }
)

(define-map proposal-votes
    {
        proposal-id: uint,
        voter: principal,
    }
    { vote: bool }
)

(define-map loans
    { loan-id: uint }
    {
        borrower: principal,
        amount: uint,
        interest-amount: uint,
        repaid-amount: uint,
        due-height: uint,
        active: bool,
        approved-height: uint,
    }
)

(define-read-only (get-member (member-id uint))
    (map-get? members { member-id: member-id })
)

(define-read-only (get-member-by-address (address principal))
    (match (map-get? member-address-to-id { address: address })
        entry (map-get? members { member-id: (get member-id entry) })
        none
    )
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-loan (loan-id uint))
    (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-member-metrics (address principal))
    (map-get? member-metrics { address: address })
)

(define-read-only (get-total-funds)
    (var-get total-funds)
)

(define-read-only (get-total-members)
    (var-get total-members)
)

(define-read-only (is-paused)
    (var-get paused)
)

(define-read-only (get-member-vote
        (proposal-id uint)
        (voter principal)
    )
    (map-get? proposal-votes {
        proposal-id: proposal-id,
        voter: voter,
    })
)

(define-public (join-group)
    (let (
            (member-id (var-get next-member-id))
            (existing-member (map-get? member-address-to-id { address: tx-sender }))
        )
        (asserts! (is-none existing-member) ERR_MEMBER_ALREADY_EXISTS)
        (try! (stx-transfer? MIN_CONTRIBUTION tx-sender (as-contract tx-sender)))
        (map-set members { member-id: member-id } {
            address: tx-sender,
            contribution: MIN_CONTRIBUTION,
            join-height: stacks-block-height,
            active: true,
            reputation: INITIAL_REPUTATION,
        })
        (map-set member-address-to-id { address: tx-sender } { member-id: member-id })
        (var-set next-member-id (+ member-id u1))
        (var-set total-members (+ (var-get total-members) u1))
        (var-set total-funds (+ (var-get total-funds) MIN_CONTRIBUTION))
        (ok member-id)
    )
)

(define-public (contribute (amount uint))
    (let (
            (member-info (unwrap! (get-member-by-address tx-sender) ERR_MEMBER_NOT_FOUND))
            (member-id-info (unwrap! (map-get? member-address-to-id { address: tx-sender })
                ERR_MEMBER_NOT_FOUND
            ))
            (member-id (get member-id member-id-info))
        )
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (get active member-info) ERR_MEMBER_NOT_FOUND)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set members { member-id: member-id }
            (merge member-info { contribution: (+ (get contribution member-info) amount) })
        )
        (var-set total-funds (+ (var-get total-funds) amount))
        (update-member-metrics tx-sender "contributions")
        (ok true)
    )
)

(define-public (create-proposal
        (proposal-type (string-ascii 20))
        (amount uint)
        (recipient principal)
        (description (string-ascii 500))
    )
    (let (
            (proposal-id (var-get next-proposal-id))
            (member-info (unwrap! (get-member-by-address tx-sender) ERR_MEMBER_NOT_FOUND))
        )
        (asserts! (get active member-info) ERR_MEMBER_NOT_FOUND)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (map-set proposals { proposal-id: proposal-id } {
            proposer: tx-sender,
            proposal-type: proposal-type,
            amount: amount,
            recipient: recipient,
            description: description,
            votes-for: u0,
            votes-against: u0,
            voting-end-height: (+ stacks-block-height VOTING_PERIOD),
            executed: false,
            created-height: stacks-block-height,
        })
        (var-set next-proposal-id (+ proposal-id u1))
        (update-member-metrics tx-sender "proposals")
        (ok proposal-id)
    )
)

(define-public (vote-on-proposal
        (proposal-id uint)
        (vote bool)
    )
    (let (
            (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
            (member-info (unwrap! (get-member-by-address tx-sender) ERR_MEMBER_NOT_FOUND))
            (existing-vote (map-get? proposal-votes {
                proposal-id: proposal-id,
                voter: tx-sender,
            }))
        )
        (asserts! (get active member-info) ERR_MEMBER_NOT_FOUND)
        (asserts! (is-none existing-vote) ERR_ALREADY_VOTED)
        (asserts! (<= stacks-block-height (get voting-end-height proposal))
            ERR_VOTING_PERIOD_ENDED
        )
        (map-set proposal-votes {
            proposal-id: proposal-id,
            voter: tx-sender,
        } { vote: vote }
        )
        (if vote
            (map-set proposals { proposal-id: proposal-id }
                (merge proposal { votes-for: (+ (get votes-for proposal) u1) })
            )
            (map-set proposals { proposal-id: proposal-id }
                (merge proposal { votes-against: (+ (get votes-against proposal) u1) })
            )
        )
        (try! (update-reputation tx-sender REPUTATION_VOTE_BONUS true))
        (update-member-metrics tx-sender "votes")
        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let (
            (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
            (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
            (majority-threshold (/ (var-get total-members) u2))
        )
        (asserts! (not (var-get paused)) ERR_PAUSED)
        (asserts! (> stacks-block-height (get voting-end-height proposal))
            ERR_VOTING_PERIOD_ENDED
        )
        (asserts! (not (get executed proposal)) ERR_PROPOSAL_NOT_APPROVED)
        (asserts! (> (get votes-for proposal) (get votes-against proposal))
            ERR_PROPOSAL_NOT_APPROVED
        )
        (asserts! (>= (get votes-for proposal) majority-threshold)
            ERR_PROPOSAL_NOT_APPROVED
        )
        (asserts! (<= (get amount proposal) (var-get total-funds))
            ERR_INSUFFICIENT_FUNDS
        )

        (if (is-eq (get proposal-type proposal) "loan")
            (try! (process-loan-proposal proposal-id proposal))
            (try! (as-contract (stx-transfer? (get amount proposal) tx-sender
                (get recipient proposal)
            )))
        )

        (map-set proposals { proposal-id: proposal-id }
            (merge proposal { executed: true })
        )
        (var-set total-funds (- (var-get total-funds) (get amount proposal)))
        (ok true)
    )
)

(define-private (process-loan-proposal
        (proposal-id uint)
        (proposal {
            proposer: principal,
            proposal-type: (string-ascii 20),
            amount: uint,
            recipient: principal,
            description: (string-ascii 500),
            votes-for: uint,
            votes-against: uint,
            voting-end-height: uint,
            executed: bool,
            created-height: uint,
        })
    )
    (let (
            (loan-id (var-get next-loan-id))
            (interest-amount (/ (* (get amount proposal) INTEREST_RATE) u100))
            (total-amount (+ (get amount proposal) interest-amount))
        )
        (map-set loans { loan-id: loan-id } {
            borrower: (get recipient proposal),
            amount: (get amount proposal),
            interest-amount: interest-amount,
            repaid-amount: u0,
            due-height: (+ stacks-block-height u4320),
            active: true,
            approved-height: stacks-block-height,
        })
        (var-set next-loan-id (+ loan-id u1))
        (update-member-metrics (get recipient proposal) "loans")
        (as-contract (stx-transfer? (get amount proposal) tx-sender (get recipient proposal)))
    )
)

(define-public (repay-loan
        (loan-id uint)
        (amount uint)
    )
    (let (
            (loan (unwrap! (get-loan loan-id) ERR_LOAN_NOT_FOUND))
            (total-due (+ (get amount loan) (get interest-amount loan)))
            (remaining-due (- total-due (get repaid-amount loan)))
        )
        (asserts! (get active loan) ERR_LOAN_NOT_ACTIVE)
        (asserts! (is-eq (get borrower loan) tx-sender) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (<= amount remaining-due) ERR_INVALID_AMOUNT)

        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (let (
                (new-repaid-amount (+ (get repaid-amount loan) amount))
                (is-fully-repaid (is-eq new-repaid-amount total-due))
            )
            (map-set loans { loan-id: loan-id }
                (merge loan {
                    repaid-amount: new-repaid-amount,
                    active: (not is-fully-repaid),
                })
            )
            (var-set total-funds (+ (var-get total-funds) amount))
            (and is-fully-repaid (is-ok (update-reputation tx-sender REPUTATION_LOAN_BONUS true)))
            (ok is-fully-repaid)
        )
    )
)

(define-public (withdraw-contribution (amount uint))
    (let (
            (member-info (unwrap! (get-member-by-address tx-sender) ERR_MEMBER_NOT_FOUND))
            (member-id-info (unwrap! (map-get? member-address-to-id { address: tx-sender })
                ERR_MEMBER_NOT_FOUND
            ))
            (member-id (get member-id member-id-info))
            (available-amount (- (get contribution member-info) MIN_CONTRIBUTION))
        )
        (asserts! (not (var-get paused)) ERR_PAUSED)
        (asserts! (get active member-info) ERR_MEMBER_NOT_FOUND)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (<= amount available-amount) ERR_INSUFFICIENT_FUNDS)
        (asserts! (<= amount (var-get total-funds)) ERR_INSUFFICIENT_FUNDS)

        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-set members { member-id: member-id }
            (merge member-info { contribution: (- (get contribution member-info) amount) })
        )
        (var-set total-funds (- (var-get total-funds) amount))
        (ok true)
    )
)

(define-public (leave-group)
    (let (
            (member-info (unwrap! (get-member-by-address tx-sender) ERR_MEMBER_NOT_FOUND))
            (member-id-info (unwrap! (map-get? member-address-to-id { address: tx-sender })
                ERR_MEMBER_NOT_FOUND
            ))
            (member-id (get member-id member-id-info))
            (withdrawal-amount (- (get contribution member-info) MIN_CONTRIBUTION))
        )
        (asserts! (not (var-get paused)) ERR_PAUSED)
        (asserts! (get active member-info) ERR_MEMBER_NOT_FOUND)
        (asserts! (<= withdrawal-amount (var-get total-funds))
            ERR_INSUFFICIENT_FUNDS
        )

        (if (> withdrawal-amount u0)
            (try! (as-contract (stx-transfer? withdrawal-amount tx-sender tx-sender)))
            true
        )

        (map-set members { member-id: member-id }
            (merge member-info { active: false })
        )
        (var-set total-members (- (var-get total-members) u1))
        (var-set total-funds (- (var-get total-funds) withdrawal-amount))
        (ok withdrawal-amount)
    )
)

(define-read-only (get-contract-balance)
    (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-member-reputation (address principal))
    (match (get-member-by-address address)
        member-info (some (get reputation member-info))
        none
    )
)

(define-private (update-reputation
        (address principal)
        (points uint)
        (is-positive bool)
    )
    (let (
            (member-info (unwrap! (get-member-by-address address) ERR_MEMBER_NOT_FOUND))
            (member-id-info (unwrap! (map-get? member-address-to-id { address: address })
                ERR_MEMBER_NOT_FOUND
            ))
            (member-id (get member-id member-id-info))
            (current-reputation (get reputation member-info))
            (new-reputation (if is-positive
                (if (> (+ current-reputation points) MAX_REPUTATION)
                    MAX_REPUTATION
                    (+ current-reputation points)
                )
                (if (< current-reputation points)
                    MIN_REPUTATION
                    (- current-reputation points)
                )
            ))
        )
        (map-set members { member-id: member-id }
            (merge member-info { reputation: new-reputation })
        )
        (ok new-reputation)
    )
)

(define-private (update-member-metrics
        (address principal)
        (field (string-ascii 16))
    )
    (let (
            (existing (default-to {
                contributions: u0,
                proposals: u0,
                votes: u0,
                loans: u0,
            }
                (map-get? member-metrics { address: address })
            ))
            (contribution-count (get contributions existing))
            (proposal-count (get proposals existing))
            (vote-count (get votes existing))
            (loan-count (get loans existing))
            (new-contributions (if (is-eq field "contributions")
                (+ contribution-count u1)
                contribution-count
            ))
            (new-proposals (if (is-eq field "proposals")
                (+ proposal-count u1)
                proposal-count
            ))
            (new-votes (if (is-eq field "votes")
                (+ vote-count u1)
                vote-count
            ))
            (new-loans (if (is-eq field "loans")
                (+ loan-count u1)
                loan-count
            ))
        )
        (map-set member-metrics { address: address } {
            contributions: new-contributions,
            proposals: new-proposals,
            votes: new-votes,
            loans: new-loans,
        })
        true
    )
)

(define-public (penalize-overdue-loan (loan-id uint))
    (let (
            (loan (unwrap! (get-loan loan-id) ERR_LOAN_NOT_FOUND))
            (borrower (get borrower loan))
        )
        (asserts! (get active loan) ERR_LOAN_NOT_ACTIVE)
        (asserts! (> stacks-block-height (get due-height loan))
            ERR_LOAN_NOT_ACTIVE
        )
        (try! (update-reputation borrower REPUTATION_LOAN_PENALTY false))
        (ok true)
    )
)

(define-read-only (get-reputation-weighted-vote (address principal))
    (match (get-member-reputation address)
        reputation (/ (* reputation u100) INITIAL_REPUTATION)
        u0
    )
)

(define-public (set-paused (value bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set paused value)
        (ok value)
    )
)
