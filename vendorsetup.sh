#!/usr/bin/env bash
# Copyright (C) Android Open Source Project
# Copyright (C) 2024-2025 Sreeshankar K
# Copyright (C) 2026 Kaveer Rana

# ─── Colors & Styles ──────────────────────────────────────────────────────────
R="\033[1;31m"
Y="\033[1;33m"
B="\033[1;34m"
G="\033[1;32m"
C="\033[1;36m"
M="\033[1;35m"
W="\033[1;37m"
DIM="\033[2m"
N="\033[0m"

# ─── Environment ──────────────────────────────────────────────────────────────
SRC_DIR="${PWD}"
CLANG_VERSION="r547379"
CLANG_DIR="${SRC_DIR}/prebuilts/clang/host/linux-x86/clang-${CLANG_VERSION}"
CLANG_TAR="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-${CLANG_VERSION}.tar.gz"

# ─── Dependency Table ─────────────────────────────────────────────────────────
DEP_NAMES=(
    "Firmware Images"
    "Kernel Source"
    "Vendor Blobs"
    "OnePlus Camera"
    "Dolby Source"
)
DEP_DIRS=(
    "${SRC_DIR}/vendor/oneplus/firmware"
    "${SRC_DIR}/kernel/oneplus/avicii"
    "${SRC_DIR}/vendor/oneplus/avicii"
    "${SRC_DIR}/vendor/oneplus/camera"
    "${SRC_DIR}/hardware/dolby"
)
DEP_REPOS=(
    "https://codeberg.org/sreeshankark/android_vendor_oneplus_firmware"
    "https://github.com/sreeshankark/android_kernel_oneplus_avicii"
    "https://github.com/Kaveer2009/android_vendor_oneplus_avicii"
    "https://codeberg.org/sreeshankark/android_vendor_oneplus_camera"
    "https://github.com/Kaveer2009/hardware_dolby-avicii"
)
DEP_BRANCHES=(
    ""
    ""
    ""
    ""
    "sony-1.2"
)

# ─── Tracking ─────────────────────────────────────────────────────────────────
FOUND=()
CLONED=()
FAILED=()

# ─── Banner ───────────────────────────────────────────────────────────────────
print_banner() {
    echo -e "${C}"
    echo -e "  ╔══════════════════════════════════════════════════════════════╗"
    echo -e "  ║                                                              ║"
    echo -e "  ║   ${W} ___   ___  ________   ___  ___     ___    ___  ${C}         ║"
    echo -e "  ║   ${W}|\  \ |\  \|\   ___  \|\  \|\  \   |\  \  /  /|${C}         ║"
    echo -e "  ║   ${W}\ \  \\_\  \ \  \\ \  \ \  \\\  \  \ \  \/  / /${C}         ║"
    echo -e "  ║   ${W} \ \______  \ \  \\ \  \ \   __  \  \ \    / / ${C}         ║"
    echo -e "  ║   ${W}  \|_____|\  \ \  \\ \  \ \  \ \  \  /     \/  ${C}         ║"
    echo -e "  ║   ${W}         \ \__\ \__\\ \__\ \__\ \__\/  /\   \  ${C}         ║"
    echo -e "  ║   ${W}          \|__|\|__| \|__|\|__|\|__/__/ /\ __\ ${C}         ║"
    echo -e "  ║   ${W}                                    |__|/ \|__| ${C}         ║"
    echo -e "  ║                                                              ║"
    echo -e "  ║        ${M}OnePlus Avicii — Device Vendor Setup Script${C}           ║"
    echo -e "  ║             ${DIM}${W}Crafted with ❤  by  Kaveer Rana${N}${C}               ║"
    echo -e "  ║                                                              ║"
    echo -e "  ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${N}"
}

# ─── Required Tree ────────────────────────────────────────────────────────────
print_tree_header() {
    echo -e "${W}  Cloning Required Tree ...${N}"
    echo ""
    echo -e "${C}  $(basename "${SRC_DIR}")/${N}"
    echo -e "${C}  ├── prebuilts/"
    echo -e "  │   └── clang/host/linux-x86/"
    echo -e "  │       └── ${W}clang-${CLANG_VERSION}${C}    ${DIM}← Clang/LLVM Toolchain${N}${C}"
    echo -e "  ├── kernel/"
    echo -e "  │   └── oneplus/"
    echo -e "  │       └── ${W}avicii${C}              ${DIM}← Kernel Source${N}${C}"
    echo -e "  ├── hardware/"
    echo -e "  │   └── ${W}dolby${C}                   ${DIM}← Dolby Source${N}${C}"
    echo -e "  └── vendor/"
    echo -e "      └── oneplus/"
    echo -e "          ├── ${W}firmware${C}             ${DIM}← Firmware Images${N}${C}"
    echo -e "          ├── ${W}avicii${C}               ${DIM}← Vendor Blobs${N}${C}"
    echo -e "          └── ${W}camera${C}               ${DIM}← OnePlus Camera${N}"
    echo ""
    echo -e "${DIM}  ──────────────────────────────────────────────────${N}"
    echo ""
}

# ─── Helpers ──────────────────────────────────────────────────────────────────
log_info()    { echo -e "    ${B}➜${N}  $*"; }
log_ok()      { echo -e "    ${G}✔${N}  $*"; }
log_warn()    { echo -e "    ${Y}⚠${N}  $*"; }
log_err()     { echo -e "    ${R}✘${N}  $*"; }
divider()     { echo -e "${DIM}  ──────────────────────────────────────────────────${N}"; }

