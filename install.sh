#!/usr/bin/env bash

#===============================================================================
# Dotfiles Installation Script
# Creates symlinks from this repo to their correct locations in the system
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located (the dotfiles repo)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect the real user's home directory (even when run with sudo)
if [[ -n "${SUDO_USER:-}" ]]; then
    # Running with sudo - get the actual user's home directory
    REAL_USER="$SUDO_USER"
    REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    # Not running with sudo - use USER if set, otherwise get from whoami
    REAL_USER="${USER:-$(whoami)}"
    REAL_HOME="${HOME:-$(eval echo ~$REAL_USER)}"
fi

# Override HOME so the path lookups below resolve against the real user's home.
# NOTE: this fixes *where* files land, not *who owns them*. Under sudo we are
# still root, so every command that writes under $HOME must go through
# run_as_user() or it leaves root-owned files in the user's home.
HOME="$REAL_HOME"
export HOME

# Detect if sudo is needed (check if running as root)
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

#===============================================================================
# Distro Detection & Package Manager
#===============================================================================

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_NAME="${NAME:-Unknown}"
        DISTRO_VERSION="${VERSION_ID:-}"
        DISTRO_ID_LIKE="${ID_LIKE:-}"
    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        DISTRO_ID="${DISTRIB_ID,,}"
        DISTRO_NAME="${DISTRIB_DESCRIPTION:-Unknown}"
        DISTRO_VERSION="${DISTRIB_RELEASE:-}"
        DISTRO_ID_LIKE=""
    else
        DISTRO_ID="unknown"
        DISTRO_NAME="Unknown"
        DISTRO_VERSION=""
        DISTRO_ID_LIKE=""
    fi
    
    # Detect package manager based on distro
    case "$DISTRO_ID" in
        ubuntu|debian|linuxmint|pop|elementary|zorin|kali)
            PKG_MANAGER="apt"
            PKG_INSTALL="$SUDO apt update && $SUDO apt install -y"
            ;;
        fedora)
            PKG_MANAGER="dnf"
            PKG_INSTALL="$SUDO dnf install -y"
            ;;
        rhel|centos|rocky|alma|oracle)
            # Check if dnf is available (RHEL 8+), otherwise use yum
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
                PKG_INSTALL="$SUDO dnf install -y"
            else
                PKG_MANAGER="yum"
                PKG_INSTALL="$SUDO yum install -y"
            fi
            ;;
        arch|manjaro|endeavouros|garuda)
            PKG_MANAGER="pacman"
            PKG_INSTALL="$SUDO pacman -S --noconfirm"
            ;;
        opensuse*|suse|sles)
            PKG_MANAGER="zypper"
            PKG_INSTALL="$SUDO zypper install -y"
            ;;
        alpine)
            PKG_MANAGER="apk"
            PKG_INSTALL="$SUDO apk add"
            ;;
        void)
            PKG_MANAGER="xbps"
            PKG_INSTALL="$SUDO xbps-install -y"
            ;;
        gentoo)
            PKG_MANAGER="emerge"
            PKG_INSTALL="$SUDO emerge"
            ;;
        nixos)
            PKG_MANAGER="nix"
            PKG_INSTALL="nix-env -iA nixpkgs"
            ;;
        *)
            # Try to detect by ID_LIKE as fallback
            case "$DISTRO_ID_LIKE" in
                *debian*|*ubuntu*)
                    PKG_MANAGER="apt"
                    PKG_INSTALL="$SUDO apt update && $SUDO apt install -y"
                    ;;
                *rhel*|*fedora*|*centos*)
                    if command -v dnf &> /dev/null; then
                        PKG_MANAGER="dnf"
                        PKG_INSTALL="$SUDO dnf install -y"
                    else
                        PKG_MANAGER="yum"
                        PKG_INSTALL="$SUDO yum install -y"
                    fi
                    ;;
                *arch*)
                    PKG_MANAGER="pacman"
                    PKG_INSTALL="$SUDO pacman -S --noconfirm"
                    ;;
                *suse*)
                    PKG_MANAGER="zypper"
                    PKG_INSTALL="$SUDO zypper install -y"
                    ;;
                *)
                    PKG_MANAGER="unknown"
                    PKG_INSTALL=""
                    ;;
            esac
            ;;
    esac
}

