(define-non-fungible-token prescription-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-prescription-not-found (err u102))
(define-constant err-prescription-expired (err u103))
(define-constant err-prescription-already-dispensed (err u104))
(define-constant err-unauthorized-doctor (err u105))
(define-constant err-unauthorized-pharmacist (err u106))
(define-constant err-invalid-prescription (err u107))
(define-constant err-prescription-already-exists (err u108))
(define-constant err-insufficient-quantity (err u109))
(define-constant err-invalid-quantity (err u110))
(define-constant err-invalid-refill (err u111))
(define-constant err-prescription-locked (err u112))

(define-data-var token-id-nonce uint u1)

(define-map authorized-doctors
    principal
    bool
)
(define-map authorized-pharmacists
    principal
    bool
)

(define-map prescription-data
    uint
    {
        doctor: principal,
        patient: principal,
        drug-name: (string-ascii 64),
        dosage: (string-ascii 32),
        quantity: uint,
        remaining-quantity: uint,
        issue-date: uint,
        expiry-date: uint,
        dispensed: bool,
        dispensed-by: (optional principal),
        dispensed-at: (optional uint),
        partially-dispensed: bool,
        dispensation-count: uint,
        notes: (string-ascii 256),
    }
)

(define-map prescription-hash
    (buff 32)
    uint
)

(define-map prescription-locks
    uint
    {
        locked: bool,
        reason: (string-ascii 128),
        set-by: principal,
    }
)

(define-read-only (get-last-token-id)
    (ok (- (var-get token-id-nonce) u1))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? prescription-nft token-id))
)

(define-read-only (is-authorized-doctor (doctor principal))
    (default-to false (map-get? authorized-doctors doctor))
)

(define-read-only (is-authorized-pharmacist (pharmacist principal))
    (default-to false (map-get? authorized-pharmacists pharmacist))
)

(define-read-only (get-prescription-data (token-id uint))
    (map-get? prescription-data token-id)
)

(define-read-only (get-prescription-by-hash (hash (buff 32)))
    (match (map-get? prescription-hash hash)
        token-id (map-get? prescription-data token-id)
        none
    )
)

(define-read-only (is-prescription-valid (token-id uint))
    (match (map-get? prescription-data token-id)
        prescription-info (let (
                (current-block stacks-block-height)
                (expiry-block (get expiry-date prescription-info))
                (remaining-qty (get remaining-quantity prescription-info))
            )
            (and (< current-block expiry-block) (> remaining-qty u0))
        )
        false
    )
)

(define-read-only (get-prescription-status (token-id uint))
    (match (map-get? prescription-data token-id)
        prescription-info (let (
                (current-block stacks-block-height)
                (expiry-block (get expiry-date prescription-info))
                (is-dispensed (get dispensed prescription-info))
            )
            (if is-dispensed
                "dispensed"
                (if (>= current-block expiry-block)
                    "expired"
                    "valid"
                )
            )
        )
        "not-found"
    )
)

(define-public (authorize-doctor (doctor principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set authorized-doctors doctor true))
    )
)

(define-public (revoke-doctor (doctor principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-delete authorized-doctors doctor))
    )
)

(define-public (authorize-pharmacist (pharmacist principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set authorized-pharmacists pharmacist true))
    )
)

(define-public (revoke-pharmacist (pharmacist principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-delete authorized-pharmacists pharmacist))
    )
)

