[![Build Status](https://travis-ci.org/sul-dlss/preservation_robots.svg?branch=master)](https://travis-ci.org/sul-dlss/preservation_robots)
[![Coverage Status](https://coveralls.io/repos/github/sul-dlss/preservation_robots/badge.svg)](https://coveralls.io/github/sul-dlss/preservation_robots)
[![Dependency Status](https://gemnasium.com/badges/github.com/sul-dlss/preservation_robots.svg)](https://gemnasium.com/github.com/sul-dlss/preservation_robots)
[![GitHub version](https://badge.fury.io/gh/sul-dlss%2Fpreservation_robots.svg)](https://badge.fury.io/gh/sul-dlss%2Fpreservation_robots)

# preservation_robots

Robots for creating/updating preservation artifacts (Moabs) for DOR objects, adding Moabs to the preservation_catalog, etc.

# General Robot Documentation

Check the [Wiki](https://github.com/sul-dlss/robot-master/wiki) in the robot-master repo.

Uses the `lyber-core`/`robot-controller` infrastructure, which uses `bundle exec controller boot`
to start all robots defined in `config/environments/robots_ENV.yml`.

## Restarting Robots

```
cap <deploy_stage> deploy:restart # restarts all the robots on servers defined in deploy stage file.
```

# Dependencies

External dependencies are surfaced in `config/settings.yml` and [shared_configs](https://github.com/sul-dlss/shared_configs) (preservation_robots_xxx branches).

# Overview of workflow

A copy of the workflow datastream (from the Workflow object) is at `config/workflows/sdr/preservationIngestWF`

There are 6 robots:

1. `transfer-object`: copies the BagIt bag containing files for a new Moab version (or new Moab), which was created by common-accessioning sdr-ingest-transfer robot, to the deposit location for the Moab.

2. `validate-bag`: validates the BagIt/Moab deposit bag structure and version

3. `verify-apo`: verifies the governing APO for this object is in SDR

4. `update-moab`: create/add a version to Moab object from deposit bag

5. `update-catalog`: create/update Preservation Catalog entry for this Moab

6. `complete-ingest`: removes deposit bag created by transfer-object robot, then transfers control back to accessioning
