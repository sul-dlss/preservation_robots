[![CircleCI](https://circleci.com/gh/sul-dlss/preservation_robots.svg?style=svg)](https://circleci.com/gh/sul-dlss/preservation_robots)
[![Code Climate](https://codeclimate.com/github/sul-dlss/preservation_robots/badges/gpa.svg)](https://codeclimate.com/github/sul-dlss/preservation_robots)
[![Code Climate Test Coverage](https://codeclimate.com/github/sul-dlss/preservation_robots/badges/coverage.svg)](https://codeclimate.com/github/sul-dlss/
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

4. `update-catalog`: create/update Preservation Catalog entry for this Moab

5. `complete-ingest`: removes deposit bag created by transfer-object robot, then transfers control back to accessioning

# Testing

See https://docs.google.com/document/d/1d1GmSkam5_mR8NkbUQIf-Ztneu82zWChSqVSo6yUDVY
