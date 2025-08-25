;; BrewingChain: Craft Brewing and Beer Mastery Reward System
;; Version: 1.0.0

;; Constants
(define-constant BREWERY_CAPACITY u2400000)
(define-constant BASE_BREWING_REWARD u30)
(define-constant CRAFT_BONUS u12)
(define-constant MAX_BREWER_LEVEL u16)
(define-constant ERR_INVALID_BREWING_ACTIVITY u1)
(define-constant ERR_NO_BREWING_TOKENS u2)
(define-constant ERR_BREWERY_CAPACITY_EXCEEDED u3)
(define-constant BLOCKS_PER_BREWING_SEASON u2016)
(define-constant YEAST_PRESERVATION_MULTIPLIER u6)
(define-constant MIN_PRESERVATION_PERIOD u1008)
(define-constant EARLY_BREWING_PENALTY u18)

;; Data Variables
(define-data-var total-brewing-tokens-distributed uint u0)
(define-data-var total-brewing-activities uint u0)
(define-data-var brewery-supervisor principal tx-sender)

;; Data Maps
(define-map brewer-activities principal uint)
(define-map brewer-brewing-tokens principal uint)
(define-map brewing-activity-start-time principal uint)
(define-map brewer-craft-level principal uint)
(define-map brewer-last-activity principal uint)
(define-map brewer-preserved-yeast principal uint)
(define-map brewer-preservation-start-block principal uint)
(define-map beer-style-specialty principal uint)
(define-map brewer-recipe-count principal uint)
(define-map fermentation-mastery principal uint)

;; Public Functions
(define-public (start-brewing-batch (fermentation-time uint) (beer-style uint))
  (let
    (
      (brewer tx-sender)
    )
    (asserts! (and (> fermentation-time u0) (> beer-style u0) (<= beer-style u20)) (err ERR_INVALID_BREWING_ACTIVITY))
    (map-set brewing-activity-start-time brewer burn-block-height)
    (map-set beer-style-specialty brewer beer-style)
    (ok true)
  ))

(define-public (complete-brewing-batch (fermentation-time uint) (quality-rating uint))
  (let
    (
      (brewer tx-sender)
      (start-block (default-to u0 (map-get? brewing-activity-start-time brewer)))
      (blocks-brewing (- burn-block-height start-block))
      (last-activity-block (default-to u0 (map-get? brewer-last-activity brewer)))
      (craft-level (default-to u0 (map-get? brewer-craft-level brewer)))
      (capped-craft (if (<= craft-level MAX_BREWER_LEVEL) craft-level MAX_BREWER_LEVEL))
      (fermentation-bonus (default-to u0 (map-get? fermentation-mastery brewer)))
      (quality-bonus (/ (* quality-rating u10) u100))
      (brewing-reward (+ BASE_BREWING_REWARD (* capped-craft CRAFT_BONUS) fermentation-bonus quality-bonus))
    )
    (asserts! (and (> start-block u0) (>= blocks-brewing fermentation-time) (<= quality-rating u100)) (err ERR_INVALID_BREWING_ACTIVITY))
    
    (map-set brewer-activities brewer (+ (default-to u0 (map-get? brewer-activities brewer)) u1))
    (map-set brewer-brewing-tokens brewer (+ (default-to u0 (map-get? brewer-brewing-tokens brewer)) brewing-reward))
    
    (if (< (- burn-block-height last-activity-block) BLOCKS_PER_BREWING_SEASON)
      (map-set brewer-craft-level brewer (+ craft-level u1))
      (map-set brewer-craft-level brewer u1)
    )
    
    (if (>= quality-rating u85)
      (begin
        (map-set brewer-recipe-count brewer (+ (default-to u0 (map-get? brewer-recipe-count brewer)) u1))
        (map-set fermentation-mastery brewer (+ fermentation-bonus u5))
      )
      true
    )
    
    (map-set brewer-last-activity brewer burn-block-height)
    (var-set total-brewing-activities (+ (var-get total-brewing-activities) u1))
    (var-set total-brewing-tokens-distributed (+ (var-get total-brewing-tokens-distributed) brewing-reward))
    
    (asserts! (<= (var-get total-brewing-tokens-distributed) BREWERY_CAPACITY) (err ERR_BREWERY_CAPACITY_EXCEEDED))
    (ok brewing-reward)
  ))

(define-public (claim-brewing-rewards)
  (let
    (
      (brewer tx-sender)
      (token-balance (default-to u0 (map-get? brewer-brewing-tokens brewer)))
    )
    (asserts! (> token-balance u0) (err ERR_NO_BREWING_TOKENS))
    (map-set brewer-brewing-tokens brewer u0)
    (ok token-balance)
  ))

;; Yeast Preservation Features
(define-public (preserve-yeast (amount uint))
  (let
    (
      (brewer tx-sender)
    )
    (asserts! (> amount u0) (err ERR_INVALID_BREWING_ACTIVITY))
    (asserts! (>= (var-get total-brewing-tokens-distributed) amount) (err ERR_BREWERY_CAPACITY_EXCEEDED))
    
    (map-set brewer-preserved-yeast brewer amount)
    (map-set brewer-preservation-start-block brewer burn-block-height)
    (var-set total-brewing-tokens-distributed (- (var-get total-brewing-tokens-distributed) amount))
    (ok amount)
  ))

