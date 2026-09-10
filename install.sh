#!/usr/bin/env bash

#===============================================================================
# Dotfiles Installation Script
# Creates symlinks from this repo to their correct locations in the system
#===============================================================================

set -euo pipefail

# macOS ships bash 3.2, which lacks the associative arrays (declare -A) this
# script relies on. Bail out early with instructions instead of a cryptic error.
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "ERROR: bash >= 4 required (found $BASH_VERSION)."
    echo "On macOS run:  brew install bash  then re-run with:  /opt/homebrew/bin/bash $0"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# nvm release to install (see https://github.com/nvm-sh/nvm/releases)
NVM_VERSION="v0.40.6"

# Get the directory where this script is located (the dotfiles repo)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect the real user's home directory (even when run with sudo)
if [[ -n "${SUDO_USER:-}" ]]; then
    # Running with sudo - get the actual user's home directory
    REAL_USER="$SUDO_USER"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        REAL_HOME=$(dscl . -read "/Users/$SUDO_USER" NFSHomeDirectory | awk '{print $2}')
    else
        REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    fi
else
    # Not running with sudo - use USER if set, otherwise get from whoami
    REAL_USER="${USER:-$(whoami)}"
    REAL_HOME="${HOME:-$(eval echo ~$REAL_USER)}"
fi

# Override HOME to use the real user's home directory
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
    # macOS: use Homebrew (bootstrap it if missing)
    if [[ "$(uname -s)" == "Darwin" ]]; then
        DISTRO_ID="macos"
        DISTRO_NAME="macOS"
        DISTRO_VERSION="$(sw_vers -productVersion 2>/dev/null || echo '')"
        DISTRO_ID_LIKE=""
        PKG_MANAGER="brew"
        PKG_INSTALL="brew install"
        return
    fi

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
        go)
            case "$PKG_MANAGER" in
                apt) echo "golang-go" ;;
                dnf|yum) echo "golang" ;;
                pacman) echo "go" ;;
                zypper) echo "go" ;;
                apk) echo "go" ;;
                xbps) echo "go" ;;
                emerge) echo "dev-lang/go" ;;
                nix-env) echo "go" ;;
                *) echo "go" ;;
            esac
            ;;
        docker)
            case "$PKG_MANAGER" in
                apt) echo "docker.io" ;;
                dnf|yum) echo "moby-engine" ;;
                pacman) echo "docker" ;;
                zypper) echo "docker" ;;
                apk) echo "docker" ;;
                xbps) echo "docker" ;;
                emerge) echo "app-containers/docker" ;;
                nix-env) echo "docker" ;;
                *) echo "docker" ;;
            esac
            ;;
        docker-compose)
            case "$PKG_MANAGER" in
                apt) echo "docker-compose-v2" ;;
                dnf|yum) echo "docker-compose" ;;
                pacman) echo "docker-compose" ;;
                zypper) echo "docker-compose" ;;
                apk) echo "docker-cli-compose" ;;
                xbps) echo "docker-compose" ;;
                emerge) echo "app-containers/docker-compose" ;;
                nix-env) echo "docker-compose" ;;
                *) echo "docker-compose" ;;
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

# Bootstrap Homebrew on macOS if it isn't installed yet
install_homebrew() {
    if [[ "$PKG_MANAGER" != "brew" ]]; then
        return 0
    fi

    if command -v brew &> /dev/null; then
        log_success "Homebrew is already installed: $(brew --version | head -1)"
    else
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Apple Silicon installs to /opt/homebrew, which is not on PATH by default
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    echo
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

    # macOS Cocoa key bindings (skipped on Linux by install_dotfiles)
    ["Library/KeyBindings/DefaultKeyBinding.dict"]="$HOME/Library/KeyBindings/DefaultKeyBinding.dict"
)

