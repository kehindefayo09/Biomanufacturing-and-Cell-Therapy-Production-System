;; Cell Line Management Contract
;; Manages cell lines, biological materials, and genetic modifications for biomanufacturing

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-CELL-LINE-EXISTS (err u101))
(define-constant ERR-CELL-LINE-NOT-FOUND (err u102))
(define-constant ERR-INVALID-INPUT (err u103))
(define-constant ERR-PASSAGE-LIMIT-EXCEEDED (err u104))
(define-constant ERR-EXPIRED-CELL-LINE (err u105))

;; Data Variables
(define-data-var next-cell-line-id uint u1)
(define-data-var next-modification-id uint u1)

;; Data Maps
(define-map cell-lines
  { cell-line-id: uint }
  {
    name: (string-ascii 100),
    cell-type: (string-ascii 50),
    origin: (string-ascii 100),
    characteristics: (string-ascii 200),
    passage-number: uint,
    max-passage: uint,
    storage-temperature: int,
    expiration-date: uint,
    created-by: principal,
    created-at: uint,
    status: (string-ascii 20)
  }
)

(define-map genetic-modifications
  { modification-id: uint }
  {
    cell-line-id: uint,
    modification-type: (string-ascii 50),
    description: (string-ascii 200),
    method: (string-ascii 100),
    performed-by: principal,
    performed-at: uint,
    verification-status: (string-ascii 20)
  }
)

(define-map custody-records
  { record-id: uint }
  {
    cell-line-id: uint,
    from-location: (string-ascii 100),
    to-location: (string-ascii 100),
    transferred-by: principal,
    received-by: principal,
    transfer-date: uint,
    condition-notes: (string-ascii 200)
  }
)

(define-map authorized-users
  { user: principal }
  { role: (string-ascii 20) }
)

;; Private Functions
(define-private (is-authorized (user principal) (required-role (string-ascii 20)))
  (match (map-get? authorized-users { user: user })
    user-data (is-eq (get role user-data) required-role)
    false
  )
)

(define-private (is-cell-line-valid (cell-line-id uint))
  (is-some (map-get? cell-lines { cell-line-id: cell-line-id }))
)

(define-private (is-passage-valid (current-passage uint) (max-passage uint))
  (<= current-passage max-passage)
)

(define-private (is-not-expired (expiration-date uint))
  (> expiration-date block-height)
)

;; Public Functions

;; Initialize contract with owner permissions
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-users
      { user: CONTRACT-OWNER }
      { role: "admin" }
    )
    (ok true)
  )
)

;; Add authorized user
(define-public (add-authorized-user (user principal) (role (string-ascii 20)))
  (begin
    (asserts! (is-authorized tx-sender "admin") ERR-NOT-AUTHORIZED)
    (asserts! (or (is-eq role "operator") (is-eq role "analyst") (is-eq role "admin")) ERR-INVALID-INPUT)
    (map-set authorized-users { user: user } { role: role })
    (ok true)
  )
)

;; Register new cell line
(define-public (register-cell-line
  (name (string-ascii 100))
  (cell-type (string-ascii 50))
  (origin (string-ascii 100))
  (characteristics (string-ascii 200))
  (max-passage uint)
  (storage-temperature int)
  (expiration-date uint))
  (let
    (
      (cell-line-id (var-get next-cell-line-id))
    )
    (asserts! (is-authorized tx-sender "operator") ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> max-passage u0) ERR-INVALID-INPUT)
    (asserts! (> expiration-date block-height) ERR-INVALID-INPUT)

    (map-set cell-lines
      { cell-line-id: cell-line-id }
      {
        name: name,
        cell-type: cell-type,
        origin: origin,
        characteristics: characteristics,
        passage-number: u1,
        max-passage: max-passage,
        storage-temperature: storage-temperature,
        expiration-date: expiration-date,
        created-by: tx-sender,
        created-at: block-height,
        status: "active"
      }
    )

    (var-set next-cell-line-id (+ cell-line-id u1))
    (ok cell-line-id)
  )
)

;; Update passage number
(define-public (update-passage (cell-line-id uint) (new-passage uint))
  (let
    (
      (cell-line (unwrap! (map-get? cell-lines { cell-line-id: cell-line-id }) ERR-CELL-LINE-NOT-FOUND))
    )
    (asserts! (is-authorized tx-sender "operator") ERR-NOT-AUTHORIZED)
    (asserts! (is-passage-valid new-passage (get max-passage cell-line)) ERR-PASSAGE-LIMIT-EXCEEDED)
    (asserts! (is-not-expired (get expiration-date cell-line)) ERR-EXPIRED-CELL-LINE)

    (map-set cell-lines
      { cell-line-id: cell-line-id }
      (merge cell-line { passage-number: new-passage })
    )
    (ok true)
  )
)

