;; LaunchPad - Milestone-based Innovation Funding Platform
;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INITIALIZED (err u101))
(define-constant ERR-MISSING (err u102))
(define-constant ERR-BAD-AMOUNT (err u103))
(define-constant ERR-MILESTONE-INCOMPLETE (err u104))
(define-constant ERR-LAUNCH-ENDED (err u105))
(define-constant ERR-TIME-EXPIRED (err u106))
(define-constant ERR-NO-WITHDRAWAL (err u107))
(define-constant ERR-BAD-LAUNCH (err u108))
(define-constant ERR-BAD-MILESTONE (err u109))

;; Data maps
(define-map launches 
    { launch-id: uint }
    {
        creator: principal,
        funding-goal: uint,
        raised-amount: uint,
        end-height: uint,
        phase-count: uint,
        status-active: bool,
        final-phase-deadline: uint,
        completed-phases: uint
    }
)

(define-map phases
    { launch-id: uint, phase-id: uint }
    {
        details: (string-ascii 256),
        required-funds: uint,
        is-complete: bool,
        funds-disbursed: bool,
        time-limit: uint,
        completion-height: uint
    }
)

(define-map backers
    { launch-id: uint, supporter: principal }
    { 
        backed-amount: uint,
        withdrew-funds: bool
    }
)

(define-map launch-metrics
    { launch-id: uint }
    {
        disbursed-amount: uint,
        backer-count: uint,
        last-phase-completion: uint
    }
)

;; Launch counter
(define-data-var launch-counter uint u0)

;; Helper functions for validation
(define-private (is-valid-launch (launch-id uint))
    (is-some (map-get? launches { launch-id: launch-id }))
)

(define-private (is-valid-phase (launch-id uint) (phase-id uint))
    (and
        (is-valid-launch launch-id)
        (let ((launch (unwrap! (map-get? launches { launch-id: launch-id }) false)))
            (<= phase-id (get phase-count launch))
        )
    )
)

;; Administrative Functions
(define-public (create-launch (funding-goal uint) (end-height uint) (phase-count uint) (phase-deadline uint))
    (let
        (
            (launch-id (+ (var-get launch-counter) u1))
        )
        (asserts! (> funding-goal u0) ERR-BAD-AMOUNT)
        (asserts! (> end-height block-height) ERR-BAD-AMOUNT)
        (asserts! (> phase-count u0) ERR-BAD-AMOUNT)
        (asserts! (>= phase-deadline block-height) ERR-BAD-AMOUNT)
        
        (map-set launches
            { launch-id: launch-id }
            {
                creator: tx-sender,
                funding-goal: funding-goal,
                raised-amount: u0,
                end-height: end-height,
                phase-count: phase-count,
                status-active: true,
                final-phase-deadline: phase-deadline,
                completed-phases: u0
            }
        )
        
        (map-set launch-metrics
            { launch-id: launch-id }
            {
                disbursed-amount: u0,
                backer-count: u0,
                last-phase-completion: u0
            }
        )
        
        (var-set launch-counter launch-id)
        (ok launch-id)
    )
)

(define-public (add-phase (launch-id uint) (phase-id uint) (details (string-ascii 256)) (required-funds uint) (time-limit uint))
    (let
        (
            (launch (unwrap! (map-get? launches { launch-id: launch-id }) ERR-MISSING))
        )
        (asserts! (is-valid-launch launch-id) ERR-BAD-LAUNCH)
        (asserts! (is-valid-phase launch-id phase-id) ERR-BAD-MILESTONE)
        (asserts! (is-eq (get creator launch) tx-sender) ERR-UNAUTHORIZED)
        (asserts! (> required-funds u0) ERR-BAD-AMOUNT)
        (asserts! (>= time-limit block-height) ERR-BAD-AMOUNT)
        
        (map-set phases
            { launch-id: launch-id, phase-id: phase-id }
            {
                details: details,
                required-funds: required-funds,
                is-complete: false,
                funds-disbursed: false,
                time-limit: time-limit,
                completion-height: u0
            }
        )
        (ok true)
    )
)

(define-public (back-launch (launch-id uint))
    (let
        (
            (launch (unwrap! (map-get? launches { launch-id: launch-id }) ERR-MISSING))
            (backing-amount (stx-get-balance tx-sender))
            (current-metrics (unwrap! (map-get? launch-metrics { launch-id: launch-id }) ERR-MISSING))
        )
        (asserts! (is-valid-launch launch-id) ERR-BAD-LAUNCH)
        (asserts! (get status-active launch) ERR-LAUNCH-ENDED)
        (asserts! (<= block-height (get end-height launch)) ERR-LAUNCH-ENDED)
        (asserts! (> backing-amount u0) ERR-BAD-AMOUNT)
        
        (try! (stx-transfer? backing-amount tx-sender (as-contract tx-sender)))
        
        (map-set backers
            { launch-id: launch-id, supporter: tx-sender }
            { 
                backed-amount: (+ (default-to u0 (get backed-amount (map-get? backers { launch-id: launch-id, supporter: tx-sender }))) backing-amount),
                withdrew-funds: false
            }
        )
        
        (map-set launches
            { launch-id: launch-id }
            (merge launch { raised-amount: (+ (get raised-amount launch) backing-amount) })
        )
        
        (map-set launch-metrics
            { launch-id: launch-id }
            (merge current-metrics { backer-count: (+ (get backer-count current-metrics) u1) })
        )
        
        (ok true)
    )
)

