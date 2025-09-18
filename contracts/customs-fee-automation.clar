(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-DECLARATION-NOT-FOUND (err u103))
(define-constant ERR-ALREADY-CLEARED (err u104))
(define-constant ERR-INVALID-CATEGORY (err u105))
(define-constant ERR-PAYMENT-FAILED (err u106))
(define-constant ERR-CURRENCY-NOT-SUPPORTED (err u107))
(define-constant ERR-INVALID-EXCHANGE-RATE (err u108))

(define-data-var contract-owner principal tx-sender)
(define-data-var customs-authority principal tx-sender)
(define-data-var declaration-counter uint u0)
(define-data-var base-currency (string-ascii 3) "STX")

(define-map duty-rates 
  { category: (string-ascii 20) } 
  { rate: uint })

(define-map declarations
  { declaration-id: uint }
  {
    importer: principal,
    goods-value: uint,
    currency: (string-ascii 3),
    stx-value: uint,
    category: (string-ascii 20),
    origin-country: (string-ascii 20),
    duty-amount: uint,
    status: (string-ascii 20),
    created-at: uint,
    cleared-at: (optional uint)
  })

(define-map user-balances
  { user: principal }
  { balance: uint })

(define-map payment-history
  { declaration-id: uint }
  {
    payer: principal,
    amount: uint,
    paid-at: uint,
    transaction-id: (optional (buff 32))
  })

(define-map exchange-rates
  { currency: (string-ascii 3) }
  { 
    rate-to-stx: uint,
    decimals: uint,
    last-updated: uint,
    is-active: bool
  })

(define-private (calculate-duty (value uint) (category (string-ascii 20)))
  (let ((rate-data (map-get? duty-rates { category: category })))
    (match rate-data
      rate-info (/ (* value (get rate rate-info)) u100)
      u0)))

(define-private (convert-to-stx (amount uint) (currency (string-ascii 3)))
  (if (is-eq currency "STX")
    amount
    (let ((exchange-data (map-get? exchange-rates { currency: currency })))
      (match exchange-data
        rate-info 
        (if (get is-active rate-info)
          (let ((rate (get rate-to-stx rate-info))
                (decimals (get decimals rate-info)))
            (/ (* amount rate) (pow u10 decimals)))
          u0)
        u0))))

(define-private (is-currency-supported (currency (string-ascii 3)))
  (or (is-eq currency "STX")
      (match (map-get? exchange-rates { currency: currency })
        rate-info (get is-active rate-info)
        false)))

(define-private (is-authorized)
  (or (is-eq tx-sender (var-get contract-owner))
      (is-eq tx-sender (var-get customs-authority))))

(define-private (get-user-balance (user principal))
  (default-to u0 
    (get balance (map-get? user-balances { user: user }))))

(define-private (set-user-balance (user principal) (amount uint))
  (map-set user-balances { user: user } { balance: amount }))

(define-private (deduct-balance (user principal) (amount uint))
  (let ((current-balance (get-user-balance user)))
    (if (>= current-balance amount)
      (begin
        (set-user-balance user (- current-balance amount))
        (ok true))
      ERR-INSUFFICIENT-FUNDS)))

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-customs-authority (new-authority principal))
  (begin
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (var-set customs-authority new-authority)
    (ok true)))

(define-public (set-duty-rate (category (string-ascii 20)) (rate uint))
  (begin
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (asserts! (<= rate u100) ERR-INVALID-AMOUNT)
    (map-set duty-rates { category: category } { rate: rate })
    (ok true)))

(define-public (deposit-funds (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let ((current-balance (get-user-balance tx-sender)))
      (set-user-balance tx-sender (+ current-balance amount))
      (ok true))))

(define-public (withdraw-funds (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let ((current-balance (get-user-balance tx-sender)))
      (asserts! (>= current-balance amount) ERR-INSUFFICIENT-FUNDS)
      (set-user-balance tx-sender (- current-balance amount))
      (ok true))))

(define-public (declare-goods 
  (goods-value uint) 
  (currency (string-ascii 3))
  (category (string-ascii 20)) 
  (origin-country (string-ascii 20)))
  (let ((declaration-id (+ (var-get declaration-counter) u1))
        (stx-value (convert-to-stx goods-value currency))
        (duty-amount (calculate-duty stx-value category)))
    (asserts! (> goods-value u0) ERR-INVALID-AMOUNT)
    (asserts! (> (len category) u0) ERR-INVALID-CATEGORY)
    (asserts! (is-currency-supported currency) ERR-CURRENCY-NOT-SUPPORTED)
    (asserts! (> stx-value u0) ERR-INVALID-EXCHANGE-RATE)
    (var-set declaration-counter declaration-id)
    (map-set declarations 
      { declaration-id: declaration-id }
      {
        importer: tx-sender,
        goods-value: goods-value,
        currency: currency,
        stx-value: stx-value,
        category: category,
        origin-country: origin-country,
        duty-amount: duty-amount,
        status: "pending",
        created-at: stacks-block-height,
        cleared-at: none
      })
    (ok declaration-id)))