log_section() {
    echo ""
    echo -e "${C}  ┌─────────────────────────────────────────────────┐"
    printf  "  │  %-47s│\n" "$*"
    echo -e "  └─────────────────────────────────────────────────┘${N}"
    echo ""
}

# ─── Clone a single dependency ────────────────────────────────────────────────
clone_dep() {
    local name="$1"
    local dir="$2"
    local repo="$3"
    local branch="$4"

    local branch_flag=""
    [[ -n "${branch}" ]] && branch_flag="-b ${branch}"

    log_info "Cloning ${W}${name}${N} ..."
    # shellcheck disable=SC2086
    if git clone ${branch_flag} --depth=1 --recursive "${repo}" "${dir}" 2>&1 | \
        sed "s/^/      ${DIM}/; s/$/${N}/"; then
        log_ok "${G}${name}${N} cloned successfully"
        CLONED+=("${name}")
    else
        log_err "Failed to clone ${name}"
        log_err "  Repo: ${DIM}${repo}${N}"
        FAILED+=("${name}")
    fi
}

# ─── Check all build dependencies ─────────────────────────────────────────────
chk_dependencies() {
    log_section "🔍  Checking Build Dependencies"

    local count="${#DEP_NAMES[@]}"
    for (( i = 0; i < count; i++ )); do
        local name="${DEP_NAMES[$i]}"
        local dir="${DEP_DIRS[$i]}"
        local repo="${DEP_REPOS[$i]}"
        local branch="${DEP_BRANCHES[$i]}"

        echo -e "  ${W}[ ${M}$(( i + 1 ))/${count}${W} ]${N}  ${W}${name}${N}"
        echo -e "    ${DIM}${dir}${N}"

        if [[ -d "${dir}" ]]; then
            log_ok "Already present — skipping"
            FOUND+=("${name}")
        else
            log_warn "Not found — cloning now"
            clone_dep "${name}" "${dir}" "${repo}" "${branch}"
        fi
        echo ""
        divider
        echo ""
    done
}

# ─── Check / fetch Clang prebuilts ────────────────────────────────────────────
chk_clang() {
    log_section "🔧  Checking Clang/LLVM Prebuilts"

    echo -e "  ${W}[ Clang ${CLANG_VERSION} ]${N}"
    echo -e "    ${DIM}${CLANG_DIR}${N}"

    if [[ -d "${CLANG_DIR}" ]]; then
        log_ok "Clang/LLVM prebuilts already present — skipping"
        FOUND+=("Clang/LLVM ${CLANG_VERSION}")
        echo ""
        divider
        return 0
    fi

    log_warn "Clang/LLVM prebuilts not found"
    log_info "Downloading tarball from AOSP ..."

    if ! curl --fail -L "${CLANG_TAR}" -o clang.tar.gz --progress-bar; then
        log_err "Download failed. Check your connection."
        FAILED+=("Clang/LLVM ${CLANG_VERSION}")
        echo ""
        divider
        return 1
    fi

    log_info "Extracting to ${CLANG_DIR} ..."
    mkdir -p "${CLANG_DIR}"
    if ! tar -xf clang.tar.gz -C "${CLANG_DIR}"; then
        log_err "Extraction failed"
        rm -f clang.tar.gz
        FAILED+=("Clang/LLVM ${CLANG_VERSION}")
        echo ""
        divider
        return 1
    fi

    rm -f clang.tar.gz
    log_ok "Clang/LLVM ${CLANG_VERSION} is ready"
    CLONED+=("Clang/LLVM ${CLANG_VERSION}")
    echo ""
    divider
}

# ─── Summary ──────────────────────────────────────────────────────────────────
print_summary() {
    log_section "📋  Setup Summary"

    local total=$(( ${#FOUND[@]} + ${#CLONED[@]} + ${#FAILED[@]} ))

    if [[ ${#FOUND[@]} -gt 0 ]]; then
        echo -e "  ${G}Already Present  [ ${#FOUND[@]}/${total} ]${N}"
        for item in "${FOUND[@]}"; do
            echo -e "    ${G}✔${N}  ${item}"
        done
        echo ""
    fi

    if [[ ${#CLONED[@]} -gt 0 ]]; then
        echo -e "  ${B}Freshly Cloned   [ ${#CLONED[@]}/${total} ]${N}"
        for item in "${CLONED[@]}"; do
            echo -e "    ${B}↓${N}  ${item}"
        done
        echo ""
    fi

    if [[ ${#FAILED[@]} -gt 0 ]]; then
        echo -e "  ${R}Failed           [ ${#FAILED[@]}/${total} ]${N}"
        for item in "${FAILED[@]}"; do
            echo -e "    ${R}✘${N}  ${item}"
        done
        echo ""
        echo -e "${R}  ╔══════════════════════════════════════════════════════════════╗"
        echo -e "  ║   ✘  Some dependencies failed. Build may not succeed.        ║"
        echo -e "  ╚══════════════════════════════════════════════════════════════╝${N}"
        echo ""
        return 1
    fi

    echo -e "${G}  ╔══════════════════════════════════════════════════════════════╗"
    echo -e "  ║   ✔  All dependencies resolved. You're ready to build!       ║"
    echo -e "  ╚══════════════════════════════════════════════════════════════╝${N}"
    echo ""
}

# ─── Entry Point ──────────────────────────────────────────────────────────────
print_banner
print_tree_header
chk_dependencies
chk_clang
print_summary
