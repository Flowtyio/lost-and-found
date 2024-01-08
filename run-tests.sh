#!/bin/bash

set -e

flow test --cover --covercode="contracts" --coverprofile="coverage.lcov" tests/*_tests.cdc