# Get the correct package name for each distro (some differ)
get_package_name() {
    local package="$1"
    
    case "$package" in
        zsh)
            echo "zsh"  # Same across all distros
            ;;
        git)
            echo "git"  # Same across all distros
            ;;
        curl)
            echo "curl"  # Same across all distros
            ;;
        make)
            echo "make"  # Same across all distros
            ;;
        cmake)
            echo "cmake"  # Same across all distros
            ;;
        ripgrep)
            case "$PKG_MANAGER" in
                apt) echo "ripgrep" ;;
                dnf|yum) echo "ripgrep" ;;
                pacman) echo "ripgrep" ;;
                zypper) echo "ripgrep" ;;
                apk) echo "ripgrep" ;;
                *) echo "ripgrep" ;;
            esac
            ;;
        *)
            echo "$package"
            ;;
    esac
}

# Get neovim build dependencies based on distro
get_nvim_build_deps() {
    case "$PKG_MANAGER" in
        apt)
            echo "ninja-build gettext cmake curl build-essential git"
            ;;
        dnf|yum)
            echo "ninja-build cmake gcc make gettext curl glibc-gconv-extra git"
            ;;
        pacman)
            echo "base-devel cmake unzip ninja tree-sitter curl git"
            ;;
        zypper)
            echo "ninja cmake gcc-c++ gettext-tools curl git"
            ;;
        apk)
            echo "build-base cmake automake autoconf libtool pkgconf coreutils curl unzip gettext-tiny-dev git"
            ;;
        *)
            echo "cmake make gcc curl git"
            ;;
    esac
}

pkg_install() {
    local package="$1"
    local pkg_name
    pkg_name="$(get_package_name "$package")"
    
    if [[ "$PKG_MANAGER" == "unknown" ]]; then
        log_error "Unknown package manager. Please install '$package' manually."
        return 1
    fi
    
    log_info "Installing $pkg_name using $PKG_MANAGER..."
    eval "$PKG_INSTALL $pkg_name"
}

show_distro_info() {
    log_info "Detected system:"
    echo -e "    Distro: ${GREEN}$DISTRO_NAME${NC}"
    [[ -n "$DISTRO_VERSION" ]] && echo -e "    Version: ${GREEN}$DISTRO_VERSION${NC}"
    echo -e "    Package Manager: ${GREEN}$PKG_MANAGER${NC}"
    echo
}

# Run detection immediately
detect_distro

#===============================================================================
# Configuration - Edit these mappings as needed
#===============================================================================

# Standard dotfiles: source (relative to repo) -> destination (absolute path)
declare -A DOTFILES=(
    # Shell
    [".zshrc"]="$HOME/.zshrc"
    
    # Zsh extras
    [".zprofile"]="$HOME/.zprofile"
    [".p10k.zsh"]="$HOME/.p10k.zsh"
    
    # Git
    [".gitconfig"]="$HOME/.gitconfig"
    
    # Tmux
    [".tmux.conf"]="$HOME/.tmux.conf"
)

# Config directories: source (relative to repo) -> destination (absolute path)
# These are directories inside .config that should be symlinked
declare -A CONFIG_DIRS=(
    [".config/nvim"]="$HOME/.config/nvim"
    [".config/starship.toml"]="$HOME/.config/starship.toml"
    [".config/tmux"]="$HOME/.config/tmux"
    [".config/i3"]="$HOME/.config/i3"
    [".config/alacritty"]="$HOME/.config/alacritty"
    [".config/touchegg"]="$HOME/.config/touchegg"
    # Add more as needed
)