# Config directories: source (relative to repo) -> destination (absolute path)
# These are directories inside .config that should be symlinked
declare -A CONFIG_DIRS=(
    [".config/nvim"]="$HOME/.config/nvim"
    [".config/starship.toml"]="$HOME/.config/starship.toml"
    [".config/tmux"]="$HOME/.config/tmux"
    [".config/i3"]="$HOME/.config/i3"
    [".config/aerospace"]="$HOME/.config/aerospace"
    [".config/alacritty"]="$HOME/.config/alacritty"
    [".config/ghostty"]="$HOME/.config/ghostty"
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
        mkdir -p "$dest_dir"
    fi
    
    # Handle existing file/directory at destination
    if [[ -e "$dest" || -L "$dest" ]]; then
        # Check if it's already the correct symlink
        if [[ -L "$dest" ]] && [[ "$(readlink -f "$dest")" == "$(readlink -f "$source")" ]]; then
            log_success "Already linked: $dest -> $source"
            return 0
        fi
        
        # Backup existing file
        mkdir -p "$backup_dir"
        local backup_path="$backup_dir/$(basename "$dest")"
        log_warning "Backing up existing: $dest -> $backup_path"
        mv "$dest" "$backup_path"
    fi
    
    # Create the symlink
    ln -s "$source" "$dest"
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
    
    if command -v rustc &> /dev/null && command -v cargo &> /dev/null; then
        log_success "Rust is already installed: $(rustc --version)"
        log_success "Cargo is available: $(cargo --version)"
    else
        log_info "Installing Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        
        # Source cargo env for current session
        if [[ -f "$HOME/.cargo/env" ]]; then
            source "$HOME/.cargo/env"
        fi
        
        log_success "Rust installed: $(rustc --version)"
        log_success "Cargo installed: $(cargo --version)"
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
    # macOS uses Ghostty instead (Alacritty is unnotarized; Gatekeeper blocks it)
    if [[ "$PKG_MANAGER" == "brew" ]]; then
        return 0
    fi

    log_info "Checking Alacritty installation..."
    echo

    if command -v alacritty &> /dev/null; then
        log_success "Alacritty is already installed: $(alacritty --version)"
        echo
        return 0
    fi

    log_info "Installing Alacritty via $PKG_MANAGER..."
    pkg_install alacritty

    # Some distros don't package Alacritty; fall back to cargo (needs Rust).
    if ! command -v alacritty &> /dev/null; then
        if command -v cargo &> /dev/null; then
            log_warning "Package install failed; building Alacritty via cargo..."
            cargo install alacritty
        else
            log_error "Could not install Alacritty automatically; install it manually."
        fi
    fi

    if command -v alacritty &> /dev/null; then
        log_success "Alacritty installed: $(alacritty --version)"
    fi
    echo
}

# Ghostty: terminal of choice on macOS (signed + notarized, unlike Alacritty)
install_ghostty() {
    if [[ "$PKG_MANAGER" != "brew" ]]; then
        return 0
    fi

    log_info "Checking Ghostty installation..."
    echo

    if [[ -d "/Applications/Ghostty.app" ]] || command -v ghostty &> /dev/null; then
        log_success "Ghostty is already installed"
    else
        log_info "Installing Ghostty via Homebrew cask..."
        brew install --cask ghostty
        log_success "Ghostty installed"
    fi
    echo
}

# Maccy: clipboard manager on macOS (CopyQ equivalent; hotkey is set in-app)
install_maccy() {
    if [[ "$PKG_MANAGER" != "brew" ]]; then
        return 0
    fi

    log_info "Checking Maccy installation..."
    echo

    if [[ -d "/Applications/Maccy.app" ]]; then
        log_success "Maccy is already installed"
    else
        log_info "Installing Maccy via Homebrew cask..."
        brew install --cask maccy
        log_success "Maccy installed (launch it once and set your popup hotkey)"
    fi
    echo
}

# AeroSpace: i3-like tiling window manager for macOS (config mirrors .config/i3)
install_aerospace() {
    if [[ "$PKG_MANAGER" != "brew" ]]; then
        return 0
    fi

    log_info "Checking AeroSpace installation..."
    echo

    if command -v aerospace &> /dev/null || [[ -d "/Applications/AeroSpace.app" ]]; then
        log_success "AeroSpace is already installed"
    else
        log_info "Installing AeroSpace via Homebrew cask..."
        brew install --cask nikitabobko/tap/aerospace
        log_success "AeroSpace installed (grant Accessibility permission on first launch)"
    fi
    echo
}

# zoxide: smarter cd — .zshrc aliases z='zi' and runs zoxide init
install_zoxide() {
    log_info "Checking zoxide installation..."
    echo

    if command -v zoxide &> /dev/null; then
        log_success "zoxide is already installed: $(zoxide --version)"
    else
        log_info "Installing zoxide..."
        pkg_install zoxide
        log_success "zoxide installed"
    fi
    echo
}