(define-public (issue-prescription
        (patient principal)
        (drug-name (string-ascii 64))
        (dosage (string-ascii 32))
        (quantity uint)
        (expiry-blocks uint)
        (notes (string-ascii 256))
        (rx-hash (buff 32))
    )
    (let (
            (token-id (var-get token-id-nonce))
            (current-block stacks-block-height)
            (expiry-date (+ current-block expiry-blocks))
        )
        (asserts! (is-authorized-doctor tx-sender) err-unauthorized-doctor)
        (asserts! (is-none (map-get? prescription-hash rx-hash))
            err-prescription-already-exists
        )
        (asserts! (> expiry-blocks u0) err-invalid-prescription)
        (asserts! (> quantity u0) err-invalid-prescription)
        (asserts! (> (len drug-name) u0) err-invalid-prescription)

        (try! (nft-mint? prescription-nft token-id patient))

        (map-set prescription-data token-id {
            doctor: tx-sender,
            patient: patient,
            drug-name: drug-name,
            dosage: dosage,
            quantity: quantity,
            remaining-quantity: quantity,
            issue-date: current-block,
            expiry-date: expiry-date,
            dispensed: false,
            dispensed-by: none,
            dispensed-at: none,
            partially-dispensed: false,
            dispensation-count: u0,
            notes: notes,
        })

        (map-set prescription-hash rx-hash token-id)

        (var-set token-id-nonce (+ token-id u1))

        (ok token-id)
    )
)

(define-public (dispense-prescription (token-id uint))
    (let (
            (prescription-info (unwrap! (map-get? prescription-data token-id)
                err-prescription-not-found
            ))
            (current-block stacks-block-height)
            (lock-entry (map-get? prescription-locks token-id))
            (is-locked (match lock-entry
                lock-data (get locked lock-data)
                false
            ))
        )
        (asserts! (is-authorized-pharmacist tx-sender)
            err-unauthorized-pharmacist
        )
        (asserts! (not is-locked) err-prescription-locked)
        (asserts! (not (get dispensed prescription-info))
            err-prescription-already-dispensed
        )
        (asserts! (< current-block (get expiry-date prescription-info))
            err-prescription-expired
        )

        (map-set prescription-data token-id
            (merge prescription-info {
                dispensed: true,
                dispensed-by: (some tx-sender),
                dispensed-at: (some current-block),
            })
        )

        (ok true)
    )
)

(define-public (partial-dispense-prescription
        (token-id uint)
        (dispense-quantity uint)
    )
    (let (
            (prescription-info (unwrap! (map-get? prescription-data token-id)
                err-prescription-not-found
            ))
            (current-block stacks-block-height)
            (remaining-qty (get remaining-quantity prescription-info))
            (new-remaining-qty (- remaining-qty dispense-quantity))
            (new-dispensation-count (+ (get dispensation-count prescription-info) u1))
            (lock-entry (map-get? prescription-locks token-id))
            (is-locked (match lock-entry
                lock-data (get locked lock-data)
                false
            ))
        )
        (asserts! (is-authorized-pharmacist tx-sender)
            err-unauthorized-pharmacist
        )
        (asserts! (not is-locked) err-prescription-locked)
        (asserts! (> remaining-qty u0) err-prescription-already-dispensed)
        (asserts! (< current-block (get expiry-date prescription-info))
            err-prescription-expired
        )
        (asserts! (> dispense-quantity u0) err-invalid-quantity)
        (asserts! (<= dispense-quantity remaining-qty) err-insufficient-quantity)

        (map-set prescription-data token-id
            (merge prescription-info {
                remaining-quantity: new-remaining-qty,
                dispensed: (is-eq new-remaining-qty u0),
                dispensed-by: (some tx-sender),
                dispensed-at: (if (is-eq new-remaining-qty u0)
                    (some current-block)
                    (get dispensed-at prescription-info)
                ),
                partially-dispensed: (> new-dispensation-count u0),
                dispensation-count: new-dispensation-count,
            })
        )

        (ok {
            dispensed-quantity: dispense-quantity,
            remaining-quantity: new-remaining-qty,
            fully-dispensed: (is-eq new-remaining-qty u0),
        })
    )
)

