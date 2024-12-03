#!/bin/bash

set -euo pipefail

# Logging functions
log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${*}" >&2; }
log_error() { log "ERROR: ${*}"; }
log_info() { log "INFO: ${*}"; }
log_debug() { [[ "${V:-}" =~ ^(sc|s)$ ]] && log "DEBUG: ${*}"; }

# Stack to track nested groups
declare -a GROUP_STACK=()

# GitHub Actions group helpers with stacking support
group() {
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        echo "::group::${1}"
    fi
    GROUP_STACK+=("${1}")
    log "BEGIN: ${1}"
}

endgroup() {
    if [[ ${#GROUP_STACK[@]} -gt 0 ]]; then
        if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
            echo "::endgroup::"
        fi
        log "END: ${GROUP_STACK[-1]}"
        unset 'GROUP_STACK[${#GROUP_STACK[@]}-1]'
    fi
}

cleanup() {
    local exit_code=$?
    while [[ ${#GROUP_STACK[@]} -gt 0 ]]; do
        if [[ ${exit_code} -ne 0 ]]; then
            log_error "Failed during: ${GROUP_STACK[-1]}"
        fi
        endgroup
    done
    exit "${exit_code}"
}

trap cleanup EXIT

FEEDNAME="${FEEDNAME:-action}"
ALL_CUSTOM_FEEDS="${FEEDNAME} "

if [[ -f setup.sh ]]; then
    log_info "Executing setup script"
    bash setup.sh
fi

if [[ -n "${KEY_BUILD:-}" ]]; then
    log_info "Installing build signing key"
    echo "${KEY_BUILD}" >key-build
    CONFIG_SIGNED_PACKAGES="y"
fi

if [[ -n "${PRIVATE_KEY:-}" ]]; then
    log_info "Installing private signing key"
    echo "${PRIVATE_KEY}" >private-key.pem
    CONFIG_SIGNED_PACKAGES="y"
fi

if [[ -z "${NO_DEFAULT_FEEDS:-}" ]]; then
    log_info "Configuring default feeds"
    sed -e 's,https://git.openwrt.org/\(feed\|openwrt\|project\)/,https://github.com/openwrt/,' \
        feeds.conf.default >feeds.conf
fi

echo "src-link ${FEEDNAME} /feed/" >>feeds.conf

if [[ -n "${EXTRA_FEEDS:-}" ]]; then
    log_info "Adding additional feeds"
    while read -r feed; do
        echo "${feed}" | tr '|' ' ' >>feeds.conf
        ALL_CUSTOM_FEEDS+="$(echo "${feed}" | cut -d'|' -f2) "
    done <<<"${EXTRA_FEEDS}"
fi

group "Feed Configuration"
log_info "Active feed configuration"
cat feeds.conf
endgroup

group "Feed Update"
log_info "Updating feed repositories"
./scripts/feeds update -a
./scripts/feeds install -p ${FEEDNAME} -a -d n
endgroup

group "Default Configuration"
log_info "Generating build configuration"
make defconfig
endgroup

build_package() {
    local pkg="${1}"
    local feed

    for feed in ${ALL_CUSTOM_FEEDS}; do
        log_info "Installing ${pkg} from feed ${feed}"
        if ! ./scripts/feeds install -p "${feed}" -d m -f "${pkg}"; then
            log_error "Installation failed for ${pkg} from ${feed}"
            return 1
        fi
    done

    log_info "Downloading ${pkg}"
    if ! make "package/${pkg}/download" V=s; then
        log_error "Download failed for ${pkg}"
        return 1
    fi

    log_info "Verifying ${pkg}"
    if ! make "package/${pkg}/check" V=s; then
        log_error "Verification failed for ${pkg}"
        return 1
    fi

    log_info "Compiling ${pkg}"
    if ! make "package/${pkg}/compile" \
        CONFIG_AUTOREMOVE=y \
        NO_DEPS=1 \
        V="${V:-}" \
        -j "$(nproc)"; then
        log_error "Compilation failed for ${pkg}"
        return 1
    fi

    return 0
}

if [[ -z "${PACKAGES:-}" ]]; then
    group "Full Build"
    
    for feed in ${ALL_CUSTOM_FEEDS}; do
        group "Installing ${feed}"
        log_info "Installing all packages from ${feed}"
        if ! ./scripts/feeds install -p "${feed}" -d m -f -a; then
            log_error "Feed installation failed: ${feed}"
            exit 1
        fi
        endgroup
    done

    group "Build"
    log_info "Starting build"
    if ! make \
        CONFIG_AUTOREMOVE=y \
        NO_DEPS=1 \
        V="${V:-}" \
        -j "$(nproc)"; then
        log_error "Build failed"
        exit 1
    fi
    endgroup
    
    endgroup
else
    group "Package Build"
    for pkg in ${PACKAGES}; do
        group "Building ${pkg}"
        if ! build_package "${pkg}"; then
            log_error "Package build failed: ${pkg}"
            exit 1
        fi
        endgroup
    done
    endgroup
fi

if [[ "${INDEX:-0}" == "1" ]]; then
    group "Index Generation"
    log_info "Generating package index"
    if ! make package/index; then
        log_error "Index generation failed"
        exit 1
    fi
    endgroup
fi

if [ -d bin/ ]; then
    mv -v bin /artifacts/
fi

log_info "Build completed"
exit 0