# fzf: fuzzy finder — required by zoxide's zi interactive picker
install_fzf() {
    log_info "Checking fzf installation..."
    echo

    if command -v fzf &> /dev/null; then
        log_success "fzf is already installed: $(fzf --version)"
    else
        log_info "Installing fzf..."
        pkg_install fzf
        log_success "fzf installed"
    fi
    echo
}

# Go toolchain: package-managed so upgrades ride along with the system
install_go() {
    log_info "Checking Go installation..."
    echo

    if command -v go &> /dev/null; then
        log_success "Go is already installed: $(go version)"
    else
        log_info "Installing Go..."
        pkg_install go
        log_success "Go installed"
        log_info "GOPATH defaults to ~/go; binaries land in ~/go/bin"
    fi
    echo
}

# nvm: Node version manager. .zshrc already sources $NVM_DIR/nvm.sh, and .zshrc
# is a symlink into this repo, so PROFILE=/dev/null keeps the upstream installer
# from appending a duplicate init block to it.
install_nvm() {
    log_info "Checking nvm installation..."
    echo

    if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
        log_success "nvm is already installed: $(. "$HOME/.nvm/nvm.sh" && nvm --version)"
    else
        log_info "Installing nvm $NVM_VERSION..."
        PROFILE=/dev/null bash -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"
        log_success "nvm installed"
        log_info "Open a new shell, then run 'nvm install --lts' to get Node"
    fi
    echo
}

# Homebrew keeps compose in its own prefix; the Docker CLI only discovers
# plugins there once the directory is registered in ~/.docker/config.json.
register_docker_cli_plugins() {
    local plugin_dir config
    plugin_dir="$(brew --prefix)/lib/docker/cli-plugins"
    config="$HOME/.docker/config.json"

    if [[ -f "$config" ]] && grep -q "$plugin_dir" "$config"; then
        log_success "Compose plugin directory already registered"
        return 0
    fi

    if [[ ! -s "$config" ]]; then
        mkdir -p "$HOME/.docker"
        cat > "$config" << EOF
{
  "cliPluginsExtraDirs": [
    "$plugin_dir"
  ]
}
EOF
        log_success "Registered compose plugin directory in $config"
    else
        # Something already lives in the config; editing JSON blind would risk
        # clobbering it, so hand the change back to the user.
        log_warning "$config already exists - add this key manually:"
        echo -e "    ${GREEN}\"cliPluginsExtraDirs\": [\"$plugin_dir\"]${NC}"
    fi
}

# Colima as a login service. `brew services` runs `colima start -f` with no
# flags of its own, so it inherits whatever sizing is saved in ~/.colima - the
# VM has to be provisioned at the sizes we want before the service is created.
register_colima_service() {
    local status
    status="$(brew services list 2>/dev/null | awk '$1 == "colima" { print $2 }')"

    if [[ "$status" == "started" ]]; then
        log_success "Colima already starts at login"
        return 0
    fi

    if colima status &> /dev/null; then
        # Handing a running VM to launchd means stopping it first, which takes
        # any running containers down with it. That is the user's call to make.
        log_warning "Colima is running but is not registered as a login service"
        log_info "To hand it over to launchd (this restarts the VM):"
        echo -e "    ${GREEN}colima stop && brew services start colima${NC}"
        return 0
    fi

    if [[ ! -f "$HOME/.colima/default/colima.yaml" ]]; then
        log_info "Provisioning the Colima VM - the first boot takes a few minutes..."
        if ! colima start --cpu 6 --memory 12 --disk 100 --vm-type vz --vz-rosetta; then
            log_warning "Could not provision the Colima VM - run 'colima start' to see why"
            return 1
        fi
        # Sizing is now saved; hand the VM over to launchd to own from here.
        colima stop &> /dev/null
    fi

    log_info "Registering Colima to start at login..."
    if brew services start colima &> /dev/null; then
        log_success "Colima will start at login - docker is ready once the VM boots"
    else
        log_warning "Could not register the service - start it with 'brew services start colima'"
    fi
}