(define-public (verify-prescription (token-id uint))
    (match (map-get? prescription-data token-id)
        prescription-info (let (
                (current-block stacks-block-height)
                (expiry-block (get expiry-date prescription-info))
                (is-dispensed (get dispensed prescription-info))
            )
            (ok {
                valid: (and (< current-block expiry-block) (> (get remaining-quantity prescription-info) u0)),
                expired: (>= current-block expiry-block),
                dispensed: is-dispensed,
                doctor: (get doctor prescription-info),
                patient: (get patient prescription-info),
                drug-name: (get drug-name prescription-info),
                dosage: (get dosage prescription-info),
                quantity: (get quantity prescription-info),
                remaining-quantity: (get remaining-quantity prescription-info),
                issue-date: (get issue-date prescription-info),
                expiry-date: expiry-block,
                dispensed-by: (get dispensed-by prescription-info),
                dispensed-at: (get dispensed-at prescription-info),
                partially-dispensed: (get partially-dispensed prescription-info),
                dispensation-count: (get dispensation-count prescription-info),
            })
        )
        err-prescription-not-found
    )
)

(define-public (transfer
        (token-id uint)
        (sender principal)
        (recipient principal)
    )
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (asserts!
            (is-eq sender
                (unwrap! (nft-get-owner? prescription-nft token-id)
                    err-not-token-owner
                ))
            err-not-token-owner
        )
        (nft-transfer? prescription-nft token-id sender recipient)
    )
)

(define-read-only (get-remaining-quantity (token-id uint))
    (match (map-get? prescription-data token-id)
        prescription-info (ok (get remaining-quantity prescription-info))
        err-prescription-not-found
    )
)

(define-read-only (get-dispensation-history (token-id uint))
    (match (map-get? prescription-data token-id)
        prescription-info (ok {
            original-quantity: (get quantity prescription-info),
            remaining-quantity: (get remaining-quantity prescription-info),
            dispensed-quantity: (- (get quantity prescription-info)
                (get remaining-quantity prescription-info)
            ),
            dispensation-count: (get dispensation-count prescription-info),
            partially-dispensed: (get partially-dispensed prescription-info),
            fully-dispensed: (get dispensed prescription-info),
        })
        err-prescription-not-found
    )
)

(define-read-only (get-prescription-count)
    (ok (- (var-get token-id-nonce) u1))
)

(define-read-only (is-prescription-owner
        (token-id uint)
        (owner principal)
    )
    (is-eq (nft-get-owner? prescription-nft token-id) (some owner))
)

(define-read-only (get-prescription-details (token-id uint))
    (match (map-get? prescription-data token-id)
        prescription-info (let (
                (current-block stacks-block-height)
                (expiry-block (get expiry-date prescription-info))
                (is-dispensed (get dispensed prescription-info))
                (is-expired (>= current-block expiry-block))
            )
            (some {
                token-id: token-id,
                doctor: (get doctor prescription-info),
                patient: (get patient prescription-info),
                drug-name: (get drug-name prescription-info),
                dosage: (get dosage prescription-info),
                quantity: (get quantity prescription-info),
                remaining-quantity: (get remaining-quantity prescription-info),
                issue-date: (get issue-date prescription-info),
                expiry-date: expiry-block,
                dispensed: is-dispensed,
                dispensed-by: (get dispensed-by prescription-info),
                dispensed-at: (get dispensed-at prescription-info),
                partially-dispensed: (get partially-dispensed prescription-info),
                dispensation-count: (get dispensation-count prescription-info),
                notes: (get notes prescription-info),
                status: (if is-dispensed
                    "dispensed"
                    (if is-expired
                        "expired"
                        (if (get partially-dispensed prescription-info)
                            "partially-dispensed"
                            "valid"
                        )
                    )
                ),
                valid: (and (not is-expired) (> (get remaining-quantity prescription-info) u0)),
            })
        )
        none
    )
)

(define-public (update-prescription-notes
        (token-id uint)
        (new-notes (string-ascii 256))
    )
    (let ((prescription-info (unwrap! (map-get? prescription-data token-id) err-prescription-not-found)))
        (asserts! (is-eq tx-sender (get doctor prescription-info))
            err-unauthorized-doctor
        )
        (asserts! (not (get dispensed prescription-info))
            err-prescription-already-dispensed
        )

        (map-set prescription-data token-id
            (merge prescription-info { notes: new-notes })
        )

        (ok true)
    )
)

