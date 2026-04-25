//! Oversight mobile FFI — verifier surface only.
//!
//! Wraps the Oversight Rust core into a small, stable surface that
//! `flutter_rust_bridge` can codegen Dart bindings against.
//!
//! Hard rules:
//!   * No new cryptography here. Only orchestrates existing oversight-* crates,
//!     so the mobile result is bit-identical with `oversight verify` on desktop.
//!   * No HTTP in v0.1. Pure offline bundle verification — strongest privacy story.
//!     Network-backed Rekor lookup arrives in v0.2.


use oversight_container::SealedFile;
use oversight_manifest::Manifest;
use serde::{Deserialize, Serialize};
use thiserror::Error;

// ------------------------------------------------------------------ types

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VerifyResult {
    pub status: VerifyStatus,
    pub bundle_size_bytes: u64,
    pub manifest: ManifestSummary,
    pub signature_valid: bool,
    /// Human-readable failure reasons. Empty when status == Ok.
    pub failures: Vec<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum VerifyStatus {
    /// All checks passed.
    Ok,
    /// Bundle parsed but signature did not verify or required field missing.
    Fail,
}

/// Subset of the manifest safe to surface in a UI. We deliberately do NOT
/// surface the recipient public key in plaintext on a phone screen — only its
/// short hash form (matches the public Rekor predicate).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ManifestSummary {
    pub file_id: String,
    pub issuer_id: String,
    pub issuer_pubkey_short: String,
    pub original_filename: String,
    pub content_type: String,
    pub content_hash_short: String,
    pub size_bytes: u64,
    pub issued_at_unix: i64,
    pub suite: String,
    pub watermark_count: u64,
    pub has_recipient: bool,
}

#[derive(Debug, Error)]
pub enum FfiError {
    #[error("bundle parse failed: {0}")]
    Parse(String),
    #[error("manifest invalid: {0}")]
    Manifest(String),
}

// -------------------------------------------------------------- public API

/// Verify an Oversight `.oversight` bundle entirely offline.
///
/// `bundle_bytes` is the raw `.oversight` file (read from disk by the Flutter
/// layer and handed to us). Returns a structured result the UI renders.
///
/// This is a synchronous function — verification is pure crypto on bytes
/// already in memory, so we avoid the async / executor cost on the mobile
/// thread. Flutter callers should still invoke off the UI thread for large
/// bundles.
pub fn verify_bundle(bundle_bytes: Vec<u8>) -> VerifyResult {
    let bundle_size_bytes = bundle_bytes.len() as u64;

    let sealed = match SealedFile::from_bytes(&bundle_bytes) {
        Ok(sf) => sf,
        Err(e) => {
            return VerifyResult {
                status: VerifyStatus::Fail,
                bundle_size_bytes,
                manifest: ManifestSummary::empty(),
                signature_valid: false,
                failures: vec![format!("bundle parse failed: {}", e)],
            };
        }
    };

    let manifest_summary = ManifestSummary::from_manifest(&sealed.manifest);

    let signature_valid = match sealed.manifest.verify() {
        Ok(v) => v,
        Err(e) => {
            return VerifyResult {
                status: VerifyStatus::Fail,
                bundle_size_bytes,
                manifest: manifest_summary,
                signature_valid: false,
                failures: vec![format!("manifest verify error: {}", e)],
            };
        }
    };

    let mut failures = Vec::new();
    if !signature_valid {
        failures.push("manifest signature did not verify against issuer pubkey".to_string());
    }
    if sealed.manifest.issuer_ed25519_pub.is_empty() {
        failures.push("issuer pubkey field is empty".to_string());
    }
    if sealed.manifest.content_hash.is_empty() {
        failures.push("content_hash field is empty".to_string());
    }

    let status = if failures.is_empty() {
        VerifyStatus::Ok
    } else {
        VerifyStatus::Fail
    };

    VerifyResult {
        status,
        bundle_size_bytes,
        manifest: manifest_summary,
        signature_valid,
        failures,
    }
}

/// Library version, surfaced to the Flutter UI for diagnostics + bug reports.
pub fn library_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

/// FFI smoke test — verifies the toolchain wiring works end-to-end without
/// requiring any input bytes. Useful as the first call from Dart on app boot
/// so a broken native lib surfaces immediately, not on first user action.
pub fn smoke_test() -> String {
    format!("oversight-mobile-ffi v{} ok", env!("CARGO_PKG_VERSION"))
}

// ----------------------------------------------------------------- helpers

impl ManifestSummary {
    fn empty() -> Self {
        Self {
            file_id: String::new(),
            issuer_id: String::new(),
            issuer_pubkey_short: String::new(),
            original_filename: String::new(),
            content_type: String::new(),
            content_hash_short: String::new(),
            size_bytes: 0,
            issued_at_unix: 0,
            suite: String::new(),
            watermark_count: 0,
            has_recipient: false,
        }
    }

    fn from_manifest(m: &Manifest) -> Self {
        Self {
            file_id: m.file_id.clone(),
            issuer_id: m.issuer_id.clone(),
            issuer_pubkey_short: short_hex(&m.issuer_ed25519_pub),
            original_filename: m.original_filename.clone(),
            content_type: m.content_type.clone(),
            content_hash_short: short_hex(&m.content_hash),
            size_bytes: m.size_bytes,
            issued_at_unix: m.issued_at,
            suite: m.suite.clone(),
            watermark_count: m.watermarks.len() as u64,
            has_recipient: m.recipient.is_some(),
        }
    }
}

