#!/bin/bash
# Install thin gcc/g++ wrappers used when building NUISANCE2 (with NuHepMC) and
# NUISANCE3 against their pinned, pre-GCC-15 dependencies. The wrappers work
# around two GCC-15 incompatibilities with the pinned fmt 10.2.1:
#
#   1. Several sub-projects (NUISANCEHEPData, NuHepMC cpputils, ...) compile with
#      -Werror, and GCC 15 emits new warnings inside fmt headers (e.g.
#      -Wtautological-compare in fmt/ranges.h) that then become hard errors.
#      -> the wrappers drop every -Werror / -Werror=* token.
#
#   2. fmt 10.2.1's consteval compile-time format-string checking does not compile
#      under GCC 15 ("call to consteval function ... is not a constant expression").
#      fmt gates this only on __cpp_consteval via `#ifndef FMT_CONSTEVAL`, so
#      pre-defining FMT_CONSTEVAL to empty makes basic_format_string's constructor
#      non-consteval and leaves FMT_HAS_CONSTEVAL undefined (fmt's fallback path).
#      -> the wrappers append -DFMT_CONSTEVAL= to every compile.
#
# Select them by exporting CC=gcc-nowerror CXX=g++-nowerror before configuring.
set -e

_make_wrapper() {
    local real="$1" out="$2"
    cat > "$out" <<EOF
#!/bin/bash
args=()
for a in "\$@"; do
  case "\$a" in
    -Werror|-Werror=*) ;;
    *) args+=("\$a");;
  esac
done
exec ${real} "\${args[@]}" -DFMT_CONSTEVAL=
EOF
    chmod +x "$out"
}

_make_wrapper /usr/bin/g++ /usr/local/bin/g++-nowerror
_make_wrapper /usr/bin/gcc /usr/local/bin/gcc-nowerror
