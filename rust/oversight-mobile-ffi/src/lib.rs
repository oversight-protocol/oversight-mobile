//! Oversight mobile FFI — verifier surface only.
//!
//! Wraps the Oversight Rust core into a small, stable async surface that
//! `flutter_rust_bridge` can codegen Dart bindings against.
//!
//! Hard rule: this crate adds zero new cryptography. It only orchestrates
//! existing oversight-* crates so the mobile result is bit-identical with
//! `oversight verify` on desktop.

use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Serialize, Deserialize)]
pub struct VerifyResult {
    pub status: VerifyStatus,
    pub bundle_digest_b64: String,
    pub manifest_summary: ManifestSummary,
    pub rekor: Option<RekorAttestation>,
    pub watermark_present: bool,
    pub policy_decision: PolicyDecision,
    pub failures: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum VerifyStatus {
    Ok,
    Warn,
    Fail,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ManifestSummary {
    pub issuer: String,
    pub recipient_hash_b64: String,
    pub created_unix: u64,
    pub predicate_uri: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RekorAttestation {
    pub log_index: u64,
    pub log_url: String,
    pub inclusion_verified: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum PolicyDecision {
    Pass,
    SoftWarn(String),
    HardFail(String),
}

#[derive(Debug, Error)]
pub enum FfiError {
    #[error("bundle parse failed: {0}")]
    Parse(String),
    #[error("signature verification failed: {0}")]
    Signature(String),
    #[error("rekor fetch failed: {0}")]
    Rekor(String),
    #[error("network error: {0}")]
    Network(String),
}

/// Verify an Oversight `.oversight` bundle.
///
/// `bundle_bytes` is the entire serialized bundle as read from disk or QR.
/// `fetch_rekor` controls whether to actually contact the public Rekor log;
/// callers may set false for offline-only verification.
pub async fn verify_bundle(
    _bundle_bytes: Vec<u8>,
    _fetch_rekor: bool,
) -> Result<VerifyResult, FfiError> {
    // TODO(verifier): wire to oversight_container::parse + oversight_manifest::verify
    //                 + oversight_rekor::fetch_and_verify + oversight_watermark::check
    //                 + oversight_policy::evaluate
    // Placeholder so flutter_rust_bridge can codegen the Dart side first.
    todo!("implement verifier orchestration in next session")
}

/// Verify just a content hash against Rekor — used for the QR / paste-hash flow
/// where we don't have a full bundle, only a digest.
pub async fn verify_hash_in_rekor(
    _content_hash_b64: String,
) -> Result<Option<RekorAttestation>, FfiError> {
    todo!("implement rekor lookup in next session")
}

/// Library version, surfaced to the Flutter UI for diagnostics.
pub fn library_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}