/// "abc123...def456" — collapse a long hex string to first8...last8 for UI.
fn short_hex(s: &str) -> String {
    if s.len() <= 16 {
        return s.to_string();
    }
    format!("{}…{}", &s[..8], &s[s.len() - 8..])
}

// ----------------------------------------------------------------- tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_empty_bytes() {
        let r = verify_bundle(vec![]);
        assert_eq!(r.status, VerifyStatus::Fail);
        assert_eq!(r.bundle_size_bytes, 0);
        assert!(!r.failures.is_empty());
        assert!(r.failures[0].contains("bundle parse failed"));
    }

    #[test]
    fn rejects_garbage_bytes() {
        let r = verify_bundle(vec![0u8; 32]);
        assert_eq!(r.status, VerifyStatus::Fail);
        assert!(!r.failures.is_empty());
    }

    #[test]
    fn rejects_wrong_magic() {
        // 32 bytes that look just enough to fail at the magic check
        let mut buf = vec![b'X'; 32];
        buf[0..6].copy_from_slice(b"OSGT\x02\x00"); // bad version byte
        let r = verify_bundle(buf);
        assert_eq!(r.status, VerifyStatus::Fail);
    }

    #[test]
    fn smoke_returns_version() {
        let s = smoke_test();
        assert!(s.starts_with("oversight-mobile-ffi v"));
        assert!(s.ends_with(" ok"));
    }

    #[test]
    fn library_version_matches_cargo() {
        assert_eq!(library_version(), env!("CARGO_PKG_VERSION"));
    }

    #[test]
    fn short_hex_collapses_long() {
        assert_eq!(
            short_hex("0123456789abcdef0123456789abcdef"),
            "01234567…89abcdef"
        );
    }

    #[test]
    fn short_hex_passes_through_short() {
        assert_eq!(short_hex("abc"), "abc");
        assert_eq!(short_hex(""), "");
    }

    #[test]
    fn manifest_summary_empty_is_safe() {
        let m = ManifestSummary::empty();
        assert!(m.file_id.is_empty());
        assert_eq!(m.size_bytes, 0);
        assert!(!m.has_recipient);
    }

    /// End-to-end: build a real bundle with the same crates the desktop CLI
    /// uses, then verify it through our FFI surface. This is the proof of the
    /// "bit-identical with desktop" claim.
    #[test]
    fn verifies_real_bundle_round_trip() {
        let (blob, _issuer_pub) = build_real_bundle("hello.txt", b"hello oversight mobile", "issuer-1");
        let r = verify_bundle(blob);
        assert_eq!(r.status, VerifyStatus::Ok, "failures: {:?}", r.failures);
        assert!(r.signature_valid);
        assert_eq!(r.manifest.issuer_id, "issuer-1");
        assert_eq!(r.manifest.original_filename, "hello.txt");
        assert!(r.manifest.has_recipient);
        assert_eq!(r.failures.len(), 0);
    }

    /// Tamper with the manifest signature in the sealed bytes and confirm
    /// the verifier flags it.
    #[test]
    fn rejects_tampered_signature() {
        let (blob, _) = build_real_bundle("tamper.txt", b"tamper me", "issuer-2");
        let mut sf = SealedFile::from_bytes(&blob).expect("parse");
        sf.manifest.signature_ed25519 = "00".repeat(64); // valid hex, wrong sig
        let bad_blob = sf.to_bytes().expect("re-encode");

        let r = verify_bundle(bad_blob);
        assert_eq!(r.status, VerifyStatus::Fail);
        assert!(!r.signature_valid);
        assert!(
            r.failures.iter().any(|f| f.contains("did not verify")),
            "expected verify failure, got: {:?}",
            r.failures
        );
    }

    // Helper: build a fully signed + sealed bundle using the real crates.
    fn build_real_bundle(
        filename: &str,
        plaintext: &[u8],
        issuer_id: &str,
    ) -> (Vec<u8>, [u8; 32]) {
        use oversight_container::seal;
        use oversight_crypto::{content_hash, ClassicIdentity};
        use oversight_manifest::{Manifest, Recipient};

        let issuer = ClassicIdentity::generate();
        let recipient_id = ClassicIdentity::generate();
        let issuer_pub = issuer.ed25519_pub;
        let issuer_priv: [u8; 32] = *issuer.ed25519_priv;

        let recipient = Recipient {
            recipient_id: "alice".into(),
            x25519_pub: hex::encode(recipient_id.x25519_pub),
            ed25519_pub: Some(hex::encode(recipient_id.ed25519_pub)),
        };

        let mut manifest = Manifest::new(
            filename,
            content_hash(plaintext),
            plaintext.len() as u64,
            issuer_id,
            hex::encode(issuer.ed25519_pub),
            recipient,
            "https://example.invalid",
            "text/plain",
            None,
            None,
            "test",
        );
        manifest.sign(&issuer_priv).expect("manifest sign");

        let blob = seal(
            plaintext,
            &mut manifest,
            &issuer_priv,
            &recipient_id.x25519_pub,
        )
        .expect("seal");

        (blob, issuer_pub)
    }
}