# Oh-My-Zsh custom directory (themes and plugins)
declare -A OMZ_CUSTOM=(
    [".oh-my-zsh/custom/themes"]="$HOME/.oh-my-zsh/custom/themes"
    [".oh-my-zsh/custom/plugins"]="$HOME/.oh-my-zsh/custom/plugins"
)

# Custom scripts with specific destinations
declare -A CUSTOM_SCRIPTS=(
    # Add custom scripts here, e.g. ["scripts/foo"]="$HOME/.local/bin/foo"
)

# System files: source (relative to repo) -> destination outside $HOME.
# These are COPIED root-owned, never symlinked. Xorg parses its InputClass
# config as root, so a symlink pointing into this user-writable repo would let
# anything able to write the repo inject input configuration that root reads.
declare -A SYSTEM_FILES=(
    ["etc/X11/xorg.conf.d/30-touchpad.conf"]="/etc/X11/xorg.conf.d/30-touchpad.conf"
)

#===============================================================================
# Helper Functions
#===============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Drop back to the invoking user for anything that writes under their home.
# Running the whole script under sudo is required for the package-manager and
# /etc steps, but user-level installers (rustup, atuin, oh-my-zsh, git clones)
# must not run as root or they leave files the user cannot read or update.
run_as_user() {
    if [[ $EUID -eq 0 && "$REAL_USER" != "root" ]]; then
        sudo -u "$REAL_USER" env \
            HOME="$REAL_HOME" \
            USER="$REAL_USER" \
            LOGNAME="$REAL_USER" \
            PATH="$REAL_HOME/.local/bin:$REAL_HOME/.cargo/bin:$REAL_HOME/.atuin/bin:$PATH" \
            "$@"
    else
        "$@"
    fi
}

# Is the command on the *user's* PATH? Under sudo the root PATH is usually
# reset to secure_path, which misses ~/.cargo/bin and ~/.atuin/bin and would
# make the checks below reinstall tools the user already has.
user_has_cmd() {
    run_as_user bash -c 'command -v "$1"' _ "$1" &> /dev/null
}

# Create a symlink with backup of existing file
create_symlink() {
    local source="$1"
    local dest="$2"
    local backup_dir="$DOTFILES_DIR/.backup/$(date +%Y%m%d_%H%M%S)"

    # Check if source exists
    if [[ ! -e "$source" ]]; then
        log_warning "Source does not exist: $source (skipping)"
        return 0
    fi

    # Create parent directory if it doesn't exist
    local dest_dir
    dest_dir="$(dirname "$dest")"
    if [[ ! -d "$dest_dir" ]]; then
        log_info "Creating directory: $dest_dir"
        run_as_user mkdir -p "$dest_dir"
    fi

    # Handle existing file/directory at destination
    if [[ -e "$dest" || -L "$dest" ]]; then
        # Check if it's already the correct symlink
        if [[ -L "$dest" ]] && [[ "$(readlink -f "$dest")" == "$(readlink -f "$source")" ]]; then
            log_success "Already linked: $dest -> $source"
            return 0
        fi

        # Backup existing file
        run_as_user mkdir -p "$backup_dir"
        local backup_path="$backup_dir/$(basename "$dest")"
        log_warning "Backing up existing: $dest -> $backup_path"
        run_as_user mv "$dest" "$backup_path"
    fi

    # Create the symlink
    run_as_user ln -s "$source" "$dest"
    log_success "Linked: $dest -> $source"
}

#===============================================================================
# Installation Functions
#===============================================================================

install_zsh() {
    log_info "Checking Zsh installation..."
    echo
    
    if command -v zsh &> /dev/null; then
        log_success "Zsh is already installed: $(zsh --version)"
    else
        if [[ "$PKG_MANAGER" == "unknown" ]]; then
            log_error "Cannot auto-install Zsh. Unknown package manager."
            log_info "Please install Zsh manually and re-run this script."
            exit 1
        fi
        
        pkg_install zsh
        log_success "Zsh installed: $(zsh --version)"
    fi
    
    # Set Zsh as default shell
    local zsh_path
    zsh_path="$(which zsh)"
}