(define-public (pay-customs-duty (declaration-id uint))
  (let ((declaration-data (map-get? declarations { declaration-id: declaration-id })))
    (match declaration-data
      decl-info
      (let ((duty-amount (get duty-amount decl-info))
            (current-status (get status decl-info)))
        (asserts! (is-eq (get importer decl-info) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq current-status "pending") ERR-ALREADY-CLEARED)
        (asserts! (> duty-amount u0) ERR-INVALID-AMOUNT)
        (try! (deduct-balance tx-sender duty-amount))
        (map-set declarations
          { declaration-id: declaration-id }
          (merge decl-info { status: "paid", cleared-at: (some stacks-block-height) }))
        (map-set payment-history
          { declaration-id: declaration-id }
          {
            payer: tx-sender,
            amount: duty-amount,
            paid-at: stacks-block-height,
            transaction-id: none
          })
        (ok true))
      ERR-DECLARATION-NOT-FOUND)))

(define-public (auto-pay-customs-duty (declaration-id uint))
  (let ((declaration-data (map-get? declarations { declaration-id: declaration-id })))
    (match declaration-data
      decl-info
      (let ((duty-amount (get duty-amount decl-info))
            (current-status (get status decl-info))
            (importer (get importer decl-info)))
        (asserts! (is-eq importer tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq current-status "pending") ERR-ALREADY-CLEARED)
        (asserts! (> duty-amount u0) ERR-INVALID-AMOUNT)
        (if (>= (get-user-balance importer) duty-amount)
          (begin
            (try! (deduct-balance importer duty-amount))
            (map-set declarations
              { declaration-id: declaration-id }
              (merge decl-info { status: "auto-paid", cleared-at: (some stacks-block-height) }))
            (map-set payment-history
              { declaration-id: declaration-id }
              {
                payer: importer,
                amount: duty-amount,
                paid-at: stacks-block-height,
                transaction-id: none
              })
            (ok true))
          ERR-INSUFFICIENT-FUNDS))
      ERR-DECLARATION-NOT-FOUND)))

(define-public (set-exchange-rate 
  (currency (string-ascii 3))
  (rate-to-stx uint)
  (decimals uint))
  (begin
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (asserts! (> rate-to-stx u0) ERR-INVALID-EXCHANGE-RATE)
    (asserts! (<= decimals u8) ERR-INVALID-EXCHANGE-RATE)
    (asserts! (not (is-eq currency "STX")) ERR-CURRENCY-NOT-SUPPORTED)
    (map-set exchange-rates
      { currency: currency }
      {
        rate-to-stx: rate-to-stx,
        decimals: decimals,
        last-updated: stacks-block-height,
        is-active: true
      })
    (ok true)))

(define-public (deactivate-currency (currency (string-ascii 3)))
  (begin
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq currency "STX")) ERR-CURRENCY-NOT-SUPPORTED)
    (let ((exchange-data (map-get? exchange-rates { currency: currency })))
      (match exchange-data
        rate-info
        (begin
          (map-set exchange-rates
            { currency: currency }
            (merge rate-info { is-active: false }))
          (ok true))
        ERR-CURRENCY-NOT-SUPPORTED))))

(define-public (update-declaration-status 
  (declaration-id uint) 
  (new-status (string-ascii 20)))
  (begin
    (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
    (let ((declaration-data (map-get? declarations { declaration-id: declaration-id })))
      (match declaration-data
        decl-info
        (begin
          (map-set declarations
            { declaration-id: declaration-id }
            (merge decl-info { status: new-status }))
          (ok true))
        ERR-DECLARATION-NOT-FOUND))))

(define-read-only (get-declaration (declaration-id uint))
  (map-get? declarations { declaration-id: declaration-id }))

(define-read-only (get-duty-rate (category (string-ascii 20)))
  (map-get? duty-rates { category: category }))

(define-read-only (get-balance (user principal))
  (get-user-balance user))

(define-read-only (get-payment-history (declaration-id uint))
  (map-get? payment-history { declaration-id: declaration-id }))

(define-read-only (calculate-customs-duty (value uint) (category (string-ascii 20)))
  (calculate-duty value category))

(define-read-only (get-exchange-rate (currency (string-ascii 3)))
  (map-get? exchange-rates { currency: currency }))

(define-read-only (convert-currency (amount uint) (from-currency (string-ascii 3)))
  (convert-to-stx amount from-currency))

(define-read-only (get-supported-currencies)
  (list "STX" "USD" "EUR" "GBP" "JPY" "CNY" "CAD" "AUD"))

(define-read-only (get-contract-info)
  {
    owner: (var-get contract-owner),
    customs-authority: (var-get customs-authority),
    total-declarations: (var-get declaration-counter),
    base-currency: (var-get base-currency)
  })
