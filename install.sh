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
            PKG_INSTALL="sudo apt update && sudo apt install -y"
            ;;
        fedora)
            PKG_MANAGER="dnf"
            PKG_INSTALL="sudo dnf install -y"
            ;;
        rhel|centos|rocky|alma|oracle)
            # Check if dnf is available (RHEL 8+), otherwise use yum
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
                PKG_INSTALL="sudo dnf install -y"
            else
                PKG_MANAGER="yum"
                PKG_INSTALL="sudo yum install -y"
            fi
            ;;
        arch|manjaro|endeavouros|garuda)
            PKG_MANAGER="pacman"
            PKG_INSTALL="sudo pacman -S --noconfirm"
            ;;
        opensuse*|suse|sles)
            PKG_MANAGER="zypper"
            PKG_INSTALL="sudo zypper install -y"
            ;;
        alpine)
            PKG_MANAGER="apk"
            PKG_INSTALL="sudo apk add"
            ;;
        void)
            PKG_MANAGER="xbps"
            PKG_INSTALL="sudo xbps-install -y"
            ;;
        gentoo)
            PKG_MANAGER="emerge"
            PKG_INSTALL="sudo emerge"
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
                    PKG_INSTALL="sudo apt update && sudo apt install -y"
                    ;;
                *rhel*|*fedora*|*centos*)
                    if command -v dnf &> /dev/null; then
                        PKG_MANAGER="dnf"
                        PKG_INSTALL="sudo dnf install -y"
                    else
                        PKG_MANAGER="yum"
                        PKG_INSTALL="sudo yum install -y"
                    fi
                    ;;
                *arch*)
                    PKG_MANAGER="pacman"
                    PKG_INSTALL="sudo pacman -S --noconfirm"
                    ;;
                *suse*)
                    PKG_MANAGER="zypper"
                    PKG_INSTALL="sudo zypper install -y"
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
    # Add more as needed
)

# Oh-My-Zsh custom directory (themes and plugins)
declare -A OMZ_CUSTOM=(
    [".oh-my-zsh/custom/themes"]="$HOME/.oh-my-zsh/custom/themes"
    [".oh-my-zsh/custom/plugins"]="$HOME/.oh-my-zsh/custom/plugins"
)

# Custom scripts with specific destinations
declare -A CUSTOM_SCRIPTS=(
    ["scripts/tmux-session"]="$HOME/.local/bin/tmux-session"
    # Add more custom scripts here
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
    
    if [[ "$current_shell" == "$zsh_path" ]]; then
        log_success "Zsh is already the default shell"
    else
        log_info "Setting Zsh as default shell..."
        
        # Ensure zsh is in /etc/shells
        if ! grep -q "^$zsh_path$" /etc/shells; then
            log_info "Adding $zsh_path to /etc/shells"
            echo "$zsh_path" | sudo tee -a /etc/shells > /dev/null
        fi
        
        # Change default shell
        chsh -s "$zsh_path"
        log_success "Default shell changed to Zsh"
        log_warning "Please log out and log back in for the shell change to take effect"
    fi
    echo
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
    
    log_info "Building Neovim from source..."
    
    # Install build dependencies
    local nvim_deps
    nvim_deps="$(get_nvim_build_deps)"
    log_info "Installing Neovim build dependencies: $nvim_deps"
    
    case "$PKG_MANAGER" in
        apt)
            sudo apt update && sudo apt install -y $nvim_deps
            ;;
        dnf)
            sudo dnf install -y $nvim_deps
            ;;
        yum)
            sudo yum install -y $nvim_deps
            ;;
        pacman)
            sudo pacman -S --noconfirm $nvim_deps
            ;;
        zypper)
            sudo zypper install -y $nvim_deps
            ;;
        apk)
            sudo apk add $nvim_deps
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
    sudo make install
    
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
        mkdir -p "$HOME/.local/bin"
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
    for dest in "${CUSTOM_SCRIPTS[@]}"; do all_links+=("$dest"); done
    
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
    echo "========================================"
    echo
    
    case "$command" in
        install)
            show_distro_info
            install_dependencies
            install_ripgrep
            install_neovim
            install_rust
            install_atuin
            install_zsh
            install_oh_my_zsh
            install_powerlevel10k
            install_zsh_plugins
            install_dotfiles
            install_config_dirs
            install_omz_custom
            install_custom_scripts
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
