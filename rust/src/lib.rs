#![deny(unsafe_code)]
//! Oversight mobile FFI — verifier surface only.
//!
//! Public API lives in `api::verify`. flutter_rust_bridge_codegen scans this
//! crate and emits Dart bindings for every `pub` item under `api::`.
//!
//! Note on `unsafe`: hand-written code in this crate is unsafe-free. The FRB
//! bridge module below uses raw pointers to cross the Dart↔Rust boundary —
//! that's required and is the only place `unsafe` is permitted.

#[allow(unsafe_code, clippy::all, dead_code, unused_imports)]
mod frb_generated; // injected by flutter_rust_bridge — keep below inner attrs

pub mod api {
    pub mod verify;
}