# Docker. macOS cannot run containers natively, so Colima supplies the Linux VM
# behind the standard docker CLI - open source, with none of the Docker Desktop
# licensing conditions that apply to business use. Linux runs the engine direct.
install_docker() {
    log_info "Checking Docker installation..."
    echo

    if command -v docker &> /dev/null; then
        log_success "Docker is already installed: $(docker --version)"
    else
        log_info "Installing Docker..."
        pkg_install docker
        log_success "Docker installed"
    fi

    if docker compose version &> /dev/null; then
        log_success "Docker Compose is already installed: $(docker compose version --short)"
    else
        log_info "Installing Docker Compose..."
        pkg_install docker-compose
        [[ "$PKG_MANAGER" == "brew" ]] && register_docker_cli_plugins
        log_success "Docker Compose installed"
    fi

    if [[ "$PKG_MANAGER" == "brew" ]]; then
        if command -v colima &> /dev/null; then
            log_success "Colima is already installed: $(colima version | head -1)"
        else
            log_info "Installing Colima (Docker Desktop replacement)..."
            pkg_install colima
            log_success "Colima installed"
        fi

        register_colima_service
    else
        # Linux: the daemon is a system service and needs group membership
        # before the CLI works without sudo.
        if command -v systemctl &> /dev/null; then
            log_info "Enabling the docker service..."
            $SUDO systemctl enable --now docker || log_warning "Could not enable docker.service"
        fi

        if id -nG "$REAL_USER" | grep -qw docker; then
            log_success "$REAL_USER is already in the docker group"
        else
            log_info "Adding $REAL_USER to the docker group..."
            $SUDO usermod -aG docker "$REAL_USER" || log_warning "Could not add $REAL_USER to the docker group"
            log_warning "Log out and back in for docker group membership to apply"
        fi
    fi
    echo
}

install_atuin() {
    log_info "Checking Atuin installation..."
    echo
    
    if command -v atuin &> /dev/null; then
        log_success "Atuin is already installed: $(atuin --version)"
    else
        log_info "Installing Atuin via install script..."
        curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
        
        # Source atuin env if available
        if [[ -f "$HOME/.atuin/bin/env" ]]; then
            source "$HOME/.atuin/bin/env"
        fi
        
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

    # macOS: install prebuilt via Homebrew instead of building from source
    if [[ "$PKG_MANAGER" == "brew" ]]; then
        pkg_install neovim
        log_success "Neovim installed: $(nvim --version | head -1)"
        echo
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
        # Install without running zsh immediately (RUNZSH=no)
        # Don't change shell again (CHSH=no) since we already did it
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
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
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
        log_success "Powerlevel10k installed"
        log_info "Make sure ZSH_THEME=\"powerlevel10k/powerlevel10k\" is set in your .zshrc"
    fi
    echo
}

install_zsh_plugins() {
    log_info "Installing popular Zsh plugins..."
    echo
    
    local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    
    # zsh-autosuggestions
    if [[ -d "$custom_dir/zsh-autosuggestions" ]]; then
        log_success "zsh-autosuggestions already installed"
    else
        log_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$custom_dir/zsh-autosuggestions"
        log_success "zsh-autosuggestions installed"
    fi
    
    # zsh-syntax-highlighting
    if [[ -d "$custom_dir/zsh-syntax-highlighting" ]]; then
        log_success "zsh-syntax-highlighting already installed"
    else
        log_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$custom_dir/zsh-syntax-highlighting"
        log_success "zsh-syntax-highlighting installed"
    fi
    
    # fast-syntax-highlighting (alternative to zsh-syntax-highlighting)
    if [[ -d "$custom_dir/fast-syntax-highlighting" ]]; then
        log_success "fast-syntax-highlighting already installed"
    else
        log_info "Installing fast-syntax-highlighting..."
        git clone https://github.com/zdharma-continuum/fast-syntax-highlighting "$custom_dir/fast-syntax-highlighting"
        log_success "fast-syntax-highlighting installed"
    fi
    
    # zsh-completions
    if [[ -d "$custom_dir/zsh-completions" ]]; then
        log_success "zsh-completions already installed"
    else
        log_info "Installing zsh-completions..."
        git clone https://github.com/zsh-users/zsh-completions "$custom_dir/zsh-completions"
        log_success "zsh-completions installed"
    fi
    
    log_info "Add these plugins to your .zshrc plugins array:"
    echo -e "    ${GREEN}plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)${NC}"
    echo
}

