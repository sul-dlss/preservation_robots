[![CircleCI](https://circleci.com/gh/sul-dlss/preservation_robots.svg?style=svg)](https://circleci.com/gh/sul-dlss/preservation_robots)
[![codecov](https://codecov.io/github/sul-dlss/preservation_robots/graph/badge.svg?token=i0Ofesr1wz)](https://codecov.io/github/sul-dlss/preservation_robots)
[![GitHub version](https://badge.fury.io/gh/sul-dlss%2Fpreservation_robots.svg)](https://badge.fury.io/gh/sul-dlss%2Fpreservation_robots)

# preservation_robots

Robots for creating/updating preservation artifacts (Moabs) for DOR objects, adding Moabs to the preservation_catalog, etc.

## Restarting Robots

```
cap <deploy_stage> deploy:restart # restarts all the robots on servers defined in deploy stage file.
```

# Dependencies

External dependencies are surfaced in `config/settings.yml` and [shared_configs](https://github.com/sul-dlss/shared_configs) (preservation_robots_xxx branches).

# Overview of workflow

The workflow is defined by: https://github.com/sul-dlss/workflow-server-rails/blob/master/config/workflows/sdr/preservationIngestWF.xml

There are 5 robots:

1. `transfer-object`: copies the BagIt bag containing files for a new Moab version (or new Moab), which was created by common-accessioning sdr-ingest-transfer robot, to the deposit location for the Moab.

2. `validate-bag`: validates the BagIt/Moab deposit bag structure and version

3. `update-moab`: create/add a version to Moab object from deposit bag

4. `validate-moab`: verify the Moab on local disk passes validation, including checksums for latest content

5. `update-catalog`: create/update Preservation Catalog entry for this Moab

6. `complete-ingest`: removes deposit bag created by transfer-object robot, then transfers control back to accessioning

# Waiting on CephFS write capabilities

Preservation storage is a CephFS mount shared by every preservation_robots host. When one
host writes and another reads moments later, the reader can see stale content, see nothing
at all, or block: CephFS clients cache inode data and metadata under *capabilities* ("caps")
granted by the MDS, and until the writer's client hands those back the MDS's copy is not
authoritative. This is why we have historically run a single preservation_robots host per
environment.

`transfer-object` writes the deposit bag and `update-moab` writes the Moab, so
`validate-bag` and `update-moab` both read paths an earlier step may have written on a
different host. Before reading, each asks the MDS whether any *other* host still holds write
caps anywhere under the deposit bag and the Moab, and waits for them to be released.

The relevant caps are `Fb` (the client holds dirty file data that has not reached the OSDs),
`Fw`/`Fa` (the client may write / extend EOF), and the exclusive caps `Fx`, `Ax`, `Xx` and
`Lx` (the client, not the MDS, holds the authoritative state). Caps held by this host's own
client are ignored: every process on a host shares one CephFS client, so those reads are
already coherent. Our own client is identified by the hostname it reported to the MDS at
mount time.

## Prerequisites

- The `ceph` CLI must be installed on the robot host.
- **The keyring must have `mds allow *`.** The MDS rejects `ceph tell mds.<...>` from any key
  without it and there is no narrower grant, so this key can also run `scrub`, `damage rm`,
  `respawn` and `exit` against the MDS. Provision a dedicated key and treat it accordingly.
- `mon allow r`, if `ranks` is left empty and the MDS ranks are discovered via `ceph fs get`.

## Configuration

Under `ceph` in `config/settings.yml`; `write_capability_check.enabled` is `false` until a
keyring is deployed. `write_capability_check.mounts` maps each local mount point to where it
sits in the CephFS namespace (the MDS knows paths by their position in the namespace, not by
local mount point). Getting that mapping wrong does not silently disable the check: each
check stats its path first, which pins the inode in the MDS cache, and then fails loudly if
the MDS does not report that inode back.

## Failure modes

- **Caps still held when `max_wait` elapses**: the step raises `ItemError`. The read that
  would follow is known to be unsafe, so failing the step beats ingesting what we would read.
- **The query itself fails** (no `ceph` binary, permission denied, unparseable output): logged,
  reported to Honeybadger, and the step proceeds as it would have before this check existed.
- **The path is not visible on this host at all**: logged and skipped, since a path we cannot
  see is a path we cannot resolve to an inode to ask the MDS about. This is a real gap --- an
  invisible deposit bag is one of the symptoms this check exists to absorb.

# Testing

See https://docs.google.com/document/d/1d1GmSkam5_mR8NkbUQIf-Ztneu82zWChSqVSo6yUDVY

# Resetting preservation robots

This only makes sense as part of a reset of the preservation environment and its associated SDR environment as a whole.  See the preservation_catalog README for detailed instructions.
