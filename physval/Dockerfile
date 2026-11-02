####################################################################################
# Achilles physics-validation image
#
# Provides, on top of a ROOT base image, a toolchain and the ecosystem needed to
# validate Achilles output against data with NUISANCE:
#   * build libraries for Achilles and NUISANCE
#   * HepMC3            (pinned release)
#   * ProSelecta        (pinned release)
#   * NUISANCE2         (main, pinned to a resolved sha)
#   * NUISANCE3         (main, pinned to a resolved sha) with the NUISANCE2
#                       legacy interface enabled
#
# The build is split into independent, individually-cacheable stages so that
# bumping one component only invalidates that component and the stages that
# depend on it.  Resolved shas are written to /opt/achilles-physval/versions.json
# and stamped as OCI image labels.
####################################################################################

ARG ROOT_IMAGE=rootproject/root:6.38.00-ubuntu25.10

# ---- component pins ---------------------------------------------------------
# HepMC3 / ProSelecta are pinned to release tags; NUISANCE2 / NUISANCE3 track
# main but are pinned to the sha that main resolved to when this file was written
# ("tag the current sha"). Override *_REF to move them.
ARG HEPMC3_VERSION=3.3.1
ARG HEPMC3_SHA=beb66aa1a2ac263066becdee26d18ead83edec95

ARG PROSELECTA_VERSION=v1-RC6
ARG PROSELECTA_SHA=c3f5a7a6c1be41f730f679c835adf9a3a52c6adb

ARG NUISANCE2_REF=main
# 86c64b44 is the first main commit with the MicroBooNE CC1Mu1p delta p_n unit fix
# (NUISANCEMC/nuisance#114); before it that sample plots a quantity that is not
# delta p_n, whatever generator is fed in.
ARG NUISANCE2_SHA=86c64b44754ce3a7b9bf3bf88f6207fc6a0256f1

ARG NUISANCE3_REF=main
ARG NUISANCE3_SHA=32bcc1f84118b617dd8fa0ea0c09371af18a5a4a

ARG BUILD_JOBS=8

####################################################################################
# Stage 0: base — libraries needed to build Achilles and NUISANCE
####################################################################################
FROM ${ROOT_IMAGE} AS base

