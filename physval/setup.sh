#!/bin/bash
# Convenience environment setup for the Achilles physics-validation image.
# Sourcing this makes ROOT, HepMC3, ProSelecta, NUISANCE2 and NUISANCE3 all
# available in the current shell. (The image also bakes these paths into its
# default environment, so this is only needed to refresh a modified shell.)

source /opt/root/bin/thisroot.sh 2>/dev/null || true

if [ -f /usr/local/bin/setup.ProSelecta.sh ]; then
    source /usr/local/bin/setup.ProSelecta.sh
fi

if [ -f /opt/nuisance2/setup.sh ]; then
    source /opt/nuisance2/setup.sh
fi

if [ -f /opt/nuisance3/bin/setup.NUISANCE3.sh ]; then
    source /opt/nuisance3/bin/setup.NUISANCE3.sh
fi