install_dependencies() {
    log_info "Checking dependencies..."
    echo
    
    local deps_to_install=()

    # Check for which
    if ! command -v which &> /dev/null; then
        deps_to_install+=("which")
    else
        log_success "which is installed"
    fi
    
    # Check for git
    if ! command -v git &> /dev/null; then
        deps_to_install+=("git")
    else
        log_success "git is installed"
    fi
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        deps_to_install+=("curl")
    else
        log_success "curl is installed"
    fi
    
    # Check for make
    if ! command -v make &> /dev/null; then
        deps_to_install+=("make")
    else
        log_success "make is installed"
    fi
    
    # Check for cmake
    if ! command -v cmake &> /dev/null; then
        deps_to_install+=("cmake")
    else
        log_success "cmake is installed"
    fi
    
    # Check for tmux
    if ! command -v tmux &> /dev/null; then
        deps_to_install+=("tmux")
    else
        log_success "tmux is installed"
    fi
    
    # Install missing dependencies
    if [[ ${#deps_to_install[@]} -gt 0 ]]; then
        log_info "Installing missing dependencies: ${deps_to_install[*]}"
        for dep in "${deps_to_install[@]}"; do
            pkg_install "$dep"
        done
    fi
    echo
}

install_rust() {
    log_info "Checking Rust installation..."
    echo

    if user_has_cmd rustc && user_has_cmd cargo; then
        log_success "Rust is already installed: $(run_as_user rustc --version)"
        log_success "Cargo is available: $(run_as_user cargo --version)"
    else
        log_info "Installing Rust via rustup..."
        run_as_user bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"

        log_success "Rust installed: $(run_as_user rustc --version)"
        log_success "Cargo installed: $(run_as_user cargo --version)"
        log_info "Rust environment added to ~/.cargo/env"
        log_info "Make sure to source it in your shell config or restart your terminal"
    fi
    echo
}

install_ripgrep() {
    log_info "Checking ripgrep installation..."
    echo

    if command -v rg &> /dev/null; then
        log_success "ripgrep is already installed: $(rg --version | head -1)"
    else
        log_info "Installing ripgrep..."
        pkg_install ripgrep
        log_success "ripgrep installed: $(rg --version | head -1)"
    fi
    echo
}

install_alacritty() {
    log_info "Checking Alacritty installation..."
    echo

    if user_has_cmd alacritty; then
        log_success "Alacritty is already installed: $(run_as_user alacritty --version)"
        echo
        return 0
    fi

    log_info "Installing Alacritty via $PKG_MANAGER..."
    pkg_install alacritty

    # Some distros don't package Alacritty; fall back to cargo (needs Rust).
    if ! user_has_cmd alacritty; then
        if user_has_cmd cargo; then
            log_warning "Package install failed; building Alacritty via cargo..."
            run_as_user cargo install alacritty
        else
            log_error "Could not install Alacritty automatically; install it manually."
        fi
    fi

    if user_has_cmd alacritty; then
        log_success "Alacritty installed: $(run_as_user alacritty --version)"
    fi
    echo
}

install_atuin() {
    log_info "Checking Atuin installation..."
    echo

    if user_has_cmd atuin; then
        log_success "Atuin is already installed: $(run_as_user atuin --version)"
    else
        log_info "Installing Atuin via install script..."
        run_as_user bash -c "curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh"

        log_success "Atuin installed"
        log_info "Add the following to your .zshrc to enable Atuin:"
        echo -e "    ${GREEN}eval \"\$(atuin init zsh)\"${NC}"
    fi
    echo
}

install_neovim() {
    log_info "Checking Neovim installation..."
    echo
    
    if command -v nvim &> /dev/null; then
        log_success "Neovim is already installed: $(nvim --version | head -1)"
        return 0
    fi
    
    log_info "Building Neovim from source..."
    
    # Install build dependencies
    local nvim_deps
    nvim_deps="$(get_nvim_build_deps)"
    log_info "Installing Neovim build dependencies: $nvim_deps"
    
    case "$PKG_MANAGER" in
        apt)
            $SUDO apt update && $SUDO apt install -y $nvim_deps
            ;;
        dnf)
            $SUDO dnf install -y $nvim_deps
            ;;
        yum)
            $SUDO yum install -y $nvim_deps
            ;;
        pacman)
            $SUDO pacman -S --noconfirm $nvim_deps
            ;;
        zypper)
            $SUDO zypper install -y $nvim_deps
            ;;
        apk)
            $SUDO apk add $nvim_deps
            ;;
        *)
            log_warning "Unknown package manager, attempting to install deps anyway..."
            ;;
    esac
    
    # Clone and build neovim
    local nvim_build_dir="/tmp/neovim-build-$$"
    
    log_info "Cloning Neovim repository..."
    git clone --depth 1 https://github.com/neovim/neovim.git "$nvim_build_dir"
    
    cd "$nvim_build_dir" || { log_error "Failed to enter build directory"; return 1; }
    
    log_info "Building Neovim (this may take a few minutes)..."
    make CMAKE_BUILD_TYPE=RelWithDebInfo

    log_info "Installing Neovim..."
    $SUDO make install
    
    # Cleanup
    cd - > /dev/null
    rm -rf "$nvim_build_dir"
    
    if command -v nvim &> /dev/null; then
        log_success "Neovim installed: $(nvim --version | head -1)"
    else
        log_error "Neovim installation may have failed. Please check manually."
    fi
    echo
}

