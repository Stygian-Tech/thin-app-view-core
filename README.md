# ThinAppViewCore

Extracted from The Social Wire at `47368fefb52ad90e37f6d0962a87451b04a04c56`. See `SOURCE_PROVENANCE.json` for the original source digests. Package history is preserved by filtering its original directory; packaging changes follow that history.

Run `swift test` with Swift 6.2.4 or newer. CI enforces warnings as errors without unsafe library flags.

The reviewed migration snapshot under `TestSupport/Migrations` prepares disposable integration databases. Set `DATABASE_URL` and run `bash scripts/apply-test-migrations.sh`; production migration ownership remains in The Social Wire. CI applies the snapshot twice to verify its migration ledger before enabling database tests.