(define-public (complete-phase (launch-id uint) (phase-id uint))
    (let
        (
            (launch (unwrap! (map-get? launches { launch-id: launch-id }) ERR-MISSING))
            (phase (unwrap! (map-get? phases { launch-id: launch-id, phase-id: phase-id }) ERR-MISSING))
            (current-metrics (unwrap! (map-get? launch-metrics { launch-id: launch-id }) ERR-MISSING))
        )
        (asserts! (is-valid-launch launch-id) ERR-BAD-LAUNCH)
        (asserts! (is-valid-phase launch-id phase-id) ERR-BAD-MILESTONE)
        (asserts! (get status-active launch) ERR-LAUNCH-ENDED)
        (asserts! (is-eq (get creator launch) tx-sender) ERR-UNAUTHORIZED)
        (asserts! (not (get is-complete phase)) ERR-MILESTONE-INCOMPLETE)
        (asserts! (<= block-height (get time-limit phase)) ERR-TIME-EXPIRED)
        
        (map-set phases
            { launch-id: launch-id, phase-id: phase-id }
            (merge phase { 
                is-complete: true,
                completion-height: block-height
            })
        )
        
        (map-set launches
            { launch-id: launch-id }
            (merge launch { 
                completed-phases: (+ (get completed-phases launch) u1)
            })
        )
        
        (map-set launch-metrics
            { launch-id: launch-id }
            (merge current-metrics { last-phase-completion: block-height })
        )
        
        (ok true)
    )
)

(define-public (disburse-phase-funds (launch-id uint) (phase-id uint))
    (let
        (
            (launch (unwrap! (map-get? launches { launch-id: launch-id }) ERR-MISSING))
            (phase (unwrap! (map-get? phases { launch-id: launch-id, phase-id: phase-id }) ERR-MISSING))
            (current-metrics (unwrap! (map-get? launch-metrics { launch-id: launch-id }) ERR-MISSING))
        )
        (asserts! (is-valid-launch launch-id) ERR-BAD-LAUNCH)
        (asserts! (is-valid-phase launch-id phase-id) ERR-BAD-MILESTONE)
        (asserts! (get status-active launch) ERR-LAUNCH-ENDED)
        (asserts! (get is-complete phase) ERR-MILESTONE-INCOMPLETE)
        (asserts! (not (get funds-disbursed phase)) ERR-MILESTONE-INCOMPLETE)
        
        (try! (as-contract (stx-transfer? (get required-funds phase) tx-sender (get creator launch))))
        
        (map-set phases
            { launch-id: launch-id, phase-id: phase-id }
            (merge phase { funds-disbursed: true })
        )
        
        (map-set launch-metrics
            { launch-id: launch-id }
            (merge current-metrics { 
                disbursed-amount: (+ (get disbursed-amount current-metrics) (get required-funds phase))
            })
        )
        
        (ok true)
    )
)

(define-public (withdraw-funds (launch-id uint))
    (let
        (
            (launch (unwrap! (map-get? launches { launch-id: launch-id }) ERR-MISSING))
            (backing (unwrap! (map-get? backers { launch-id: launch-id, supporter: tx-sender }) ERR-MISSING))
            (final-phase (unwrap! (map-get? phases { launch-id: launch-id, phase-id: (get phase-count launch) }) ERR-MISSING))
        )
        (asserts! (is-valid-launch launch-id) ERR-BAD-LAUNCH)
        (asserts! (or
            (> block-height (get final-phase-deadline launch))
            (> block-height (get time-limit final-phase))
        ) ERR-NO-WITHDRAWAL)
        (asserts! (not (get withdrew-funds backing)) ERR-NO-WITHDRAWAL)
        
        (try! (as-contract (stx-transfer? (get backed-amount backing) tx-sender tx-sender)))
        
        (map-set backers
            { launch-id: launch-id, supporter: tx-sender }
            (merge backing { withdrew-funds: true })
        )
        
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-launch (launch-id uint))
    (map-get? launches { launch-id: launch-id })
)

(define-read-only (get-phase (launch-id uint) (phase-id uint))
    (map-get? phases { launch-id: launch-id, phase-id: phase-id })
)

(define-read-only (get-backer (launch-id uint) (supporter principal))
    (map-get? backers { launch-id: launch-id, supporter: supporter })
)

(define-read-only (get-launch-metrics (launch-id uint))
    (map-get? launch-metrics { launch-id: launch-id })
)

(define-read-only (get-withdrawal-eligibility (launch-id uint) (supporter principal))
    (let
        (
            (launch (unwrap! (map-get? launches { launch-id: launch-id }) ERR-MISSING))
            (backing (unwrap! (map-get? backers { launch-id: launch-id, supporter: supporter }) ERR-MISSING))
            (final-phase (unwrap! (map-get? phases { launch-id: launch-id, phase-id: (get phase-count launch) }) ERR-MISSING))
        )
        (ok (and
            (not (get withdrew-funds backing))
            (or
                (> block-height (get final-phase-deadline launch))
                (> block-height (get time-limit final-phase))
            )
        ))
    )
)