install_oh_my_zsh() {
    log_info "Checking Oh-My-Zsh installation..."
    echo

    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        log_success "Oh-My-Zsh is already installed"
    else
        log_info "Installing Oh-My-Zsh..."
        # Fetch as root (network only), execute as the user (writes to $HOME).
        local omz_installer
        omz_installer="$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        # Install without running zsh immediately (RUNZSH=no)
        # Don't change shell again (CHSH=no) since we already did it
        run_as_user env RUNZSH=no CHSH=no sh -c "$omz_installer"
        log_success "Oh-My-Zsh installed"
    fi
    echo
}

install_powerlevel10k() {
    log_info "Checking Powerlevel10k installation..."
    echo

    local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

    if [[ -d "$p10k_dir" ]]; then
        log_success "Powerlevel10k is already installed"
    else
        log_info "Installing Powerlevel10k theme..."
        run_as_user git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
        log_success "Powerlevel10k installed"
        log_info "Make sure ZSH_THEME=\"powerlevel10k/powerlevel10k\" is set in your .zshrc"
    fi
    echo
}

install_zsh_plugins() {
    log_info "Installing popular Zsh plugins..."
    echo

    local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"

    local name url
    for entry in \
        "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions" \
        "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting" \
        "fast-syntax-highlighting https://github.com/zdharma-continuum/fast-syntax-highlighting" \
        "zsh-completions https://github.com/zsh-users/zsh-completions"
    do
        read -r name url <<< "$entry"
        if [[ -d "$custom_dir/$name" ]]; then
            log_success "$name already installed"
        else
            log_info "Installing $name..."
            run_as_user git clone "$url" "$custom_dir/$name"
            log_success "$name installed"
        fi
    done

    log_info "Add these plugins to your .zshrc plugins array:"
    echo -e "    ${GREEN}plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)${NC}"
    echo
}

install_dotfiles() {
    log_info "Installing standard dotfiles..."
    echo
    
    for source in "${!DOTFILES[@]}"; do
        local full_source="$DOTFILES_DIR/$source"
        local dest="${DOTFILES[$source]}"
        create_symlink "$full_source" "$dest"
    done
    echo
}