ENV DEBIAN_FRONTEND=noninteractive
# run every RUN in bash so we can `source` the ROOT environment
SHELL ["/bin/bash", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        gfortran \
        cmake \
        make \
        git \
        ca-certificates \
        curl \
        wget \
        pkg-config \
        python3 \
        python3-dev \
        python3-pip \
        python3-numpy \
        zlib1g-dev \
        libhdf5-dev \
        libgsl-dev \
        libeigen3-dev \
        libyaml-cpp-dev \
        pybind11-dev \
        libboost-dev \
        libboost-system-dev \
        libboost-filesystem-dev \
    && rm -rf /var/lib/apt/lists/*

# Make CPM cache its downloads in a stable location so retries are cheap.
ENV CPM_SOURCE_CACHE=/opt/cpm-cache
# Where each builder stages its `make install` tree (prefix /usr/local underneath).
RUN mkdir -p /opt/stage /opt/versions /opt/cpm-cache

# Pull the ROOT environment into every subsequent bash RUN (rootproject images
# install ROOT under /opt/root; also honour ROOTSYS if the image sets it).
RUN if [ -f /opt/root/bin/thisroot.sh ]; then \
        echo 'source /opt/root/bin/thisroot.sh' >> /etc/profile.d/zz-root.sh ; \
    elif [ -n "${ROOTSYS}" ] && [ -f "${ROOTSYS}/bin/thisroot.sh" ]; then \
        echo "source ${ROOTSYS}/bin/thisroot.sh" >> /etc/profile.d/zz-root.sh ; \
    fi
# Helper sourced at the top of each build RUN.
ENV ROOTENV="source /etc/profile.d/zz-root.sh 2>/dev/null || true"

####################################################################################
# Stage 1: HepMC3  (build + install, pinned version)
####################################################################################
FROM base AS hepmc3
ARG HEPMC3_VERSION
ARG HEPMC3_SHA
ARG BUILD_JOBS

RUN eval "$ROOTENV" \
 && git clone --depth 1 --branch "${HEPMC3_VERSION}" \
        https://gitlab.cern.ch/hepmc/HepMC3.git /src/HepMC3 \
 && cmake -S /src/HepMC3 -B /build/HepMC3 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DHEPMC3_ENABLE_ROOTIO=ON \
        -DHEPMC3_ENABLE_PYTHON=ON \
        -DHEPMC3_PYTHON_VERSIONS=3.13 \
        -DHEPMC3_ENABLE_TEST=OFF \
        -DHEPMC3_BUILD_EXAMPLES=OFF \
        -DHEPMC3_INSTALL_INTERFACES=ON \
 && cmake --build /build/HepMC3 -j"${BUILD_JOBS}" \
 && DESTDIR=/opt/stage/hepmc3 cmake --install /build/HepMC3 \
 && sha="$(git -C /src/HepMC3 rev-parse HEAD)" \
 && printf '{"hepmc3":{"repo":"https://gitlab.cern.ch/hepmc/HepMC3.git","ref":"%s","version":"%s","sha":"%s"}}\n' \
        "${HEPMC3_VERSION}" "${HEPMC3_VERSION}" "${sha}" > /opt/versions/hepmc3.json \
 && cat /opt/versions/hepmc3.json

####################################################################################
# Stage 2: ProSelecta  (build + install, pinned version)  — needs HepMC3 + ROOT
####################################################################################
FROM base AS proselecta
ARG PROSELECTA_VERSION
ARG BUILD_JOBS

COPY --from=hepmc3 /opt/stage/hepmc3/usr/local/ /usr/local/

RUN eval "$ROOTENV" && ldconfig \
 && git clone --depth 1 --branch "${PROSELECTA_VERSION}" \
        https://github.com/NUISANCEMC/ProSelecta.git /src/ProSelecta \
 && cmake -S /src/ProSelecta -B /build/ProSelecta \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DProSelecta_ENABLE_TESTS=OFF \
 && cmake --build /build/ProSelecta -j"${BUILD_JOBS}" \
 && DESTDIR=/opt/stage/proselecta cmake --install /build/ProSelecta \
 && sha="$(git -C /src/ProSelecta rev-parse HEAD)" \
 && printf '{"proselecta":{"repo":"https://github.com/NUISANCEMC/ProSelecta.git","ref":"%s","version":"%s","sha":"%s"}}\n' \
        "${PROSELECTA_VERSION}" "${PROSELECTA_VERSION}" "${sha}" > /opt/versions/proselecta.json \
 && cat /opt/versions/proselecta.json

####################################################################################
# Stage 3: NUISANCE2  (main, pinned sha)  — needs HepMC3 + ROOT
# Generators/reweight engines are explicitly disabled (not present in this image);
# the experiment-data comparison libraries (the point of physics validation) stay on.
# NuHepMC is enabled so NUISANCE2 can read Achilles' NuHepMC events and so that the
# NuHepMCInputHandler headers exist for NUISANCE3's legacy (NUISANCE2) record plugin.
####################################################################################
FROM base AS nuisance2
ARG NUISANCE2_REF
ARG NUISANCE2_SHA
ARG BUILD_JOBS

COPY --from=hepmc3 /opt/stage/hepmc3/usr/local/ /usr/local/
COPY nuisance2-patches/ /src/nuisance2-patches/

# NuHepMC pulls in fmt/spdlog via NuHepMC cpputils; build through the GCC-15/fmt
# wrappers (see cc-nowerror-setup.sh) so those translation units compile.
COPY cc-nowerror-setup.sh /usr/local/bin/cc-nowerror-setup.sh
RUN bash /usr/local/bin/cc-nowerror-setup.sh
ENV CC=gcc-nowerror \
    CXX=g++-nowerror

RUN eval "$ROOTENV" && ldconfig \
 && git clone https://github.com/NUISANCEMC/nuisance.git /src/nuisance \
 && git -C /src/nuisance checkout --detach "${NUISANCE2_SHA}" \
 # Four NUISANCE2 fixes the Achilles physval suite needs. Three fail silently -- an
 # empty prediction, not an error: the WireCell MicroBooNE_NCpi0 and
 # MicroBooNE_CC1Mu0pNp samples set their bin index only in FillHistograms, which
 # NUISANCE3's legacy record never calls, and the Durham ElectronData samples cut on
 # variables that record fills after isSignal. The fourth is loud: SampleList offers
 # twelve MicroBooNE_CC1Mu1p_XSec_1D* names but the class constructor's name chain
 # covers only ten, so ProtonMomentum or EQE makes CreateSample abort the process and
 # take its whole shard down. Upstream as NUISANCEMC/nuisance#115, #116 and two more;
 # drop these once they merge and the pin moves past them.
 && for patch in /src/nuisance2-patches/*.patch; do \
        echo "[physval] applying $(basename "$patch")"; \
        git -C /src/nuisance apply --verbose "$patch"; \
    done \
 # Enable the pyNuHepMC python binding in the NuHepMC cpputils that NUISANCE2 pulls
 # in. NUISANCE3 reuses this cpputils (found via $NUISANCE) instead of building its
 # own, and NUISANCE3's pyNUISANCE does `import pyNuHepMC` at load, so the binding
 # must exist here. (Upstream builds cpputils without python by default.)
 && sed -i 's|OPTIONS "BUILTIN_HEPMC3 ON"|OPTIONS "BUILTIN_HEPMC3 ON" "NuHepMC_CPPUtils_PYTHON_ENABLED ON"|' \
        /src/nuisance/cmake/Modules/NUISANCEDependencies.cmake \
 && cmake -S /src/nuisance -B /build/nuisance \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/nuisance2 \
        -DNuHepMC_ENABLED=ON \
        -DNEUT_ENABLED=OFF \
        -DGENIE_ENABLED=OFF \
        -DNuWro_ENABLED=OFF \
        -DT2KReWeight_ENABLED=OFF \
        -DNIWGLegacy_ENABLED=OFF \
        -DNOvARwgt_ENABLED=OFF \
        -Dnusystematics_ENABLED=OFF \
 && cmake --build /build/nuisance -j"${BUILD_JOBS}" \
 && cmake --install /build/nuisance \
 # Ensure the built pyNuHepMC module is on the deployable python path (CPM may
 # exclude cpputils' own install rule from the top-level install).
 && mkdir -p /opt/nuisance2/python/3.13 \
 && found="$(find /build/nuisance -name 'pyNuHepMC*.so' 2>/dev/null | head -1)" \
 && echo "[physval] nuisance2 pyNuHepMC: ${found:-NOT-FOUND}" \
 && if [ -n "$found" ]; then cp "$found" /opt/nuisance2/python/3.13/; fi \
 && sha="$(git -C /src/nuisance rev-parse HEAD)" \
 && patches="$(cd /src/nuisance2-patches && ls *.patch | paste -sd, -)" \
 && printf '{"nuisance2":{"repo":"https://github.com/NUISANCEMC/nuisance.git","ref":"%s","sha":"%s","patches":"%s"}}\n' \
        "${NUISANCE2_REF}" "${sha}" "${patches}" > /opt/versions/nuisance2.json \
 && cat /opt/versions/nuisance2.json

####################################################################################
# Stage 4: NUISANCE3  (main, pinned sha) with the NUISANCE2 legacy interface
# Needs HepMC3 + ProSelecta + ROOT, and NUISANCE2 (via $NUISANCE) for the legacy link.
####################################################################################
FROM base AS nuisance3
ARG NUISANCE3_REF
ARG NUISANCE3_SHA
ARG BUILD_JOBS

COPY --from=hepmc3 /opt/stage/hepmc3/usr/local/ /usr/local/
COPY --from=proselecta /opt/stage/proselecta/usr/local/ /usr/local/
COPY --from=nuisance2 /opt/nuisance2/ /opt/nuisance2/

# The legacy interface requires $NUISANCE to point at a NUISANCE2 install.
ENV NUISANCE=/opt/nuisance2

# Install the gcc/g++ wrappers that work around GCC 15 / fmt 10.2.1 issues
# (see cc-nowerror-setup.sh) and select them for the whole NUISANCE3 build.
COPY cc-nowerror-setup.sh /usr/local/bin/cc-nowerror-setup.sh
RUN bash /usr/local/bin/cc-nowerror-setup.sh
ENV CC=gcc-nowerror \
    CXX=g++-nowerror

RUN eval "$ROOTENV" && ldconfig \
 && source /opt/nuisance2/setup.sh \
 && git clone https://github.com/NUISANCEMC/nuisance3.git /src/nuisance3 \
 && git -C /src/nuisance3 checkout --detach "${NUISANCE3_SHA}" \
 && cmake -S /src/nuisance3 -B /build/nuisance3 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/nuisance3 \
        -DNUISANCE_LEGACY_INTERFACE=ON \
        -DNUISANCE_ENABLE_TESTS=OFF \
 && cmake --build /build/nuisance3 -j"${BUILD_JOBS}" \
 && cmake --install /build/nuisance3 \
 # pyNUISANCE does `import pyNuHepMC` at load; that binding comes from NUISANCE2's
 # cpputils (built with python above) and is picked up from /opt/nuisance2/python
 # via PYTHONPATH in the final image.
 && sha="$(git -C /src/nuisance3 rev-parse HEAD)" \
 && printf '{"nuisance3":{"repo":"https://github.com/NUISANCEMC/nuisance3.git","ref":"%s","sha":"%s","legacy_nuisance2_interface":true}}\n' \
        "${NUISANCE3_REF}" "${sha}" > /opt/versions/nuisance3.json \
 && cat /opt/versions/nuisance3.json

####################################################################################
# Final stage: assemble the runtime image
####################################################################################
FROM base AS final

# component installs
COPY --from=hepmc3     /opt/stage/hepmc3/usr/local/     /usr/local/
COPY --from=proselecta /opt/stage/proselecta/usr/local/ /usr/local/
COPY --from=nuisance2  /opt/nuisance2/                  /opt/nuisance2/
COPY --from=nuisance3  /opt/nuisance3/                  /opt/nuisance3/

# resolved-version fragments
COPY --from=hepmc3     /opt/versions/hepmc3.json     /opt/versions/hepmc3.json
COPY --from=proselecta /opt/versions/proselecta.json /opt/versions/proselecta.json
COPY --from=nuisance2  /opt/versions/nuisance2.json  /opt/versions/nuisance2.json
COPY --from=nuisance3  /opt/versions/nuisance3.json  /opt/versions/nuisance3.json

# environment: put the whole stack on the default library/binary/python paths so
# tools work without sourcing anything. The versioned python dirs hold the
# pyProSelecta (/usr/local/python/3.13) and pyNUISANCE (/opt/nuisance3/python/3.13)
# modules; pyHepMC3 installs into the default site dir (…/dist-packages).
ENV NUISANCE=/opt/nuisance2 \
    NUISANCE3_ROOT=/opt/nuisance3 \
    ProSelecta_ROOT=/usr/local \
    PATH=/opt/nuisance3/bin:/opt/nuisance2/bin:/usr/local/bin:$PATH \
    LD_LIBRARY_PATH=/opt/nuisance3/lib:/opt/nuisance2/lib:/usr/local/lib:$LD_LIBRARY_PATH \
    PYTHONPATH=/opt/nuisance3/python/3.13:/opt/nuisance3/python:/opt/nuisance3/lib:/opt/nuisance2/python/3.13:/usr/local/python/3.13:/usr/local/lib:$PYTHONPATH

COPY setup.sh /opt/achilles-physval/setup.sh

# Runtime python deps for pyNUISANCE: PyYAML is required (pyNUISANCEProb3plusplus
# imports `yaml` at init); matplotlib backs pyNUISANCE's optional plotting helpers.
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3-yaml \
        python3-matplotlib \
    && rm -rf /var/lib/apt/lists/*

RUN echo "/usr/local/lib"      >  /etc/ld.so.conf.d/achilles-physval.conf \
 && echo "/opt/nuisance2/lib"  >> /etc/ld.so.conf.d/achilles-physval.conf \
 && echo "/opt/nuisance3/lib"  >> /etc/ld.so.conf.d/achilles-physval.conf \
 && ldconfig \
 && chmod +x /opt/achilles-physval/setup.sh \
 && python3 -c "import json,glob; d={}; [d.update(json.load(open(f))) for f in sorted(glob.glob('/opt/versions/*.json'))]; json.dump(d, open('/opt/achilles-physval/versions.json','w'), indent=2)" \
 && cat /opt/achilles-physval/versions.json

# ---- OCI labels: stamp the same resolved shas -------------------------------
ARG HEPMC3_VERSION
ARG HEPMC3_SHA
ARG PROSELECTA_VERSION
ARG PROSELECTA_SHA
ARG NUISANCE2_REF
ARG NUISANCE2_SHA
ARG NUISANCE3_REF
ARG NUISANCE3_SHA

LABEL org.opencontainers.image.title="achilles-physval" \
      org.opencontainers.image.description="ROOT + HepMC3 + ProSelecta + NUISANCE2 + NUISANCE3 (legacy interface) for Achilles physics validation" \
      physval.hepmc3.version="${HEPMC3_VERSION}" \
      physval.hepmc3.sha="${HEPMC3_SHA}" \
      physval.proselecta.version="${PROSELECTA_VERSION}" \
      physval.proselecta.sha="${PROSELECTA_SHA}" \
      physval.nuisance2.ref="${NUISANCE2_REF}" \
      physval.nuisance2.sha="${NUISANCE2_SHA}" \
      physval.nuisance3.ref="${NUISANCE3_REF}" \
      physval.nuisance3.sha="${NUISANCE3_SHA}" \
      physval.nuisance3.legacy_nuisance2_interface="true"

WORKDIR /work
CMD ["/bin/bash"]