(define-public (release-preserved-yeast)
  (let
    (
      (brewer tx-sender)
      (preserved-amount (default-to u0 (map-get? brewer-preserved-yeast brewer)))
      (preservation-start-block (default-to u0 (map-get? brewer-preservation-start-block brewer)))
      (blocks-preserved (- burn-block-height preservation-start-block))
      (penalty (if (< blocks-preserved MIN_PRESERVATION_PERIOD) (/ (* preserved-amount EARLY_BREWING_PENALTY) u100) u0))
      (preservation-bonus (if (>= blocks-preserved MIN_PRESERVATION_PERIOD) (/ (* preserved-amount YEAST_PRESERVATION_MULTIPLIER) u100) u0))
      (final-amount (+ (- preserved-amount penalty) preservation-bonus))
    )
    (asserts! (> preserved-amount u0) (err ERR_NO_BREWING_TOKENS))
    
    (map-set brewer-preserved-yeast brewer u0)
    (map-set brewer-preservation-start-block brewer u0)
    (var-set total-brewing-tokens-distributed (+ (var-get total-brewing-tokens-distributed) final-amount))
    (ok final-amount)
  ))

(define-public (create-signature-recipe (recipe-name (string-utf8 64)) (innovation-score uint))
  (let
    (
      (brewer tx-sender)
      (craft-level (default-to u0 (map-get? brewer-craft-level brewer)))
      (recipe-count (default-to u0 (map-get? brewer-recipe-count brewer)))
      (innovation-bonus (+ BASE_BREWING_REWARD (* innovation-score u4) (* recipe-count u8)))
    )
    (asserts! (and (> (len recipe-name) u0) (>= craft-level u8) (> innovation-score u0)) (err ERR_INVALID_BREWING_ACTIVITY))
    
    (map-set brewer-brewing-tokens brewer (+ (default-to u0 (map-get? brewer-brewing-tokens brewer)) innovation-bonus))
    (var-set total-brewing-tokens-distributed (+ (var-get total-brewing-tokens-distributed) innovation-bonus))
    
    (ok innovation-bonus)
  ))

(define-public (host-tasting-event (participant-count uint) (event-duration uint))
  (let
    (
      (brewer tx-sender)
      (craft-level (default-to u0 (map-get? brewer-craft-level brewer)))
      (fermentation-mastery-level (default-to u0 (map-get? fermentation-mastery brewer)))
      (tasting-bonus (+ (* participant-count u25) (* event-duration u6) (* fermentation-mastery-level u3)))
    )
    (asserts! (and (> participant-count u0) (> event-duration u0) (>= craft-level u10)) (err ERR_INVALID_BREWING_ACTIVITY))
    
    (map-set brewer-brewing-tokens brewer (+ (default-to u0 (map-get? brewer-brewing-tokens brewer)) tasting-bonus))
    (var-set total-brewing-tokens-distributed (+ (var-get total-brewing-tokens-distributed) tasting-bonus))
    
    (ok tasting-bonus)
  ))

;; Read-Only Functions
(define-read-only (get-brewing-activity-count (user principal))
  (default-to u0 (map-get? brewer-activities user)))

(define-read-only (get-brewing-token-balance (user principal))
  (default-to u0 (map-get? brewer-brewing-tokens user)))

(define-read-only (get-craft-level (user principal))
  (default-to u0 (map-get? brewer-craft-level user)))

(define-read-only (get-recipe-count (user principal))
  (default-to u0 (map-get? brewer-recipe-count user)))

(define-read-only (get-preserved-yeast (user principal))
  (default-to u0 (map-get? brewer-preserved-yeast user)))

(define-read-only (get-fermentation-mastery (user principal))
  (default-to u0 (map-get? fermentation-mastery user)))

(define-read-only (get-brewery-stats)
  {
    total-brewing-activities: (var-get total-brewing-activities),
    total-brewing-tokens-distributed: (var-get total-brewing-tokens-distributed),
    brewery-capacity: BREWERY_CAPACITY
  })

(define-read-only (calculate-brewing-reward (craft-level uint) (quality-rating uint) (fermentation-bonus uint))
  (let
    (
      (capped-craft (if (<= craft-level MAX_BREWER_LEVEL) craft-level MAX_BREWER_LEVEL))
      (quality-bonus (/ (* quality-rating u10) u100))
    )
    (+ BASE_BREWING_REWARD (* capped-craft CRAFT_BONUS) fermentation-bonus quality-bonus)
  ))

;; Private Functions
(define-private (is-brewery-supervisor)
  (is-eq tx-sender (var-get brewery-supervisor)))

(define-private (validate-brewing-parameters (fermentation-time uint) (quality-rating uint))
  (and (> fermentation-time u0) (<= quality-rating u100)))