install_config_dirs() {
    log_info "Installing config directories..."
    echo
    
    for source in "${!CONFIG_DIRS[@]}"; do
        local full_source="$DOTFILES_DIR/$source"
        local dest="${CONFIG_DIRS[$source]}"
        create_symlink "$full_source" "$dest"
    done
    echo
}

install_omz_custom() {
    log_info "Installing Oh-My-Zsh custom themes/plugins..."
    echo
    
    # Check if Oh-My-Zsh is installed
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_warning "Oh-My-Zsh not installed, skipping custom themes/plugins"
        return 0
    fi
    
    for source in "${!OMZ_CUSTOM[@]}"; do
        local full_source="$DOTFILES_DIR/$source"
        local dest="${OMZ_CUSTOM[$source]}"
        
        # For OMZ, we might want to link individual files instead of directories
        if [[ -d "$full_source" ]]; then
            for file in "$full_source"/*; do
                if [[ -e "$file" ]]; then
                    local filename
                    filename="$(basename "$file")"
                    create_symlink "$file" "$dest/$filename"
                fi
            done
        else
            create_symlink "$full_source" "$dest"
        fi
    done
    echo
}

install_custom_scripts() {
    log_info "Installing custom scripts..."
    echo

    # Ensure ~/.local/bin exists and is in PATH
    if [[ ! -d "$HOME/.local/bin" ]]; then
        log_info "Creating ~/.local/bin directory"
        run_as_user mkdir -p "$HOME/.local/bin"
    fi

    if [[ ${#CUSTOM_SCRIPTS[@]} -eq 0 ]]; then
        log_info "No custom scripts to install"
    fi
    for source in "${!CUSTOM_SCRIPTS[@]}"; do
        local full_source="$DOTFILES_DIR/$source"
        local dest="${CUSTOM_SCRIPTS[$source]}"
        create_symlink "$full_source" "$dest"

        # Make script executable
        if [[ -L "$dest" && -f "$full_source" ]]; then
            run_as_user chmod +x "$full_source"
        fi
    done
    echo
}

install_system_files() {
    log_info "Installing system files (requires root)..."
    echo

    if [[ ${#SYSTEM_FILES[@]} -eq 0 ]]; then
        log_info "No system files configured, skipping"
        echo
        return 0
    fi

    for source in "${!SYSTEM_FILES[@]}"; do
        local full_source="$DOTFILES_DIR/$source"
        local dest="${SYSTEM_FILES[$source]}"

        if [[ ! -f "$full_source" ]]; then
            log_warning "Source does not exist: $full_source (skipping)"
            continue
        fi

        if [[ -f "$dest" ]] && cmp -s "$full_source" "$dest"; then
            log_success "Already current: $dest"
            continue
        fi

        # Back up a differing existing file so a bad config can be reverted.
        # The backup lives in the user's repo, so it stays user-owned.
        if [[ -f "$dest" ]]; then
            local backup_dir="$DOTFILES_DIR/.backup/$(date +%Y%m%d_%H%M%S)"
            local backup_path="$backup_dir/$(basename "$dest")"
            run_as_user mkdir -p "$backup_dir"
            log_warning "Backing up existing: $dest -> $backup_path"
            $SUDO cp -p "$dest" "$backup_path"
            $SUDO chown "$REAL_USER:$(id -gn "$REAL_USER")" "$backup_path"
        fi

        $SUDO install -D -o root -g root -m 644 "$full_source" "$dest"
        log_success "Installed: $dest (root:root 0644)"
    done
    echo
    log_warning "Xorg reads input config at startup: log out and back in to apply."
    echo
}

install_touchegg() {
    log_info "Checking Touchegg (touchpad gestures)..."
    echo

    if command -v touchegg &> /dev/null; then
        log_success "Touchegg is already installed"
    else
        if [[ "$PKG_MANAGER" == "unknown" ]]; then
            log_warning "Unknown package manager; skipping Touchegg (gestures disabled)"
            echo
            return 0
        fi
        if ! pkg_install touchegg; then
            log_warning "Touchegg unavailable for this distro; gestures disabled"
            echo
            return 0
        fi
    fi

    # The recogniser runs as a system daemon. The per-session client is started
    # from the i3 config, not here.
    if command -v systemctl &> /dev/null; then
        if systemctl is-enabled touchegg.service &> /dev/null; then
            log_success "touchegg.service already enabled"
        elif $SUDO systemctl enable --now touchegg.service; then
            log_success "touchegg.service enabled"
        else
            log_warning "Could not enable touchegg.service; gestures will not work"
        fi
    fi
    echo
}

install_tmux_plugins() {
    log_info "Setting up tmux plugins (TPM)..."
    echo

    if ! command -v tmux &> /dev/null; then
        log_warning "tmux not found; skipping plugin setup"
        echo
        return 0
    fi

    local tpm_dir="$HOME/.tmux/plugins/tpm"
    if [[ -d "$tpm_dir/.git" ]]; then
        log_success "TPM already installed: $tpm_dir"
    else
        log_info "Cloning TPM into $tpm_dir"
        run_as_user git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir"
        log_success "TPM installed"
    fi

    # Install the plugins declared in ~/.tmux.conf without an interactive session
    if [[ -x "$tpm_dir/bin/install_plugins" ]]; then
        log_info "Installing tmux plugins (resurrect, continuum)..."
        run_as_user "$tpm_dir/bin/install_plugins" || \
            log_warning "Automatic plugin install failed; run 'prefix + I' inside tmux"
    else
        log_warning "TPM installer not found; run 'prefix + I' inside tmux to install plugins"
    fi
    echo
}

check_path() {
    log_info "Checking if ~/.local/bin is in PATH..."

    # Check the user's own login PATH, not root's reset PATH under sudo.
    local user_path
    user_path="$(run_as_user bash -lc 'printf %s "$PATH"' 2>/dev/null || printf %s "$PATH")"

    if [[ ":$user_path:" != *":$HOME/.local/bin:"* ]]; then
        log_warning "~/.local/bin is not in your PATH"
        log_info "Add this line to your .zshrc or .bashrc:"
        echo -e "    ${GREEN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        echo
    else
        log_success "~/.local/bin is already in PATH"
    fi
}

# Undo root-owned files that earlier runs of this script left in the user's
# home. Safe to run repeatedly; only touches paths this script manages.
repair_ownership() {
    log_info "Checking ownership of user files..."
    echo

    local group
    group="$(id -gn "$REAL_USER")"

    local paths=(
        "$REAL_HOME/.cargo"
        "$REAL_HOME/.rustup"
        "$REAL_HOME/.atuin"
        "$REAL_HOME/.oh-my-zsh"
        "$REAL_HOME/.tmux"
        "$REAL_HOME/.local/bin"
        "$REAL_HOME/.local/share/atuin"
        "$DOTFILES_DIR"
    )
    for dest in "${DOTFILES[@]}"; do paths+=("$dest"); done
    for dest in "${CONFIG_DIRS[@]}"; do paths+=("$dest"); done

    local target found=0
    for target in "${paths[@]}"; do
        [[ -e "$target" || -L "$target" ]] || continue
        # -print -quit stops at the first offender, so this stays cheap.
        if [[ -z "$(find "$target" ! -user "$REAL_USER" -print -quit 2>/dev/null)" ]]; then
            continue
        fi
        found=$((found + 1))
        if [[ $EUID -eq 0 ]]; then
            # -h so a root-owned symlink is fixed without following it.
            chown -R -h "$REAL_USER:$group" "$target"
            log_success "Fixed ownership: $target"
        else
            log_warning "Root-owned files under: $target"
        fi
    done

    if [[ $found -eq 0 ]]; then
        log_success "All managed files are owned by $REAL_USER"
    elif [[ $EUID -ne 0 ]]; then
        log_info "Re-run with sudo to fix: sudo $0 repair"
    fi
    echo
}

#===============================================================================
# Uninstall Function
#===============================================================================

uninstall() {
    log_info "Uninstalling dotfiles (removing symlinks)..."
    echo
    
    local all_links=()
    
    # Collect all destinations
    for dest in "${DOTFILES[@]}"; do all_links+=("$dest"); done
    for dest in "${CONFIG_DIRS[@]}"; do all_links+=("$dest"); done
    if [[ ${#CUSTOM_SCRIPTS[@]} -gt 0 ]]; then
        for dest in "${CUSTOM_SCRIPTS[@]}"; do all_links+=("$dest"); done
    fi
    
    for dest in "${all_links[@]}"; do
        if [[ -L "$dest" ]]; then
            local target
            target="$(readlink "$dest")"
            if [[ "$target" == "$DOTFILES_DIR"* ]]; then
                rm "$dest"
                log_success "Removed symlink: $dest"
            fi
        fi
    done
    
    # System files are copies, not symlinks, so they need removing explicitly.
    for source in "${!SYSTEM_FILES[@]}"; do
        local dest="${SYSTEM_FILES[$source]}"
        if [[ -f "$dest" ]] && cmp -s "$DOTFILES_DIR/$source" "$dest"; then
            $SUDO rm -f "$dest"
            log_success "Removed system file: $dest"
        elif [[ -f "$dest" ]]; then
            log_warning "Left in place (modified since install): $dest"
        fi
    done

    log_info "Uninstall complete. Check .backup directory to restore original files."
}

#===============================================================================
# Main
#===============================================================================

show_help() {
    cat << EOF
Dotfiles Installation Script (Multi-Distro)

Usage: $(basename "$0") [command]

Commands:
    install     Install everything (default)
    uninstall   Remove all symlinks created by this script
    repair      Fix root-owned files left in \$HOME by an earlier sudo run
    help        Show this help message

Supported Distros:
    - Debian/Ubuntu (apt)
    - Fedora (dnf)
    - RHEL/CentOS/Rocky/Alma (dnf/yum)
    - Arch/Manjaro (pacman)
    - openSUSE (zypper)
    - Alpine (apk)
    - Void (xbps)
    - Gentoo (emerge)
    - NixOS (nix-env)

The script will:
  1. Detect your Linux distribution and package manager
  2. Install dependencies (git, curl)
  3. Install Zsh and set it as default shell
  4. Install Oh-My-Zsh framework
  5. Install Powerlevel10k theme
  6. Install popular Zsh plugins (autosuggestions, syntax-highlighting, completions)
  7. Install Touchegg and enable touchegg.service (touchpad gestures)
  8. Create symlinks from this repo to their correct locations
  9. Copy system files (e.g. Xorg touchpad config) into place, root-owned
 10. Backup any existing files before overwriting

Backups are stored in: $DOTFILES_DIR/.backup/

Edit the configuration arrays in this script to customize which files are linked.
EOF
}

main() {
    local command="${1:-install}"

    echo
    echo "========================================"
    echo "  Dotfiles Installation Script"
    echo "  Repository: $DOTFILES_DIR"
    echo "  Target User: $REAL_USER"
    echo "  Target Home: $HOME"
    echo "========================================"
    echo
    
    case "$command" in
        install)
            show_distro_info
            install_dependencies
            install_ripgrep
            install_neovim
            install_rust
            install_alacritty
            install_touchegg
            install_atuin
            install_zsh
            install_oh_my_zsh
            install_powerlevel10k
            install_zsh_plugins
            install_dotfiles
            install_config_dirs
            install_omz_custom
            install_custom_scripts
            install_system_files
            install_tmux_plugins
            repair_ownership
            check_path

            log_success "Installation complete!"
            log_info "Backups stored in: $DOTFILES_DIR/.backup/"
            echo
            log_warning "Remember to log out and back in for shell changes to take effect!"
            ;;
        uninstall)
            uninstall
            ;;
        repair)
            repair_ownership
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
