// ========================================
// CONSTANTS
// lib/classroom/constants.ak
// System-wide constants and configuration
// ========================================

// ========================================
// AMOUNT CONSTANTS (in lovelaces)
// ========================================

/// Minimum ADA locked in escrow (2 ADA)
pub const min_escrow_amount: Int = 2_000_000

/// Minimum ADA for reputation UTXO (2 ADA)
pub const min_reputation_ada: Int = 2_000_000

/// Minimum ADA for NFT output (1.5 ADA)
pub const min_nft_ada: Int = 1_500_000

/// Maximum escrow amount (100,000 ADA)
pub const max_escrow_amount: Int = 100_000_000_000

// ========================================
// TIME CONSTANTS (in milliseconds)
// ========================================

/// Minimum refund deadline (1 day)
pub const min_refund_deadline: Int = 86_400_000 // 24 hours

/// Maximum refund deadline (365 days)
pub const max_refund_deadline: Int = 31_536_000_000 // 1 year

/// Default refund deadline (30 days)
pub const default_refund_deadline: Int = 2_592_000_000 // 30 days

// ========================================
// RATING CONSTANTS
// ========================================

/// Minimum rating value
pub const min_rating: Int = 1

/// Maximum rating value
pub const max_rating: Int = 5

/// Default initial rating
pub const initial_rating: Int = 0

/// Minimum ratings for verified status
pub const min_verified_ratings: Int = 5

// ========================================
// NFT CONSTANTS
// ========================================

/// NFT asset name prefix
pub const nft_prefix: ByteArray = "CLASSROOM_"

/// Maximum classroom ID length
pub const max_classroom_id_length: Int = 32

/// Minimum classroom ID length
pub const min_classroom_id_length: Int = 3

// ========================================
// SYSTEM LIMITS
// ========================================

/// Maximum students per classroom
pub const max_students_per_classroom: Int = 100

/// Maximum classrooms per teacher
pub const max_classrooms_per_teacher: Int = 50

/// Maximum active escrows per student
pub const max_active_escrows: Int = 10

// ========================================
// FEE CONSTANTS
// ========================================

/// Platform fee percentage (2%)
pub const platform_fee_percentage: Int = 2

/// Transaction fee buffer (0.5 ADA)
pub const tx_fee_buffer: Int = 500_000

// ========================================
// VERSION CONSTANTS
// ========================================

/// Contract version
pub const contract_version: Int = 1

/// Minimum compatible version
pub const min_compatible_version: Int = 1

// ========================================
// DATUM CONSTANTS
// ========================================

/// Initial reputation version
pub const initial_reputation_version: Int = 0

/// Initial rating sum
pub const initial_rating_sum: Int = 0

/// Initial rating count
pub const initial_rating_count: Int = 0

// ========================================
// VALIDATION CONSTANTS
// ========================================

/// Minimum transaction signers required
pub const min_signers_required: Int = 1

/// Maximum multi-sig signers
pub const max_multisig_signers: Int = 5

// ========================================
// STRING CONSTANTS
// ========================================

/// Error message: Invalid rating
pub const error_invalid_rating: ByteArray = "Rating must be between 1 and 5"

/// Error message: Insufficient funds
pub const error_insufficient_funds: ByteArray = "Insufficient funds"

/// Error message: Deadline not passed
pub const error_deadline_not_passed: ByteArray = "Refund deadline not reached"

/// Error message: Missing signature
pub const error_missing_signature: ByteArray = "Required signature missing"

/// Error message: NFT not owned
pub const error_nft_not_owned: ByteArray = "Teacher does not own classroom NFT"