install_dotfiles() {
    log_info "Installing standard dotfiles..."
    echo
    
    for source in "${!DOTFILES[@]}"; do
        # ~/Library is macOS-only; nothing reads it on Linux
        if [[ "$(uname -s)" != "Darwin" && "$source" == Library/* ]]; then
            log_info "Skipping $source (macOS-only)"
            continue
        fi
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
        # i3 is X11-only; skip it on macOS (AeroSpace replaces it there)
        if [[ "$(uname -s)" == "Darwin" && "$source" == ".config/i3" ]]; then
            log_info "Skipping $source (i3 is Linux/X11-only)"
            continue
        fi
        # AeroSpace is macOS-only; skip it on Linux
        if [[ "$(uname -s)" != "Darwin" && "$source" == ".config/aerospace" ]]; then
            log_info "Skipping $source (AeroSpace is macOS-only)"
            continue
        fi
        local full_source="$DOTFILES_DIR/$source"
        local dest="${CONFIG_DIRS[$source]}"
        create_symlink "$full_source" "$dest"
    done
    echo
}

install_keyboard_layouts() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        log_info "Skipping keyboard layouts (macOS-only)"
        return
    fi

    log_info "Installing keyboard layouts..."
    echo

    local src_dir="$DOTFILES_DIR/Library/Keyboard Layouts"
    local dest_dir="$HOME/Library/Keyboard Layouts"

    if [[ ! -d "$src_dir" ]]; then
        log_info "No keyboard layouts to install"
        echo
        return
    fi

    mkdir -p "$dest_dir"

    # HIToolbox does not reliably load symlinked .keylayout files, so copy them
    # rather than going through create_symlink like the rest of the dotfiles.
    local layout dest
    for layout in "$src_dir"/*.keylayout; do
        [[ -e "$layout" ]] || continue
        dest="$dest_dir/$(basename "$layout")"
        if [[ -f "$dest" ]] && cmp -s "$layout" "$dest"; then
            log_info "Already current: $dest"
        else
            cp "$layout" "$dest"
            log_success "Installed: $dest"
        fi
    done

    log_info "Add layouts under System Settings > Keyboard > Text Input > Input Sources > Edit > + > Others"
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
        mkdir -p "$HOME/.local/bin"
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
            chmod +x "$full_source"
        fi
    done
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
        git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir"
        log_success "TPM installed"
    fi

    # Install the plugins declared in ~/.tmux.conf without an interactive session
    if [[ -x "$tpm_dir/bin/install_plugins" ]]; then
        log_info "Installing tmux plugins (resurrect, continuum)..."
        "$tpm_dir/bin/install_plugins" || \
            log_warning "Automatic plugin install failed; run 'prefix + I' inside tmux"
    else
        log_warning "TPM installer not found; run 'prefix + I' inside tmux to install plugins"
    fi
    echo
}

check_path() {
    log_info "Checking if ~/.local/bin is in PATH..."
    
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        log_warning "~/.local/bin is not in your PATH"
        log_info "Add this line to your .zshrc or .bashrc:"
        echo -e "    ${GREEN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        echo
    else
        log_success "~/.local/bin is already in PATH"
    fi
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
    help        Show this help message

Supported Systems:
    - macOS / Apple Silicon (Homebrew; needs bash >= 4: brew install bash)
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
  7. Create symlinks from this repo to their correct locations
  8. Backup any existing files before overwriting

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
            install_homebrew
            install_dependencies
            install_ripgrep
            install_neovim
            install_rust
            install_alacritty
            install_ghostty
            install_aerospace
            install_maccy
            install_zoxide
            install_fzf
            install_go
            install_nvm
            install_docker
            install_atuin
            install_zsh
            install_oh_my_zsh
            install_powerlevel10k
            install_zsh_plugins
            install_dotfiles
            install_config_dirs
            install_keyboard_layouts
            install_omz_custom
            install_custom_scripts
            install_tmux_plugins
            check_path

            log_success "Installation complete!"
            log_info "Backups stored in: $DOTFILES_DIR/.backup/"
            echo
            log_warning "Remember to log out and back in for shell changes to take effect!"
            ;;
        uninstall)
            uninstall
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