;; Add genetic modification
(define-public (add-genetic-modification
  (cell-line-id uint)
  (modification-type (string-ascii 50))
  (description (string-ascii 200))
  (method (string-ascii 100)))
  (let
    (
      (modification-id (var-get next-modification-id))
    )
    (asserts! (is-authorized tx-sender "operator") ERR-NOT-AUTHORIZED)
    (asserts! (is-cell-line-valid cell-line-id) ERR-CELL-LINE-NOT-FOUND)
    (asserts! (> (len modification-type) u0) ERR-INVALID-INPUT)

    (map-set genetic-modifications
      { modification-id: modification-id }
      {
        cell-line-id: cell-line-id,
        modification-type: modification-type,
        description: description,
        method: method,
        performed-by: tx-sender,
        performed-at: block-height,
        verification-status: "pending"
      }
    )

    (var-set next-modification-id (+ modification-id u1))
    (ok modification-id)
  )
)

;; Verify genetic modification
(define-public (verify-modification (modification-id uint) (status (string-ascii 20)))
  (let
    (
      (modification (unwrap! (map-get? genetic-modifications { modification-id: modification-id }) ERR-CELL-LINE-NOT-FOUND))
    )
    (asserts! (is-authorized tx-sender "analyst") ERR-NOT-AUTHORIZED)
    (asserts! (or (is-eq status "verified") (is-eq status "rejected")) ERR-INVALID-INPUT)

    (map-set genetic-modifications
      { modification-id: modification-id }
      (merge modification { verification-status: status })
    )
    (ok true)
  )
)

;; Record custody transfer
(define-public (record-custody-transfer
  (cell-line-id uint)
  (from-location (string-ascii 100))
  (to-location (string-ascii 100))
  (received-by principal)
  (condition-notes (string-ascii 200)))
  (let
    (
      (record-id (+ (var-get next-cell-line-id) (var-get next-modification-id)))
    )
    (asserts! (is-authorized tx-sender "operator") ERR-NOT-AUTHORIZED)
    (asserts! (is-cell-line-valid cell-line-id) ERR-CELL-LINE-NOT-FOUND)
    (asserts! (> (len from-location) u0) ERR-INVALID-INPUT)
    (asserts! (> (len to-location) u0) ERR-INVALID-INPUT)

    (map-set custody-records
      { record-id: record-id }
      {
        cell-line-id: cell-line-id,
        from-location: from-location,
        to-location: to-location,
        transferred-by: tx-sender,
        received-by: received-by,
        transfer-date: block-height,
        condition-notes: condition-notes
      }
    )
    (ok record-id)
  )
)

;; Update cell line status
(define-public (update-status (cell-line-id uint) (new-status (string-ascii 20)))
  (let
    (
      (cell-line (unwrap! (map-get? cell-lines { cell-line-id: cell-line-id }) ERR-CELL-LINE-NOT-FOUND))
    )
    (asserts! (is-authorized tx-sender "operator") ERR-NOT-AUTHORIZED)
    (asserts! (or (is-eq new-status "active") (is-eq new-status "inactive") (is-eq new-status "quarantine")) ERR-INVALID-INPUT)

    (map-set cell-lines
      { cell-line-id: cell-line-id }
      (merge cell-line { status: new-status })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get cell line details
(define-read-only (get-cell-line (cell-line-id uint))
  (map-get? cell-lines { cell-line-id: cell-line-id })
)

;; Get genetic modification details
(define-read-only (get-modification (modification-id uint))
  (map-get? genetic-modifications { modification-id: modification-id })
)

;; Get custody record
(define-read-only (get-custody-record (record-id uint))
  (map-get? custody-records { record-id: record-id })
)

;; Check if cell line is active and not expired
(define-read-only (is-cell-line-usable (cell-line-id uint))
  (match (map-get? cell-lines { cell-line-id: cell-line-id })
    cell-line (and
      (is-eq (get status cell-line) "active")
      (is-not-expired (get expiration-date cell-line))
      (is-passage-valid (get passage-number cell-line) (get max-passage cell-line))
    )
    false
  )
)

;; Get user authorization
(define-read-only (get-user-role (user principal))
  (map-get? authorized-users { user: user })
)

;; Get next available IDs
(define-read-only (get-next-cell-line-id)
  (var-get next-cell-line-id)
)

(define-read-only (get-next-modification-id)
  (var-get next-modification-id)
)