(define-public (cancel-prescription (token-id uint))
    (let ((prescription-info (unwrap! (map-get? prescription-data token-id) err-prescription-not-found)))
        (asserts! (is-eq tx-sender (get doctor prescription-info))
            err-unauthorized-doctor
        )
        (asserts! (not (get dispensed prescription-info))
            err-prescription-already-dispensed
        )

        (map-set prescription-data token-id
            (merge prescription-info { expiry-date: stacks-block-height })
        )

        (ok true)
    )
)

(define-public (refill-prescription
        (token-id uint)
        (additional-quantity uint)
        (extend-blocks uint)
    )
    (let (
            (prescription-info (unwrap! (map-get? prescription-data token-id)
                err-prescription-not-found
            ))
            (current-block stacks-block-height)
            (current-expiry (get expiry-date prescription-info))
            (current-remaining (get remaining-quantity prescription-info))
            (has-increment (> additional-quantity u0))
            (has-extension (> extend-blocks u0))
        )
        (asserts! (is-eq tx-sender (get doctor prescription-info))
            err-unauthorized-doctor
        )
        (asserts! (not (get dispensed prescription-info))
            err-prescription-already-dispensed
        )
        (asserts! (< current-block current-expiry) err-prescription-expired)
        (asserts! (or has-increment has-extension) err-invalid-refill)
        (let (
                (new-remaining (+ current-remaining additional-quantity))
                (new-expiry (if has-extension
                    (+ current-expiry extend-blocks)
                    current-expiry
                ))
            )
            (map-set prescription-data token-id
                (merge prescription-info {
                    remaining-quantity: new-remaining,
                    expiry-date: new-expiry,
                })
            )
            (ok {
                remaining-quantity: new-remaining,
                expiry-date: new-expiry,
            })
        )
    )
)

(define-read-only (get-doctor-prescription-count (doctor principal))
    (let ((max-id (var-get token-id-nonce)))
        (fold count-doctor-prescriptions (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) {
            doctor: doctor,
            count: u0,
            max-id: max-id,
        })
    )
)

(define-private (count-doctor-prescriptions
        (token-id uint)
        (data {
            doctor: principal,
            count: uint,
            max-id: uint,
        })
    )
    (if (< token-id (get max-id data))
        (match (map-get? prescription-data token-id)
            prescription-info (if (is-eq (get doctor prescription-info) (get doctor data))
                {
                    doctor: (get doctor data),
                    count: (+ (get count data) u1),
                    max-id: (get max-id data),
                }
                data
            )
            data
        )
        data
    )
)

(define-read-only (validate-prescription-integrity
        (token-id uint)
        (expected-hash (buff 32))
    )
    (match (map-get? prescription-hash expected-hash)
        stored-token-id (if (is-eq stored-token-id token-id)
            (ok true)
            (ok false)
        )
        (ok false)
    )
)

(define-read-only (get-prescription-lock (token-id uint))
    (map-get? prescription-locks token-id)
)

(define-public (lock-prescription
        (token-id uint)
        (reason (string-ascii 128))
    )
    (let ((prescription-info (unwrap! (map-get? prescription-data token-id) err-prescription-not-found)))
        (asserts! (is-eq tx-sender (get doctor prescription-info))
            err-unauthorized-doctor
        )
        (asserts! (not (get dispensed prescription-info))
            err-prescription-already-dispensed
        )

        (map-set prescription-locks token-id {
            locked: true,
            reason: reason,
            set-by: tx-sender,
        })

        (ok true)
    )
)

(define-public (unlock-prescription (token-id uint))
    (let ((prescription-info (unwrap! (map-get? prescription-data token-id) err-prescription-not-found)))
        (asserts! (is-eq tx-sender (get doctor prescription-info))
            err-unauthorized-doctor
        )

        (map-set prescription-locks token-id {
            locked: false,
            reason: "",
            set-by: tx-sender,
        })

        (ok true)
    )
)
