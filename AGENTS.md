# Project Guidelines
preservation_robots is a Ruby application that ingests digital objects in the Stanford Digital Repository (SDR) long term preservation system.

## Architecture

- preservation_robots is meant to be the only application that writes to preservation storage mounts ("storage roots", in the terminology of the moab-versioning gem).
- Its main functionality is implemented as job code that is used to execute "workflow steps" in the SDR `preservationIngestWF`. It has no web interface of its own. It does have a CLI console script for invoking app code, and some other scripts, in `bin/`.
- It is one of the SDR "robots" applications (i.e. it inherets functionality from the lyber-core framework for interacting with the workflow service).

## Conventions

- Match existing implementation patterns before introducing new abstractions. If you are unsure about what might be idiomatic, ask questions.
- Keep changes focused and avoid rewriting established search flow patterns unless the task requires it.
- Prefer full variable names instead of abbreviations (e.g., `full_variable_name` instead of `fvn` or `full_var_name`).
- Prefer reading and writing Moab and Bag file and folder structures via functionality provided by the moab-versioning gem.
- The preservation storage is mounted as a local POSIX file system, but is backed by Ceph, a distributed cluster file storage system. This rarely matters in practice, so do not proactively account for it unless asked, or unless it seems absolutely necessary.

## Testing notes

- Druids should match the pattern "^[b-df-hjkmnp-tv-z]{2}[0-9]{3}[b-df-hjkmnp-tv-z]{2}[0-9]{4}$", e.g., "bc123df4567". I.e., they should not have the `druid:` namespace/prefix.
- When creating multiple, unique druids for the same spec, vary at least the first 2 characters and the last 2 characters.
- Prefer instance_doubles instead of doubles.
- For mocking, place allow statements in a before block and expect statements after the action is performed. Prefer testing argument (with) in expect; do not test in both allow and expect.
- Place "let" statements before "before "blocks.

## References
For gems, read the source at the indicated path rather than guessing interfaces. If this local source isn't available, read from Github.

### Useful for development
- See `README.md` for: setup, linting, and testing details; workflow step ordering and summary of expected behavior.
- DOR Services Client (Repository: https://github.com/sul-dlss/dor-services-client, Namespace: `Dor::Services::Client`) - Client for interacting with DOR Services App (DSA), the backend of SDR. It can usually be found locally for reading at `../dor-services-client`.
- Moab Versioning (Repository: https://github.com/sul-dlss/moab-versioning, Namespace: `Stanford`, `Moab`) - A Ruby gem for reading and manipulating Moab preservation storage objects.

### Deeper context, may be useful when debugging
- Moab (whitepaper: https://journal.code4lib.org/articles/8482) - A directory layout and manifest structure for multi-version digital preservation objects. It uses a forward differential approach for versioning, and there are manifest files that include checksums for content files and other manifest files, so that Moab objects may be checked for fixity and completeness.
- Ceph - A software-defined storage platform that provides object storage, block storage, and file storage built on a common distributed cluster foundation. See https://en.wikipedia.org/wiki/Ceph_(software) and https://docs.ceph.com/en/quincy/cephfs/index.html (the latter is about CephFS, "a POSIX-compliant file system built on top of Ceph’s distributed object store, RADOS.")
