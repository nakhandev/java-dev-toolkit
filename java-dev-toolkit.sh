#!/bin/bash

# 🧩 Java Developer Toolkit - Unified Development Tool
# Advanced, feature-rich development environment management script
# Combines setup, start, monitoring, and deployment capabilities

set -euo pipefail  # Enhanced error handling

# =============================================================================
# CORE CONFIGURATION & GLOBAL VARIABLES
# =============================================================================

# Script metadata
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="java-dev-toolkit"
PROJECT_NAME="java-developer-toolkit"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color scheme for enhanced output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration files
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
CONFIG_FILE="$PROJECT_ROOT/.fjdtool.conf"
LOG_DIR="$PROJECT_ROOT/logs"
BACKUP_DIR="$PROJECT_ROOT/backups"

# Service ports
BACKEND_PORT="1998"
FRONTEND_PORT="3000"
POSTGRES_PORT="5432"
MONGO_PORT="27017"
REDIS_PORT="6379"

# Process IDs for service management
BACKEND_PID=""
FRONTEND_PID=""
MONITOR_PID=""

# System capabilities (detected during runtime)
OS=""
ARCH=""
CPU_CORES=""
TOTAL_MEM=""
AVAILABLE_DISK=""
USED_MEM=""
MEM_PERCENTAGE=""
CPU_USAGE=""
DEVICE_CLASS=""

# Service status tracking
declare -A SERVICE_STATUS=()
declare -A SERVICE_PIDS=()

# Configuration defaults
DEFAULT_SPRING_PROFILES="dev"
DEFAULT_JVM_HEAP_SIZE="1g"
DEFAULT_DB_POOL_SIZE="10"
DEFAULT_NODE_ENV="development"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Enhanced visual logging with attractive ASCII art styling
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Clear any active progress bars before logging
    if [ -n "${PROGRESS_SYSTEM_INITIALIZED:-}" ]; then
        printf "\r\033[2K\n" 2>/dev/null || true
    fi

    # Attractive console output with enhanced ASCII art styling
    case "$level" in
        "INFO")    echo -e "${GREEN}[==== INFO ====]${NC} $message" ;;
        "WARN")    echo -e "${YELLOW}[==== WARN ====]${NC} $message" ;;
        "ERROR")   echo -e "${RED}[==== ERROR ====]${NC} $message" >&2 ;;
        "SUCCESS") echo -e "${GREEN}[==== OK ====]${NC} $message" ;;
        "HEADER")  echo -e "${BLUE}[==== START ====]${NC} $message" ;;
        "DEBUG")   echo -e "${CYAN}[==== DEBUG ====]${NC} $message" ;;
        *)         echo -e "$message" ;;
    esac

    # File logging (unchanged)
    mkdir -p "$LOG_DIR"
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/fjdtool.log"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if port is in use
port_in_use() {
    local port="$1"
    command_exists lsof && lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1
}

# Get process ID by port
get_pid_by_port() {
    local port="$1"
    command_exists lsof && lsof -ti :"$port" 2>/dev/null || echo ""
}

# Enhanced spinner with better visual feedback (Much slower for readability)
show_spinner() {
    local pid="$1"
    local message="$2"
    local delay="0.3"
    local spinner_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

    echo -n "$message "

    while ps -p "$pid" >/dev/null 2>&1; do
        for char in "${spinner_chars[@]}"; do
            echo -ne "\b$char"
            sleep "$delay"
            if ! ps -p "$pid" >/dev/null 2>&1; then
                break 2
            fi
        done
    done
    echo -e "\b${GREEN}✓${NC}"
}

# =============================================================================
# ENHANCED PROGRESS BAR SYSTEM (From backup version with improvements)
# =============================================================================

# Terminal capability detection
PROGRESS_TERMINAL_WIDTH=80
PROGRESS_COLOR_SUPPORT=16
PROGRESS_UNICODE_SUPPORT=true
PROGRESS_ANIMATION_SPEED="normal"

# Progress bar styles configuration
declare -A PROGRESS_STYLES=(
    ["neon"]="NEON_CYBERPUNK"
    ["ocean"]="OCEAN_WAVE"
    ["retro"]="RETRO_GAMING"
    ["minimal"]="MINIMALIST"
    ["fire"]="FIRE"
    ["matrix"]="MATRIX_DIGITAL_RAIN"
    ["cyberpunk"]="CYBERPUNK_GLITCH"
    ["nature"]="NATURE_FOREST"
    ["space"]="SPACE_GALAXY"
    ["ascii"]="ASCII_ART_ANIMATED"
)

# Color gradients for different styles
declare -A NEON_COLORS=(
    [1]="\033[38;5;39m"  # Cyan
    [2]="\033[38;5;45m"  # Blue
    [3]="\033[38;5;51m"  # Light blue
    [4]="\033[38;5;87m"  # Bright cyan
    [5]="\033[38;5;123m" # Electric blue
)

declare -A OCEAN_COLORS=(
    [1]="\033[38;5;18m"  # Dark blue
    [2]="\033[38;5;25m"  # Medium blue
    [3]="\033[38;5;32m"  # Blue-green
    [4]="\033[38;5;39m"  # Cyan
    [5]="\033[38;5;45m"  # Light blue
)

declare -A RETRO_COLORS=(
    [1]="\033[38;5;232m" # Dark gray (almost black)
    [2]="\033[38;5;240m" # Medium gray
    [3]="\033[38;5;248m" # Light gray
    [4]="\033[38;5;255m" # White
    [5]="\033[38;5;235m" # Very dark gray
)

declare -A MINIMAL_COLORS=(
    [1]="\033[38;5;240m" # Dark gray
    [2]="\033[38;5;245m" # Light gray
    [3]="\033[38;5;250m" # Lighter gray
    [4]="\033[38;5;255m" # White
    [5]="\033[38;5;235m" # Very dark gray
)

declare -A FIRE_COLORS=(
    [1]="\033[38;5;52m"  # Dark red
    [2]="\033[38;5;88m"  # Red
    [3]="\033[38;5;124m" # Light red
    [4]="\033[38;5;160m" # Orange-red
    [5]="\033[38;5;196m" # Bright red
)

declare -A MATRIX_COLORS=(
    [1]="\033[38;5;22m"  # Dark green
    [2]="\033[38;5;28m"  # Green
    [3]="\033[38;5;34m"  # Bright green
    [4]="\033[38;5;40m"  # Light green
    [5]="\033[38;5;46m"  # Cyan green
)

declare -A CYBERPUNK_COLORS=(
    [1]="\033[38;5;201m" # Pink
    [2]="\033[38;5;165m" # Purple-pink
    [3]="\033[38;5;93m"  # Magenta
    [4]="\033[38;5;129m" # Purple
    [5]="\033[38;5;198m" # Hot pink
)

declare -A NATURE_COLORS=(
    [1]="\033[38;5;22m"  # Forest green
    [2]="\033[38;5;28m"  # Green
    [3]="\033[38;5;34m"  # Light green
    [4]="\033[38;5;70m"  # Brown
    [5]="\033[38;5;106m" # Light brown
)

declare -A SPACE_COLORS=(
    [1]="\033[38;5;18m"  # Deep blue
    [2]="\033[38;5;19m"  # Dark blue
    [3]="\033[38;5;20m"  # Blue
    [4]="\033[38;5;21m"  # Light blue
    [5]="\033[38;5;27m"  # Bright blue
)

# Progress state management
declare -A PROGRESS_STATE=()
declare -A PROGRESS_TIMERS=()
declare -A PROGRESS_ANIMATIONS=()

# Detect terminal capabilities with improved accuracy
detect_terminal_capabilities() {
    # Detect terminal width with multiple fallback methods and better validation
    PROGRESS_TERMINAL_WIDTH=""

    # Method 1: tput (most reliable)
    if command_exists tput; then
        PROGRESS_TERMINAL_WIDTH=$(tput cols 2>/dev/null | tr -d '[:space:]')
    fi

    # Method 2: stty size
    if [ -z "$PROGRESS_TERMINAL_WIDTH" ]; then
        PROGRESS_TERMINAL_WIDTH=$(stty size 2>/dev/null | cut -d' ' -f2 | tr -d '[:space:]')
    fi

    # Method 3: environment variables
    if [ -z "$PROGRESS_TERMINAL_WIDTH" ]; then
        PROGRESS_TERMINAL_WIDTH="${COLUMNS:-}"
    fi

    # Method 4: default fallback with validation
    if [ -z "$PROGRESS_TERMINAL_WIDTH" ] || ! [[ "$PROGRESS_TERMINAL_WIDTH" =~ ^[0-9]+$ ]]; then
        PROGRESS_TERMINAL_WIDTH=80
    fi

    # Ensure reasonable bounds with better limits
    if [ "$PROGRESS_TERMINAL_WIDTH" -lt 60 ]; then
        PROGRESS_TERMINAL_WIDTH=60
    elif [ "$PROGRESS_TERMINAL_WIDTH" -gt 120 ]; then
        PROGRESS_TERMINAL_WIDTH=120
    fi

    # Detect color support with better detection
    if [ -n "${COLORTERM:-}" ]; then
        PROGRESS_COLOR_SUPPORT="truecolor"
    elif [ "$(tput colors 2>/dev/null | tr -d '[:space:]' || echo 0)" -ge 256 ] 2>/dev/null; then
        PROGRESS_COLOR_SUPPORT=256
    elif [ "$(tput colors 2>/dev/null | tr -d '[:space:]' || echo 0)" -ge 16 ] 2>/dev/null; then
        PROGRESS_COLOR_SUPPORT=16
    else
        PROGRESS_COLOR_SUPPORT=0
    fi

    # Detect Unicode support (improved check)
    case "${LANG:-}" in
        *.UTF-8*|*.utf-8*|*.UTF8*|*.utf8*) PROGRESS_UNICODE_SUPPORT=true ;;
        *) PROGRESS_UNICODE_SUPPORT=false ;;
    esac

    # Set animation speed based on terminal capabilities
    if [ "$PROGRESS_COLOR_SUPPORT" = "truecolor" ] && [ "$PROGRESS_UNICODE_SUPPORT" = true ]; then
        PROGRESS_ANIMATION_SPEED="fast"
    elif [ "$PROGRESS_COLOR_SUPPORT" = 256 ]; then
        PROGRESS_ANIMATION_SPEED="normal"
    else
        PROGRESS_ANIMATION_SPEED="slow"
    fi

    log "DEBUG" "Terminal capabilities: ${PROGRESS_TERMINAL_WIDTH}x${PROGRESS_COLOR_SUPPORT}c Unicode:${PROGRESS_UNICODE_SUPPORT} Speed:${PROGRESS_ANIMATION_SPEED}"
}

# Initialize progress bar system (only once)
init_progress_system() {
    if [ -n "${PROGRESS_SYSTEM_INITIALIZED:-}" ]; then
        return 0
    fi
    detect_terminal_capabilities
    PROGRESS_SYSTEM_INITIALIZED=true
    log "DEBUG" "Progress bar system initialized"
}

# Cleanup progress system (only once)
cleanup_progress_system() {
    if [ -z "${PROGRESS_SYSTEM_INITIALIZED:-}" ]; then
        return 0
    fi

    # Stop all progress animations
    for progress_id in "${!PROGRESS_ANIMATIONS[@]}"; do
        stop_progress_animation "$progress_id"
    done

    # Clear progress state
    PROGRESS_STATE=()
    PROGRESS_TIMERS=()
    PROGRESS_ANIMATIONS=()
    PROGRESS_SYSTEM_INITIALIZED=""

    log "DEBUG" "Progress bar system cleaned up"
}

# Enhanced progress bar with multiple styles (Fixed for proper display)
show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Progress}"
    local style="${4:-minimal}"
    local progress_id="${5:-default}"

    # Input validation
    if ! [[ "$current" =~ ^[0-9]+$ ]] || ! [[ "$total" =~ ^[0-9]+$ ]]; then
        log "ERROR" "Progress values must be integers."
        return 1
    fi
    if [ "$total" -eq 0 ]; then total=1; fi

    # Initialize if first call
    if [ -z "${PROGRESS_STATE[$progress_id]:-}" ]; then
        PROGRESS_STATE[$progress_id]="$current/$total"
        PROGRESS_TIMERS[$progress_id]=$(date +%s)
        start_progress_animation "$progress_id" "$style" "$message"
        return
    fi

    # Update progress state
    PROGRESS_STATE[$progress_id]="$current/$total"

    # Calculate percentage and visual elements with improved width handling and bounds checking
    local percentage=0

    # Ensure current doesn't exceed total (prevent >100% display)
    if [ "$current" -gt "$total" ]; then
        current="$total"
    fi

    # Calculate percentage safely
    if [ "$total" -gt 0 ]; then
        percentage=$((current * 100 / total))
    fi

    # Ensure percentage doesn't exceed 100%
    if [ "$percentage" -gt 100 ]; then
        percentage=100
    fi

    # Simplified width calculation - more conservative terminal width usage
    local reserved_space=25  # Reduced for better compatibility
    local bar_width=$((PROGRESS_TERMINAL_WIDTH - reserved_space))

    # Ensure reasonable bar width bounds
    if [ "$bar_width" -lt 15 ]; then
        bar_width=15
    elif [ "$bar_width" -gt 40 ]; then
        bar_width=40
    fi

    # Simplified message length calculation - better space management
    local max_message_length=$((PROGRESS_TERMINAL_WIDTH - 45))  # Reserve space for progress elements
    if [ "${#message}" -gt "$max_message_length" ]; then
        message="${message:0:$((max_message_length - 3))}..."
    fi

    # Calculate completed bars safely
    local completed=$((current * bar_width / total))

    # Ensure completed doesn't exceed bar_width
    if [ "$completed" -gt "$bar_width" ]; then
        completed="$bar_width"
    fi

    local elapsed_time=$(( $(date +%s) - PROGRESS_TIMERS[$progress_id] ))

    # Format elapsed time
    local elapsed_formatted
    if [ "$elapsed_time" -lt 60 ]; then
        elapsed_formatted="${elapsed_time}s"
    elif [ "$elapsed_time" -lt 3600 ]; then
        elapsed_formatted="$((elapsed_time / 60))m $(printf '%02d' $((elapsed_time % 60)))s"
    else
        elapsed_formatted="$((elapsed_time / 3600))h $(((elapsed_time % 3600) / 60))m"
    fi

    # Calculate ETA
    local eta="calculating..."
    if [ "$current" -gt 0 ] && [ "$elapsed_time" -gt 0 ]; then
        local rate=$((current / elapsed_time))
        if [ "$rate" -gt 0 ]; then
            local remaining=$((total - current))
            local eta_seconds=$((remaining / rate))
            if [ "$eta_seconds" -lt 60 ]; then
                eta="${eta_seconds}s"
            elif [ "$eta_seconds" -lt 3600 ]; then
                eta="$((eta_seconds / 60))m $(printf '%02d' $((eta_seconds % 60)))s"
            else
                eta="$((eta_seconds / 3600))h $(((eta_seconds % 3600) / 60))m"
            fi
        fi
    fi

    # Clear previous progress bar content with improved method
    printf "\r\033[2K\r"
    # Ensure clean line clearing
    printf "\r"

    # Render progress bar based on style
    case "${style,,}" in
        "neon"|"neon_cyberpunk")
            render_neon_progress "$completed" "$bar_width" "$percentage" "$elapsed_formatted" "$eta" "$message"
            ;;
        "ocean"|"ocean_wave")
            render_ocean_progress "$completed" "$bar_width" "$percentage" "$elapsed_formatted" "$eta" "$message"
            ;;
        "retro"|"retro_gaming")
            render_retro_progress "$completed" "$bar_width" "$percentage" "$elapsed_formatted" "$eta" "$message"
            ;;
        "fire")
            render_fire_progress "$completed" "$bar_width" "$percentage" "$elapsed_formatted" "$eta" "$message"
            ;;
        "matrix"|"matrix_digital_rain")
            render_matrix_progress "$completed" "$bar_width" "$percentage" "$elapsed_formatted" "$eta" "$message"
            ;;
        "cyberpunk"|"cyberpunk_glitch")
            render_cyberpunk_progress "$completed" "$bar_width" "$percentage" "$elapsed_formatted" "$eta" "$message"
            ;;
        "nature"|"nature_forest")
            render_nature_progress "$completed" "$bar_width" "$percentage" "$elapsed_formatted" "$eta" "$message"
            ;;
        "space"|"space_galaxy")
            render_space_progress "$completed" "$bar_width" "$percentage" "$elapsed_formatted" "$eta" "$message"
            ;;
        "ascii"|"ascii_art_animated")
            render_ascii_progress "$completed" "$bar_width" "$percentage" "$elapsed_formatted" "$eta" "$message"
            ;;
        *)
            render_minimal_progress "$completed" "$bar_width" "$percentage" "$elapsed_formatted" "$eta" "$message"
            ;;
    esac
}

# Neon Cyberpunk style progress bar (Improved ANSI handling)
render_neon_progress() {
    local completed="$1"
    local bar_width="$2"
    local percentage="$3"
    local elapsed="$4"
    local eta="$5"
    local message="$6"

    # Clear entire line and position cursor at beginning
    printf "\r\033[2K\r"

    # Print message and progress bar on single line
    printf "${NEON_COLORS[4]}%-25s${NC} " "${message:0:25}"

    # Draw progress bar inline
    printf "${NEON_COLORS[2]}[${NC}"
    local color_index=1
    for ((i=1; i<=completed; i++)); do
        local color_key=$((color_index % 5 + 1))
        printf "${NEON_COLORS[$color_key]}▓${NC}"
        color_index=$((color_index + 1))
    done

    for ((i=completed+1; i<=bar_width; i++)); do
        printf "░"
    done

    printf "${NEON_COLORS[2]}]${NC} "

    # Print percentage and timing info
    printf "${NEON_COLORS[3]}%3d%%${NC} " "$percentage"
    printf "${NEON_COLORS[2]}[${elapsed} → ${eta}]${NC}"
}

# Ocean Wave style progress bar
render_ocean_progress() {
    local completed="$1"
    local bar_width="$2"
    local percentage="$3"
    local elapsed="$4"
    local eta="$5"
    local message="$6"

    printf "\r\033[2K"
    printf "${OCEAN_COLORS[4]}🌊 ${message}${NC} "
    printf "${OCEAN_COLORS[2]}[OCEAN WAVE]${NC}\n"
    printf "\r${OCEAN_COLORS[3]}│${NC} "

    local wave_chars=(" " "▃" "▄" "▅" "▆" "▇" "█" "▇" "▆" "▅" "▄" "▃")
    local wave_index=0

    for ((i=1; i<=completed; i++)); do
        local color_key=$((i * 5 / bar_width + 1))
        if [ "$color_key" -gt 5 ]; then color_key=5; fi
        printf "${OCEAN_COLORS[$color_key]}${wave_chars[$wave_index]}${NC}"
        wave_index=$(((wave_index + 1) % ${#wave_chars[@]}))
    done

    for ((i=completed+1; i<=bar_width; i++)); do
        printf " "
    done

    printf " ${OCEAN_COLORS[3]}│${NC} "
    printf "${OCEAN_COLORS[4]}%3d%%${NC} " "$percentage"
    printf "${OCEAN_COLORS[2]}[${elapsed} → ${eta}]${NC}"
}

# Retro Gaming style progress bar
render_retro_progress() {
    local completed="$1"
    local bar_width="$2"
    local percentage="$3"
    local elapsed="$4"
    local eta="$5"
    local message="$6"

    # Clear entire line and position cursor at beginning
    printf "\r\033[2K\r"

    # Print message and progress bar on single line
    printf "${RETRO_COLORS[3]}%-25s${NC} " "${message:0:25}"

    # Draw progress bar inline
    printf "${RETRO_COLORS[2]}[${NC}"
    local pixel_chars=("█" "▓" "▒" "░")
    local color_index=1

    for ((i=1; i<=completed; i++)); do
        local pixel_index=$((i % 4))
        local color_key=$((color_index % 5 + 1))
        printf "${RETRO_COLORS[$color_key]}${pixel_chars[$pixel_index]}${NC}"
        color_index=$((color_index + 1))
    done

    for ((i=completed+1; i<=bar_width; i++)); do
        printf "░"
    done

    printf "${RETRO_COLORS[2]}]${NC} "

    # Print percentage and timing info
    printf "${RETRO_COLORS[4]}%3d%%${NC} " "$percentage"
    printf "${RETRO_COLORS[1]}[${elapsed} → ${eta}]${NC}"
}

# Fire style progress bar
render_fire_progress() {
    local completed="$1"
    local bar_width="$2"
    local percentage="$3"
    local elapsed="$4"
    local eta="$5"
    local message="$6"

    # Clear entire line and position cursor at beginning
    printf "\r\033[2K\r"

    # Print message and progress bar on single line
    printf "${FIRE_COLORS[5]}%-25s${NC} " "${message:0:25}"

    # Draw progress bar inline
    printf "${FIRE_COLORS[3]}[${NC}"
    local flame_chars=(" " "▂" "▃" "▄" "▅" "▆" "▇" "█")
    local intensity=1

    for ((i=1; i<=completed; i++)); do
        local flame_index=$((intensity % 8))
        local color_key=$((intensity % 5 + 1))
        printf "${FIRE_COLORS[$color_key]}${flame_chars[$flame_index]}${NC}"
        intensity=$((intensity + 1))
    done

    for ((i=completed+1; i<=bar_width; i++)); do
        printf " "
    done

    printf "${FIRE_COLORS[3]}]${NC} "

    # Print percentage and timing info
    printf "${FIRE_COLORS[5]}%3d%%${NC} " "$percentage"
    printf "${FIRE_COLORS[3]}[${elapsed} → ${eta}]${NC}"
}

# Minimalist style progress bar (Fixed layout alignment)
render_minimal_progress() {
    local completed="$1"
    local bar_width="$2"
    local percentage="$3"
    local elapsed="$4"
    local eta="$5"
    local message="$6"

    # Clear entire line and position cursor at start
    printf "\r\033[2K\r"

    # Print message and progress bar on single line
    printf "${MINIMAL_COLORS[3]}%-30s${NC} " "${message:0:30}"

    # Draw progress bar inline
    printf "${MINIMAL_COLORS[2]}[${NC}"
    for ((i=1; i<=completed; i++)); do
        local shade=$((i * 4 / bar_width + 1))
        if [ "$shade" -gt 4 ]; then shade=4; fi
        printf "${MINIMAL_COLORS[$shade]}█${NC}"
    done

    for ((i=completed+1; i<=bar_width; i++)); do
        printf "░"
    done

    printf "${MINIMAL_COLORS[2]}]${NC} "

    # Print percentage and timing info
    printf "${MINIMAL_COLORS[1]}%3d%%${NC} " "$percentage"
    printf "${MINIMAL_COLORS[1]}[${elapsed} → ${eta}]${NC}"
}

# Matrix Digital Rain style progress bar
render_matrix_progress() {
    local completed="$1"
    local bar_width="$2"
    local percentage="$3"
    local elapsed="$4"
    local eta="$5"
    local message="$6"

    printf "\r\033[2K"
    printf "${MATRIX_COLORS[4]}┌─ ${message} ─┐${NC} "
    printf "${MATRIX_COLORS[2]}[MATRIX DIGITAL RAIN]${NC}\n"
    printf "\r${MATRIX_COLORS[3]}│${NC} "

    # Matrix-style falling characters effect
    local matrix_chars=("ｱ" "ｳ" "ｴ" "ｵ" "ｶ" "ｷ" "ｸ" "ｹ" "ｺ" "ｻ" "ｼ" "ｽ" "ｾ" "ｿ" "ﾀ" "ﾁ" "ﾂ" "ﾃ" "ﾄ" "ﾅ" "ﾆ" "ﾇ" "ﾈ" "ﾉ" "ﾊ" "ﾋ" "ﾌ" "ﾍ" "ﾎ" "ﾏ")
    local char_index=0

    for ((i=1; i<=completed; i++)); do
        local color_key=$((i * 5 / bar_width + 1))
        if [ "$color_key" -gt 5 ]; then color_key=5; fi
        printf "${MATRIX_COLORS[$color_key]}${matrix_chars[$((char_index % ${#matrix_chars[@]}))]}${NC}"
        char_index=$((char_index + 1))
    done

    for ((i=completed+1; i<=bar_width; i++)); do
        printf "░"
    done

    printf " ${MATRIX_COLORS[3]}│${NC} "
    printf "${MATRIX_COLORS[4]}%3d%%${NC} " "$percentage"
    printf "${MATRIX_COLORS[2]}[${elapsed} → ${eta}]${NC}"
}

# Cyberpunk Glitch style progress bar
render_cyberpunk_progress() {
    local completed="$1"
    local bar_width="$2"
    local percentage="$3"
    local elapsed="$4"
    local eta="$5"
    local message="$6"

    printf "\r\033[2K"
    printf "${CYBERPUNK_COLORS[5]}⚡ ${message}${NC} "
    printf "${CYBERPUNK_COLORS[3]}[CYBERPUNK GLITCH]${NC}\n"
    printf "\r${CYBERPUNK_COLORS[4]}│${NC} "

    # Glitch effect with shifting colors
    local glitch_chars=("█" "▓" "▒" "░" "▓" "█")
    local glitch_offset=$(( $(date +%s) % 3 ))

    for ((i=1; i<=completed; i++)); do
        local glitch_index=$(((i + glitch_offset) % ${#glitch_chars[@]}))
        local color_key=$((i * 5 / bar_width + 1))
        if [ "$color_key" -gt 5 ]; then color_key=5; fi

        # Random color switching for glitch effect
        if [ $((i % 7)) -eq 0 ]; then
            printf "${CYBERPUNK_COLORS[$((color_key % 5 + 1))]}${glitch_chars[$glitch_index]}${NC}"
        else
            printf "${CYBERPUNK_COLORS[$color_key]}${glitch_chars[$glitch_index]}${NC}"
        fi
    done

    for ((i=completed+1; i<=bar_width; i++)); do
        printf "░"
    done

    printf " ${CYBERPUNK_COLORS[4]}│${NC} "
    printf "${CYBERPUNK_COLORS[5]}%3d%%${NC} " "$percentage"
    printf "${CYBERPUNK_COLORS[2]}[${elapsed} → ${eta}]${NC}"
}

# Nature Forest style progress bar
render_nature_progress() {
    local completed="$1"
    local bar_width="$2"
    local percentage="$3"
    local elapsed="$4"
    local eta="$5"
    local message="$6"

    printf "\r\033[2K"
    printf "${NATURE_COLORS[3]}🌲 ${message}${NC} "
    printf "${NATURE_COLORS[2]}[NATURE FOREST]${NC}\n"
    printf "\r${NATURE_COLORS[4]}│${NC} "

    # Forest growth effect
    local tree_chars=("🌱" "🌿" "🌾" "🌵" "🌲" "🌳")
    local tree_index=0

    for ((i=1; i<=completed; i++)); do
        local tree_stage=$((i * 6 / bar_width))
        if [ "$tree_stage" -gt 5 ]; then tree_stage=5; fi

        local color_key=$((i * 5 / bar_width + 1))
        if [ "$color_key" -gt 5 ]; then color_key=5; fi

        printf "${NATURE_COLORS[$color_key]}${tree_chars[$tree_stage]}${NC}"
        tree_index=$((tree_index + 1))
    done

    for ((i=completed+1; i<=bar_width; i++)); do
        printf " "
    done

    printf " ${NATURE_COLORS[4]}│${NC} "
    printf "${NATURE_COLORS[3]}%3d%%${NC} " "$percentage"
    printf "${NATURE_COLORS[1]}[${elapsed} → ${eta}]${NC}"
}

# Space Galaxy style progress bar
render_space_progress() {
    local completed="$1"
    local bar_width="$2"
    local percentage="$3"
    local elapsed="$4"
    local eta="$5"
    local message="$6"

    printf "\r\033[2K"
    printf "${SPACE_COLORS[5]}🌌 ${message}${NC} "
    printf "${SPACE_COLORS[3]}[SPACE GALAXY]${NC}\n"
    printf "\r${SPACE_COLORS[4]}│${NC} "

    # Galaxy swirl effect
    local space_chars=("⭐" "🌟" "✨" "💫" "🌠" "⭐")
    local space_index=0

    for ((i=1; i<=completed; i++)); do
        local swirl=$((i * 6 / bar_width))
        if [ "$swirl" -gt 5 ]; then swirl=5; fi

        local color_key=$((i * 5 / bar_width + 1))
        if [ "$color_key" -gt 5 ]; then color_key=5; fi

        printf "${SPACE_COLORS[$color_key]}${space_chars[$swirl]}${NC}"
        space_index=$((space_index + 1))
    done

    for ((i=completed+1; i<=bar_width; i++)); do
        printf "░"
    done

    printf " ${SPACE_COLORS[4]}│${NC} "
    printf "${SPACE_COLORS[5]}%3d%%${NC} " "$percentage"
    printf "${SPACE_COLORS[2]}[${elapsed} → ${eta}]${NC}"
}

# ASCII Art Animated style progress bar
render_ascii_progress() {
    local completed="$1"
    local bar_width="$2"
    local percentage="$3"
    local elapsed="$4"
    local eta="$5"
    local message="$6"

    printf "\r\033[2K"
    printf "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║${NC} 🎨 ${message} ${CYAN}║${NC}\n"
    printf "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}\n"
    printf "${CYAN}║${NC} "

    # Animated ASCII art progress
    local ascii_chars=("█" "▓" "▒" "░" "▒" "▓")
    local ascii_index=0

    for ((i=1; i<=completed; i++)); do
        local char_variant=$((ascii_index % 6))
        printf "${ascii_chars[$char_variant]}"
        ascii_index=$((ascii_index + 1))
    done

    for ((i=completed+1; i<=bar_width; i++)); do
        printf "░"
    done

    printf " ${CYAN}║${NC} %3d%%" "$percentage"
    printf "\n${CYAN}║${NC} ⏱️  ${elapsed} → ${eta} ${CYAN}║${NC}"
    printf "\n${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
}

# Start progress animation
start_progress_animation() {
    local progress_id="$1"
    local style="$2"
    local message="$3"

    if [ -n "${PROGRESS_ANIMATIONS[$progress_id]:-}" ]; then
        stop_progress_animation "$progress_id"
    fi

    # Start animation in background only if not already running
    animate_progress "$progress_id" "$style" "$message" &
    PROGRESS_ANIMATIONS[$progress_id]=$!
}

# Stop progress animation
stop_progress_animation() {
    local progress_id="$1"

    if [ -n "${PROGRESS_ANIMATIONS[$progress_id]:-}" ]; then
        local pid_to_kill="${PROGRESS_ANIMATIONS[$progress_id]}"

        if ps -p "$pid_to_kill" >/dev/null 2>&1; then
            kill "$pid_to_kill" 2>/dev/null || true
            local attempts=0
            while ps -p "$pid_to_kill" >/dev/null 2>&1 && [ "$attempts" -lt 10 ]; do
                sleep 0.01
                attempts=$((attempts + 1))
            done
        fi

        unset PROGRESS_ANIMATIONS[$progress_id]
        printf "\r\033[2K"
    fi
}

# Animate progress bar
animate_progress() {
    local progress_id="$1"
    local style="$2"
    local message="$3"

    while true; do
        if [ -n "${PROGRESS_STATE[$progress_id]:-}" ]; then
            local IFS_BAK="$IFS"
            IFS='/' read -r current total <<< "${PROGRESS_STATE[$progress_id]}"
            IFS="$IFS_BAK"

            if [ -n "$current" ] && [ -n "$total" ]; then
                show_progress "$current" "$total" "$message" "$style" "$progress_id"
            fi
        fi

        # Check if we should continue animating
        if [ -z "${PROGRESS_STATE[$progress_id]:-}" ]; then
            break
        fi

        case "$PROGRESS_ANIMATION_SPEED" in
            "fast") sleep 0.05 ;;
            "normal") sleep 0.1 ;;
            "slow") sleep 0.2 ;;
        esac
    done
}

# Complete progress bar with celebration
complete_progress() {
    local message="${1:-Complete}"
    local style="${2:-minimal}"
    local progress_id="${3:-default}"

    # Stop animation
    stop_progress_animation "$progress_id"

    # Show final 100% state
    local final_current=100
    local final_total=100
    show_progress "$final_current" "$final_total" "Finished: $message" "$style" "$progress_id"
    printf "\n"

    # Show completion message
    case "${style,,}" in
        "neon"|"neon_cyberpunk")
            printf "${NEON_COLORS[5]}╔══════════════════════════════════════════════════════════╗${NC}\n"
            printf "${NEON_COLORS[5]}║${NC} ${NEON_COLORS[3]}OPERATION COMPLETE: ${message}${NC} ${NEON_COLORS[5]}║${NC}\n"
            printf "${NEON_COLORS[5]}╚══════════════════════════════════════════════════════════╝${NC}\n"
            ;;
        "ocean"|"ocean_wave")
            printf "${OCEAN_COLORS[4]}🌊 ✨ ${message} ✨ 🌊${NC}\n"
            ;;
        "retro"|"retro_gaming")
            printf "${RETRO_COLORS[3]}╔══════════════════════════════════════════════════════════╗${NC}\n"
            printf "${RETRO_COLORS[3]}║${NC} ${RETRO_COLORS[1]}OPERATION COMPLETE: ${message}${NC} ${RETRO_COLORS[3]}║${NC}\n"
            printf "${RETRO_COLORS[3]}╚══════════════════════════════════════════════════════════╝${NC}\n"
            ;;
        "fire")
            printf "${FIRE_COLORS[5]}🔥 ✨ ${message} ✨ 🔥${NC}\n"
            ;;
        "matrix"|"matrix_digital_rain")
            printf "${MATRIX_COLORS[4]}╔══════════════════════════════════════════════════════════╗${NC}\n"
            printf "${MATRIX_COLORS[4]}║${NC} ${MATRIX_COLORS[2]}MATRIX DOWNLOAD COMPLETE: ${message}${NC} ${MATRIX_COLORS[4]}║${NC}\n"
            printf "${MATRIX_COLORS[4]}╚══════════════════════════════════════════════════════════╝${NC}\n"
            ;;
        "cyberpunk"|"cyberpunk_glitch")
            printf "${CYBERPUNK_COLORS[5]}╔══════════════════════════════════════════════════════════╗${NC}\n"
            printf "${CYBERPUNK_COLORS[5]}║${NC} ${CYBERPUNK_COLORS[3]}GLITCH RESOLVED: ${message}${NC} ${CYBERPUNK_COLORS[5]}║${NC}\n"
            printf "${CYBERPUNK_COLORS[5]}╚══════════════════════════════════════════════════════════╝${NC}\n"
            ;;
        "nature"|"nature_forest")
            printf "${NATURE_COLORS[3]}╔══════════════════════════════════════════════════════════╗${NC}\n"
            printf "${NATURE_COLORS[3]}║${NC} ${NATURE_COLORS[1]}GROWTH COMPLETE: ${message}${NC} ${NATURE_COLORS[3]}║${NC}\n"
            printf "${NATURE_COLORS[3]}╚══════════════════════════════════════════════════════════╝${NC}\n"
            ;;
        "space"|"space_galaxy")
            printf "${SPACE_COLORS[5]}╔══════════════════════════════════════════════════════════╗${NC}\n"
            printf "${SPACE_COLORS[5]}║${NC} ${SPACE_COLORS[3]}MISSION ACCOMPLISHED: ${message}${NC} ${SPACE_COLORS[5]}║${NC}\n"
            printf "${SPACE_COLORS[5]}╚══════════════════════════════════════════════════════════╝${NC}\n"
            ;;
        "ascii"|"ascii_art_animated")
            printf "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}\n"
            printf "${CYAN}║${NC} ${BOLD}ARTISTIC ACHIEVEMENT: ${message}${NC} ${CYAN}║${NC}\n"
            printf "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
            ;;
        *)
            printf "${MINIMAL_COLORS[4]}✓ ${message}${NC}\n"
            ;;
    esac

    # Clean up state
    unset PROGRESS_STATE[$progress_id]
    unset PROGRESS_TIMERS[$progress_id]

    # Terminal bell if supported
    if [ "$PROGRESS_UNICODE_SUPPORT" = true ]; then
        printf "\a"
    fi
}

# Simple progress function for better terminal compatibility
show_simple_progress() {
    local current="$1"
    local total="$2"
    local message="$3"

    # Input validation
    if ! [[ "$current" =~ ^[0-9]+$ ]] || ! [[ "$total" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    if [ "$total" -eq 0 ]; then total=1; fi

    local percentage=$((current * 100 / total))

    # Simple, clean progress output
    printf "\r${GREEN}[INFO]${NC} %s: %d%% (%d/%d)" "$message" "$percentage" "$current" "$total"
}

# Enhanced progress bar for operations (Simplified for reliability)
show_operation_progress() {
    local operation="$1"
    local current="$2"
    local total="$3"
    local style="${4:-minimal}"

    # Use simple progress for better terminal compatibility
    show_simple_progress "$current" "$total" "Operation: $operation"
}

# Clean, simple progress bar (replacement for complex system)
show_clean_progress() {
    local current="$1"
    local total="$2"
    local message="$3"

    # Input validation
    if ! [[ "$current" =~ ^[0-9]+$ ]] || ! [[ "$total" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    if [ "$total" -eq 0 ]; then total=1; fi

    local percentage=$((current * 100 / total))

    # Simple, clean progress output - no complex formatting
    printf "\r${GREEN}[PROGRESS]${NC} %s: %d%% (%d/%d)" "$message" "$percentage" "$current" "$total"
}

# =============================================================================
# SYSTEM DETECTION & CLASSIFICATION
# =============================================================================

# Comprehensive system detection
detect_system() {
    log "INFO" "Detecting system specifications..."

    # Detect OS
    case "$(uname -s)" in
        Linux*)     OS="Linux" ;;
        Darwin*)    OS="macOS" ;;
        CYGWIN*|MINGW*|MSYS*) OS="Windows" ;;
        *)          OS="Unknown" ;;
    esac

    # Detect architecture
    ARCH=$(uname -m)

    # Detect CPU cores
    CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "1")

    # Detect total memory (MB)
    if [[ "$OS" == "Linux" ]]; then
        TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    elif [[ "$OS" == "macOS" ]]; then
        TOTAL_MEM=$(echo "$(sysctl -n hw.memsize) / 1024 / 1024" | bc 2>/dev/null || echo "4096")
    else
        TOTAL_MEM="2048"
    fi

    # Detect available disk space (MB)
    AVAILABLE_DISK=$(df "$PROJECT_ROOT" | tail -1 | awk '{print int($4/1024)}' 2>/dev/null || echo "10240")

    log "INFO" "System detected: $OS $ARCH, $CPU_CORES cores, ${TOTAL_MEM}MB RAM, ${AVAILABLE_DISK}MB disk"
}

# Monitor current resource usage
monitor_resources() {
    log "DEBUG" "Monitoring current resource usage..."

    # Get current memory usage
    if [[ "$OS" == "Linux" ]]; then
        USED_MEM=$(free -m | awk 'NR==2{printf "%.0f", $3}')
        MEM_PERCENTAGE="$((USED_MEM * 100 / TOTAL_MEM))"
    elif [[ "$OS" == "macOS" ]]; then
        USED_MEM=$(vm_stat | awk '/Pages active/ {print $3}' | sed 's/\..*//' | awk '{print int($1 * 4096 / 1024 / 1024)}' 2>/dev/null || echo "0")
        MEM_PERCENTAGE="$((USED_MEM * 100 / TOTAL_MEM))"
    else
        MEM_PERCENTAGE="50"
    fi

    # Get current CPU usage (simplified)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' 2>/dev/null || echo "0")

    log "DEBUG" "Resource usage: CPU ${CPU_USAGE}% | Memory ${MEM_PERCENTAGE}% (${USED_MEM}MB/${TOTAL_MEM}MB)"
}

# Classify device capability with enhanced logic
classify_device() {
    local mem="$1"
    local cores="$2"
    local disk="$3"

    if [[ $mem -ge 16384 && $cores -ge 16 && $disk -ge 102400 ]]; then
        DEVICE_CLASS="ultra-high"
        log "INFO" "Ultra-high-end device detected - Maximum configuration enabled"
    elif [[ $mem -ge 8192 && $cores -ge 8 && $disk -ge 51200 ]]; then
        DEVICE_CLASS="high-end"
        log "INFO" "High-end device detected - Full configuration enabled"
    elif [[ $mem -ge 4096 && $cores -ge 4 && $disk -ge 25600 ]]; then
        DEVICE_CLASS="mid-range"
        log "INFO" "Mid-range device detected - Standard configuration"
    else
        DEVICE_CLASS="low-end"
        log "INFO" "Low-end device detected - Minimal configuration"
    fi
}

# Get adaptive configuration based on device class and current usage
get_adaptive_config() {
    local device_class="$1"
    local mem_percent="$2"

    case "$device_class" in
        "ultra-high")
            SPRING_PROFILES="dev,async,monitoring"
            JVM_HEAP_SIZE="4g"
            DB_POOL_SIZE="30"
            NODE_ENV="development"
            PARALLEL_PROCESSES="$CPU_CORES"
            ENABLE_MONITORING=true
            ;;
        "high-end")
            SPRING_PROFILES="dev,async"
            JVM_HEAP_SIZE="2g"
            DB_POOL_SIZE="20"
            NODE_ENV="development"
            PARALLEL_PROCESSES="$CPU_CORES"
            ENABLE_MONITORING=true
            ;;
        "mid-range")
            SPRING_PROFILES="dev"
            JVM_HEAP_SIZE="1g"
            DB_POOL_SIZE="10"
            NODE_ENV="development"
            PARALLEL_PROCESSES="$((CPU_CORES / 2))"
            ENABLE_MONITORING=false
            ;;
        "low-end")
            SPRING_PROFILES="dev,minimal"
            JVM_HEAP_SIZE="512m"
            DB_POOL_SIZE="5"
            NODE_ENV="production"
            PARALLEL_PROCESSES="1"
            ENABLE_MONITORING=false
            ;;
    esac

    # Adjust for current memory pressure
    if [[ "$mem_percent" -gt 80 ]]; then
        JVM_HEAP_SIZE="512m"
        DB_POOL_SIZE="5"
        log "WARN" "High memory usage detected - reducing resource allocation"
    elif [[ "$mem_percent" -gt 60 ]]; then
        local jvm_numeric=$(echo "$JVM_HEAP_SIZE" | sed 's/[^0-9]*//g')
        local jvm_unit=$(echo "$JVM_HEAP_SIZE" | sed 's/[0-9]*//g')
        if [[ -n "$jvm_numeric" && "$jvm_numeric" -gt 0 ]]; then
            JVM_HEAP_SIZE="$((jvm_numeric / 2))${jvm_unit}"
        else
            JVM_HEAP_SIZE="512m"
        fi
        DB_POOL_SIZE="$((DB_POOL_SIZE / 2))"
        log "INFO" "Moderate memory usage - optimizing resource allocation"
    fi

    # Platform-specific optimizations
    if [[ "$OS" == "macOS" && "$ARCH" == "arm64" ]]; then
        JVM_OPTS="-XX:+UseG1GC -XX:+UseStringDeduplication -XX:+OptimizeStringConcat"
        NODE_OPTS="--max-old-space-size=1024"
    elif [[ "$OS" == "Linux" ]]; then
        JVM_OPTS="-XX:+UseG1GC -XX:+UseContainerSupport -XX:+DisableExplicitGC"
        NODE_OPTS="--max-old-space-size=768"
    else
        JVM_OPTS="-XX:+UseG1GC"
        NODE_OPTS="--max-old-space-size=512"
    fi
}

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

# Load configuration from file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        log "DEBUG" "Loading configuration from $CONFIG_FILE"
        source "$CONFIG_FILE" 2>/dev/null || true
    fi
}

# Save configuration to file
save_config() {
    log "INFO" "Saving configuration to $CONFIG_FILE"
    mkdir -p "$(dirname "$CONFIG_FILE")"

    cat > "$CONFIG_FILE" << EOF
# Java Dev Toolkit Configuration
# Generated on $(date)

# System Configuration
OS="$OS"
ARCH="$ARCH"
CPU_CORES="$CPU_CORES"
TOTAL_MEM="$TOTAL_MEM"
DEVICE_CLASS="$DEVICE_CLASS"

# Adaptive Configuration
SPRING_PROFILES="$SPRING_PROFILES"
JVM_HEAP_SIZE="$JVM_HEAP_SIZE"
DB_POOL_SIZE="$DB_POOL_SIZE"
NODE_ENV="$NODE_ENV"
PARALLEL_PROCESSES="$PARALLEL_PROCESSES"
JVM_OPTS="$JVM_OPTS"
NODE_OPTS="$NODE_OPTS"
ENABLE_MONITORING="$ENABLE_MONITORING"

# User Preferences
LOG_LEVEL="${LOG_LEVEL:-INFO}"
AUTO_START="${AUTO_START:-false}"
BACKUP_ENABLED="${BACKUP_ENABLED:-true}"
EOF
}

# Interactive configuration wizard
configure_interactive() {
    log "HEADER" "Interactive Configuration Wizard"

    echo ""
    log "INFO" "Current configuration:"
    echo "  Device Class: $DEVICE_CLASS"
    echo "  JVM Heap Size: $JVM_HEAP_SIZE"
    echo "  Database Pool Size: $DB_POOL_SIZE"
    echo "  Spring Profiles: $SPRING_PROFILES"
    echo ""

    if confirm "Would you like to customize these settings?"; then
        JVM_HEAP_SIZE=$(prompt "JVM Heap Size" "$JVM_HEAP_SIZE" "^[0-9]+[mg]$")
        DB_POOL_SIZE=$(prompt "Database Connection Pool Size" "$DB_POOL_SIZE" "^[0-9]+$")
        SPRING_PROFILES=$(prompt "Spring Profiles" "$SPRING_PROFILES")

        if confirm "Enable monitoring features?"; then
            ENABLE_MONITORING=true
        else
            ENABLE_MONITORING=false
        fi

        save_config
        log "SUCCESS" "Configuration updated successfully!"
    fi
}

# Interactive prompt with validation
prompt() {
    local message="$1"
    local default="${2:-}"
    local validation="${3:-}"

    while true; do
        echo -n -e "${CYAN}$message${NC}"
        if [ -n "$default" ]; then
            echo -n " [$default]"
        fi
        echo -n ": "

        read -r response
        response="${response:-$default}"

        if [ -n "$validation" ] && ! [[ "$response" =~ $validation ]]; then
            log "ERROR" "Invalid input. Please try again."
            continue
        fi

        echo "$response"
        return 0
    done
}

# Confirm action with yes/no prompt
confirm() {
    local message="$1"
    local default="${2:-n}"

    while true; do
        echo -n -e "${YELLOW}$message${NC} [y/N]: "
        read -r response
        response="${response:-$default}"

        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]|"") return 1 ;;
            *) log "WARN" "Please answer yes or no." ;;
        esac
    done
}

# =============================================================================
# DEPENDENCY MANAGEMENT
# =============================================================================

# Check system requirements with detailed reporting
check_requirements() {
    log "INFO" "Checking system requirements..."

    local missing_deps=()
    local warning_deps=()

    # Check Java
    if ! command_exists java; then
        missing_deps+=("java")
    else
        java_version=$(java -version 2>&1 | head -n1 | cut -d'"' -f2 | sed 's/^1\.//' | cut -d'.' -f1)
        if [ "$java_version" -lt 17 ]; then
            warning_deps+=("Java $java_version (Java 17+ recommended)")
        else
            log "INFO" "Java version $java_version detected."
        fi
    fi

    # Check Node.js
    if ! command_exists node; then
        missing_deps+=("nodejs")
    else
        node_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$node_version" -lt 18 ]; then
            warning_deps+=("Node.js $node_version (Node.js 18+ recommended)")
        else
            log "INFO" "Node.js version $node_version detected."
        fi
    fi

    # Check Docker (optional but recommended)
    if ! command_exists docker; then
        warning_deps+=("docker (recommended for containerized services)")
    fi

    # Check Git
    if ! command_exists git; then
        missing_deps+=("git")
    fi

    # Check curl
    if ! command_exists curl; then
        missing_deps+=("curl")
    fi

    # Report results
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        log "INFO" "Please install the missing dependencies and run this script again."
        return 1
    fi

    if [ ${#warning_deps[@]} -ne 0 ]; then
        log "WARN" "The following dependencies may need updates: ${warning_deps[*]}"
    fi

    log "SUCCESS" "All system requirements met!"
    return 0
}

# =============================================================================
# SERVICE MANAGEMENT
# =============================================================================

# Enhanced animated waiting function with MOVING black and white retro matrix style
show_animated_waiting() {
    local message="$1"
    local attempt="$2"
    local max_attempts="$3"

    # Black and white matrix animation characters
    local matrix_chars=("█" "▓" "▒" "░" "▒" "▓" "█")
    local shades=("\033[1;37m" "\033[0;37m" "\033[1;30m" "\033[0;90m")  # White, Light gray, Dark gray, Black

    # Create MOVING animated black and white matrix pattern
    local pattern=""
    local pattern_length=10

    for i in {1..10}; do
        # Create flowing wave effect by shifting based on attempt number
        local shift=$((attempt + i))
        local char_index=$((shift % ${#matrix_chars[@]}))
        local shade_index=$((shift % ${#shades[@]}))
        pattern="${pattern}${shades[$shade_index]}${matrix_chars[$char_index]}${NC}"
    done

    # Show MOVING animated waiting with attempt counter in black and white
    printf "\r[WAIT] ${pattern} Attempt ${attempt}/${max_attempts}"
}

# Wait for service to be ready with cool retro matrix animation
wait_for_service() {
    local host="$1"
    local port="$2"
    local service_name="$3"
    local max_attempts="${4:-30}"
    local attempt=1

    log "INFO" "Waiting for $service_name to be ready at $host:$port..."

    while [ "$attempt" -le "$max_attempts" ]; do
        if nc -z "$host" "$port" >/dev/null 2>&1; then
            # Show final success animation
            show_animated_waiting "🎮 █▓▒░█▓▒░█▓▒░█▓▒░█▓▒░█▓▒░█▓▒░█▓▒░ CONNECTED!" "$attempt" "$max_attempts"
            printf "\n"
            log "SUCCESS" "$service_name is ready!"
            return 0
        fi

        # Show cool animated waiting indicator
        show_animated_waiting "🎮 █▓▒░█▓▒░█▓▒░█▓▒░█▓▒░█▓▒░█▓▒░█▓▒░ WAITING..." "$attempt" "$max_attempts"
        sleep 2
        attempt=$((attempt + 1))
    done

    # Show timeout animation
    printf "\r${RETRO_COLORS[5]}⏰ TIMEOUT after ${max_attempts} attempts${NC}                    \n"
    log "WARN" "$service_name not ready after $max_attempts attempts"
    return 1
}

# Start Spring Boot backend with enhanced configuration
start_backend() {
    log "HEADER" "Starting Spring Boot Backend"

    if [ ! -d "backend/spring-boot-template" ]; then
        log "ERROR" "Backend directory not found. Please run setup first."
        return 1
    fi

    cd backend/spring-boot-template

    # Check if port is available
    if port_in_use "$BACKEND_PORT"; then
        log "WARN" "Port $BACKEND_PORT is already in use. Please free up the port or stop existing services."
        cd "$PROJECT_ROOT"
        return 1
    fi

    log "INFO" "Starting Spring Boot application with adaptive configuration..."
    log "INFO" "Device class: $DEVICE_CLASS | JVM heap: $JVM_HEAP_SIZE | DB connections: $DB_POOL_SIZE"

    # Check if gradlew exists, otherwise use system gradle
    if [ -f "./gradlew" ]; then
        GRADLE_CMD="./gradlew"
    else
        GRADLE_CMD="gradle"
    fi

    # Set JVM options based on device class and platform
    JVM_OPTS="-Xmx$JVM_HEAP_SIZE $JVM_OPTS"

    # Start in background with enhanced JVM settings
    if [ "$GRADLE_CMD" = "./gradlew" ]; then
        nohup $GRADLE_CMD bootRun -Dspring-boot.run.jvmArguments="$JVM_OPTS" > ../backend.log 2>&1 &
    else
        nohup $GRADLE_CMD run -Dorg.gradle.jvmargs="$JVM_OPTS" > ../backend.log 2>&1 &
    fi
    BACKEND_PID=$!

    SERVICE_PIDS["backend"]="$BACKEND_PID"
    log "INFO" "Backend started with PID: $BACKEND_PID"

    # Wait for backend to be ready
    wait_for_service "localhost" "$BACKEND_PORT" "Spring Boot Backend"

    cd "$PROJECT_ROOT"
}

# Start React frontend with enhanced configuration
start_frontend() {
    log "HEADER" "Starting React Frontend"

    if [ ! -d "frontend/react-vite-template" ]; then
        log "ERROR" "Frontend directory not found. Please run setup first."
        return 1
    fi

    cd frontend/react-vite-template

    # Check if Node.js is available
    if ! command_exists node; then
        log "ERROR" "Node.js is not installed. Please install Node.js to run the frontend."
        cd "$PROJECT_ROOT"
        return 1
    fi

    # Check if port is available
    if port_in_use "$FRONTEND_PORT"; then
        log "WARN" "Port $FRONTEND_PORT is already in use. Please free up the port or stop existing services."
        cd "$PROJECT_ROOT"
        return 1
    fi

    log "INFO" "Installing frontend dependencies..."
    if [[ "$PARALLEL_PROCESSES" -gt 1 ]]; then
        npm install --parallel
    else
        npm install
    fi

    log "INFO" "Starting React development server..."

    # Start in background with adaptive Node settings
    nohup node $NODE_OPTS node_modules/.bin/vite > ../frontend.log 2>&1 &
    FRONTEND_PID=$!

    SERVICE_PIDS["frontend"]="$FRONTEND_PID"
    log "INFO" "Frontend started with PID: $FRONTEND_PID"

    # Wait for frontend to be ready
    wait_for_service "localhost" "$FRONTEND_PORT" "React Frontend"

    cd "$PROJECT_ROOT"
}

# Start databases with Docker (enhanced)
start_databases() {
    log "HEADER" "Starting Database Services"

    if ! command_exists docker; then
        log "WARN" "Docker not found. Database services will be limited."
        return 0
    fi

    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        log "WARN" "Docker Compose not found. Database services will be limited."
        return 0
    fi

    log "INFO" "Starting PostgreSQL, MongoDB, and Redis..."

    # Check if containers are already running
    if docker ps | grep -q "fullstack-"; then
        log "INFO" "Database containers are already running!"
    else
        # Start database containers
        if command_exists docker-compose; then
            docker-compose up -d postgres mongodb redis
        else
            docker compose up -d postgres mongodb redis
        fi
        log "SUCCESS" "All database containers started successfully!"
    fi

    # Wait for databases to be ready
    wait_for_service "localhost" "$POSTGRES_PORT" "PostgreSQL"
    wait_for_service "localhost" "$MONGO_PORT" "MongoDB"
    wait_for_service "localhost" "$REDIS_PORT" "Redis"
}

# Stop all services gracefully
stop_all_services() {
    log "HEADER" "Stopping all services..."

    # Stop backend
    if [ -n "${SERVICE_PIDS["backend"]:-}" ] && ps -p "${SERVICE_PIDS["backend"]}" >/dev/null 2>&1; then
        log "INFO" "Stopping backend (PID: ${SERVICE_PIDS["backend"]})..."
        kill -TERM "${SERVICE_PIDS["backend"]}" 2>/dev/null || true
        sleep 3
        kill -KILL "${SERVICE_PIDS["backend"]}" 2>/dev/null || true
    fi

    # Stop frontend
    if [ -n "${SERVICE_PIDS["frontend"]:-}" ] && ps -p "${SERVICE_PIDS["frontend"]}" >/dev/null 2>&1; then
        log "INFO" "Stopping frontend (PID: ${SERVICE_PIDS["frontend"]})..."
        kill -TERM "${SERVICE_PIDS["frontend"]}" 2>/dev/null || true
        sleep 3
        kill -KILL "${SERVICE_PIDS["frontend"]}" 2>/dev/null || true
    fi

    # Stop Docker containers
    if command_exists docker-compose; then
        docker-compose down >/dev/null 2>&1 || true
    elif docker compose version >/dev/null 2>&1; then
        docker compose down >/dev/null 2>&1 || true
    fi

    # Stop monitoring
    if [ -n "$MONITOR_PID" ] && ps -p "$MONITOR_PID" >/dev/null 2>&1; then
        log "INFO" "Stopping monitoring service (PID: $MONITOR_PID)..."
        kill -TERM "$MONITOR_PID" 2>/dev/null || true
    fi

    log "SUCCESS" "All services stopped!"
}

# =============================================================================
# SETUP MODULE
# =============================================================================

# Create directory structure with enhanced organization
create_directory_structure() {
    log "INFO" "Creating enhanced project directory structure..."

    local total_steps=13
    local current_step=0

    # Update overall progress and show clean log messages
    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating backend structure" "minimal" "main_setup"
    log "INFO" "Creating backend structure..."
    mkdir -p "$PROJECT_ROOT/backend/spring-boot-template/src/main/java/org/nakhan"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating backend resources" "minimal" "main_setup"
    log "INFO" "Creating backend resources..."
    mkdir -p "$PROJECT_ROOT/backend/spring-boot-template/src/main/resources"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating test directories" "minimal" "main_setup"
    log "INFO" "Creating test directories..."
    mkdir -p "$PROJECT_ROOT/backend/spring-boot-template/src/test/java/org/nakhan"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating frontend structure" "minimal" "main_setup"
    log "INFO" "Creating frontend structure..."
    mkdir -p "$PROJECT_ROOT/frontend/react-vite-template"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating database directories" "minimal" "main_setup"
    log "INFO" "Creating database directories..."
    mkdir -p "$PROJECT_ROOT/database/{postgres,mongo,redis,migrations,seeds}"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating DevOps structure" "minimal" "main_setup"
    log "INFO" "Creating DevOps structure..."
    mkdir -p "$PROJECT_ROOT/devops/{docker,kubernetes,jenkins,terraform}"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating testing framework" "minimal" "main_setup"
    log "INFO" "Creating testing framework..."
    mkdir -p "$PROJECT_ROOT/testing/{junit-examples,mockito-examples,testcontainers,performance}"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating documentation" "minimal" "main_setup"
    log "INFO" "Creating documentation..."
    mkdir -p "$PROJECT_ROOT/docs/{api,deployment,development}"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating utility scripts" "minimal" "main_setup"
    log "INFO" "Creating utility scripts..."
    mkdir -p "$PROJECT_ROOT/scripts/{deployment,migration,backup}"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating configurations" "minimal" "main_setup"
    log "INFO" "Creating configurations..."
    mkdir -p "$PROJECT_ROOT/config/{development,staging,production}"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating log directories" "minimal" "main_setup"
    log "INFO" "Creating log directories..."
    mkdir -p "$PROJECT_ROOT/logs"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating backup storage" "minimal" "main_setup"
    log "INFO" "Creating backup storage..."
    mkdir -p "$PROJECT_ROOT/backups"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Finalizing structure" "minimal" "main_setup"
    log "INFO" "Finalizing structure..."

    log "SUCCESS" "Enhanced directory structure created successfully!"
}

# Create environment files with dynamic configuration
create_env_files() {
    log "INFO" "Creating dynamic environment configuration files..."

    # Backend environment with enhanced configuration
    cat > "$PROJECT_ROOT/backend/spring-boot-template/.env" << EOF
# Spring Boot Application Configuration (Dynamic - $DEVICE_CLASS device)
SPRING_PROFILES_ACTIVE=$SPRING_PROFILES
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:$POSTGRES_PORT/java_dev_app
SPRING_DATASOURCE_USERNAME=java_dev_user
SPRING_DATASOURCE_PASSWORD=java_dev_password
SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE=$DB_POOL_SIZE
SPRING_JPA_HIBERNATE_DDL_AUTO=update

# Server Configuration
SERVER_PORT=$BACKEND_PORT

# JWT Configuration
JWT_SECRET=mySecretKey12345678901234567890
JWT_EXPIRATION=86400000

# JVM Configuration (Dynamic)
JVM_OPTS="$JVM_OPTS"
JVM_HEAP_SIZE=$JVM_HEAP_SIZE

# Logging (adjusted for device class)
LOGGING_LEVEL_COM_EXAMPLE=DEBUG
LOGGING_FILE_PATH=../logs/backend.log

# Monitoring
MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE=health,info,metrics,prometheus
MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS=when-authorized
EOF

    # Frontend environment with enhanced configuration
    cat > "$PROJECT_ROOT/frontend/react-vite-template/.env" << EOF
# React Vite Application Configuration (Dynamic - $DEVICE_CLASS device)
VITE_API_BASE_URL=http://localhost:$BACKEND_PORT/api
VITE_APP_TITLE=Java Developer Toolkit
VITE_DEVICE_CLASS=$DEVICE_CLASS

# Development Configuration (Dynamic)
VITE_DEV_TOOLS=true
VITE_NODE_ENV=$NODE_ENV
VITE_PARALLEL_PROCESSES=$PARALLEL_PROCESSES

# Feature Flags
VITE_ENABLE_ANALYTICS=false
VITE_ENABLE_PWA=false
EOF

    log "SUCCESS" "Dynamic environment files created with $DEVICE_CLASS optimizations!"
}

# Create enhanced Docker Compose file
create_docker_compose() {
    log "INFO" "Creating enhanced Docker Compose configuration..."

    cat > "$PROJECT_ROOT/docker-compose.yml" << EOF
version: '3.8'
services:
  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: java-dev-postgres
    environment:
      POSTGRES_DB: java_dev_app
      POSTGRES_USER: java_dev_user
      POSTGRES_PASSWORD: java_dev_password
    ports:
      - "$POSTGRES_PORT:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/postgres/init:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U java_dev_user -d java_dev_app"]
      interval: 10s
      timeout: 5s
      retries: 5

  # MongoDB Database
  mongodb:
    image: mongo:7-jammy
    container_name: java-dev-mongo
    environment:
      MONGO_INITDB_DATABASE: java_dev_app
    ports:
      - "$MONGO_PORT:27017"
    volumes:
      - mongo_data:/data/db
      - ./database/mongo/init:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: java-dev-redis
    ports:
      - "$REDIS_PORT:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis Commander (for development)
  redis-commander:
    image: rediscommander/redis-commander:latest
    container_name: java-dev-redis-commander
    environment:
      REDIS_HOSTS: local:redis:6379
    ports:
      - "8081:8081"
    depends_on:
      - redis

volumes:
  postgres_data:
  mongo_data:
  redis_data:
EOF

    log "SUCCESS" "Enhanced Docker Compose configuration created!"
}

# Create Spring Boot template with enhanced features
create_spring_boot_template() {
    log "INFO" "Creating enhanced Spring Boot template..."

    local total_steps=8
    local current_step=0

    # Update overall progress and show clean log messages
    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating Gradle build configuration" "minimal" "main_setup"
    log "INFO" "Creating Gradle build configuration..."
    cat > "$PROJECT_ROOT/backend/spring-boot-template/build.gradle.kts" << 'EOF'
plugins {
    java
    id("org.springframework.boot") version "3.1.5"
    id("io.spring.dependency-management") version "1.1.4"
}

group = "org.nakhan"
version = "0.0.1-SNAPSHOT"

java {
    sourceCompatibility = JavaVersion.VERSION_17
}

configurations {
    compileOnly {
        extendsFrom(annotationProcessor.get())
    }
}

repositories {
    mavenCentral()
}

dependencies {
    // Core Spring Boot
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-data-rest")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-actuator")

    // Database
    runtimeOnly("org.postgresql:postgresql")
    runtimeOnly("com.h2database:h2")

    // JWT
    implementation("io.jsonwebtoken:jjwt-api:0.11.5")
    runtimeOnly("io.jsonwebtoken:jjwt-impl:0.11.5")
    runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.11.5")

    // Additional useful libraries
    implementation("org.springframework.boot:spring-boot-starter-cache")
    implementation("org.springframework.boot:spring-boot-starter-data-redis")
    implementation("org.springframework.boot:spring-boot-starter-mail")
    implementation("org.springframework.boot:spring-boot-starter-thymeleaf")

    // Development
    developmentOnly("org.springframework.boot:spring-boot-devtools")

    // Documentation
    implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.2.0")

    // Testing
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.security:spring-security-test")
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:postgresql")
}

tasks.withType<Test> {
    useJUnitPlatform()
}
EOF

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Configuring Spring Boot application properties" "minimal" "main_setup"
    log "INFO" "Configuring Spring Boot application properties..."
    # Enhanced application.yml
    cat > "$PROJECT_ROOT/backend/spring-boot-template/src/main/resources/application.yml" << EOF
spring:
  datasource:
    url: \${SPRING_DATASOURCE_URL:jdbc:postgresql://localhost:$POSTGRES_PORT/java_dev_app}
    username: \${SPRING_DATASOURCE_USERNAME:java_dev_user}
    password: \${SPRING_DATASOURCE_PASSWORD:java_dev_password}
    hikari:
      maximum-pool-size: \${SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE:$DB_POOL_SIZE}
  jpa:
    hibernate:
      ddl-auto: \${SPRING_JPA_HIBERNATE_DDL_AUTO:update}
    show-sql: true
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true

  # Redis Configuration
  data:
    redis:
      host: localhost
      port: $REDIS_PORT

  # Cache Configuration
  cache:
    type: redis

server:
  port: \${SERVER_PORT:$BACKEND_PORT}

# JWT Configuration
jwt:
  secret: \${JWT_SECRET:mySecretKey12345678901234567890}
  expiration: \${JWT_EXPIRATION:86400000}

# Logging Configuration
logging:
  level:
    org.nakhan: DEBUG
    org.springframework.web: DEBUG
  file:
    name: logs/backend.log

# Management endpoints for monitoring
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when-authorized
EOF

    # Create additional Spring Boot files with progress tracking
    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating Spring Boot main application class" "minimal" "main_setup"
    log "INFO" "Creating Spring Boot main application class..."
    mkdir -p "$PROJECT_ROOT/backend/spring-boot-template/src/main/java/org/nakhan"
    cat > "$PROJECT_ROOT/backend/spring-boot-template/src/main/java/org/nakhan/Application.java" << 'EOF'
package org.nakhan;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
EOF

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating REST controller template" "minimal" "main_setup"
    log "INFO" "Creating REST controller template..."
    cat > "$PROJECT_ROOT/backend/spring-boot-template/src/main/java/org/nakhan/HelloController.java" << 'EOF'
package org.nakhan;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {

    @GetMapping("/")
    public String hello() {
        return "Hello from Java Developer Toolkit!";
    }

    @GetMapping("/api/health")
    public String health() {
        return "Application is running!";
    }
}
EOF

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating test classes" "minimal" "main_setup"
    log "INFO" "Creating test classes..."
    mkdir -p "$PROJECT_ROOT/backend/spring-boot-template/src/test/java/org/nakhan"
    cat > "$PROJECT_ROOT/backend/spring-boot-template/src/test/java/org/nakhan/ApplicationTest.java" << 'EOF'
package org.nakhan;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class ApplicationTest {

    @Test
    void contextLoads() {
        // Test that Spring context loads successfully
    }
}
EOF

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating environment configuration" "minimal" "main_setup"
    log "INFO" "Creating environment configuration..."
    cat > "$PROJECT_ROOT/backend/spring-boot-template/.env" << EOF
# Spring Boot Application Configuration (Dynamic - $DEVICE_CLASS device)
SPRING_PROFILES_ACTIVE=$SPRING_PROFILES
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:$POSTGRES_PORT/java_dev_app
SPRING_DATASOURCE_USERNAME=java_dev_user
SPRING_DATASOURCE_PASSWORD=java_dev_password
SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE=$DB_POOL_SIZE
SPRING_JPA_HIBERNATE_DDL_AUTO=update

# Server Configuration
SERVER_PORT=$BACKEND_PORT

# JWT Configuration
JWT_SECRET=mySecretKey12345678901234567890
JWT_EXPIRATION=86400000

# JVM Configuration (Dynamic)
JVM_OPTS="$JVM_OPTS"
JVM_HEAP_SIZE=$JVM_HEAP_SIZE

# Logging (adjusted for device class)
LOGGING_LEVEL_COM_EXAMPLE=DEBUG
LOGGING_FILE_PATH=../logs/backend.log

# Monitoring
MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE=health,info,metrics,prometheus
MANAGEMENT_ENDPOINT_HEALTH_SHOW_DETAILS=when-authorized
EOF

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating Gradle wrapper" "minimal" "main_setup"
    log "INFO" "Creating Gradle wrapper..."
    cat > "$PROJECT_ROOT/backend/spring-boot-template/gradlew" << 'EOF'
#!/bin/bash
exec ./gradlew "$@"
EOF
    chmod +x "$PROJECT_ROOT/backend/spring-boot-template/gradlew"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Finalizing Spring Boot template" "minimal" "main_setup"
    log "INFO" "Finalizing Spring Boot template..."

    log "SUCCESS" "Enhanced Spring Boot template created!"
}

# Create React Vite template with enhanced features
create_react_vite_template() {
    log "INFO" "Creating enhanced React Vite template..."

    local total_steps=10
    local current_step=0

    # Update overall progress and show clean log messages
    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating React package configuration" "minimal" "main_setup"
    log "INFO" "Creating React package configuration..."
    cat > "$PROJECT_ROOT/frontend/react-vite-template/package.json" << 'EOF'
{
  "name": "java-dev-react-app",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "lint": "eslint . --ext ts,tsx --report-unused-disable-directives --max-warnings 0",
    "preview": "vite preview",
    "test": "vitest",
    "test:ui": "vitest --ui",
    "test:coverage": "vitest --coverage",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "axios": "^1.6.0",
    "react-router-dom": "^6.17.0",
    "react-query": "^3.39.3",
    "tailwindcss": "^3.3.5",
    "react-hook-form": "^7.47.0",
    "zustand": "^4.4.6",
    "react-hot-toast": "^2.4.1"
  },
  "devDependencies": {
    "@types/react": "^18.2.37",
    "@types/react-dom": "^18.2.15",
    "@typescript-eslint/eslint-plugin": "^6.10.0",
    "@typescript-eslint/parser": "^6.10.0",
    "@vitejs/plugin-react": "^4.1.1",
    "@vitest/ui": "^0.34.6",
    "@vitest/coverage-v8": "^0.34.6",
    "autoprefixer": "^10.4.16",
    "eslint": "^8.53.0",
    "eslint-plugin-react-hooks": "^4.6.0",
    "eslint-plugin-react-refresh": "^0.4.4",
    "jsdom": "^22.1.0",
    "postcss": "^8.4.31",
    "typescript": "^5.2.2",
    "vite": "^4.5.0",
    "vitest": "^0.34.6"
  }
}
EOF

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Configuring Vite build system" "minimal" "main_setup"
    log "INFO" "Configuring Vite build system..."
    # Enhanced vite.config.ts
    cat > "$PROJECT_ROOT/frontend/react-vite-template/vite.config.ts" << EOF
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: $FRONTEND_PORT,
    proxy: {
      '/api': {
        target: 'http://localhost:$BACKEND_PORT',
        changeOrigin: true,
      },
    },
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
  },
})
EOF

    # Create additional React files with progress tracking
    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating React app structure" "minimal" "main_setup"
    log "INFO" "Creating React app structure..."
    mkdir -p "$PROJECT_ROOT/frontend/react-vite-template/src/components"
    mkdir -p "$PROJECT_ROOT/frontend/react-vite-template/src/hooks"
    mkdir -p "$PROJECT_ROOT/frontend/react-vite-template/src/services"
    mkdir -p "$PROJECT_ROOT/frontend/react-vite-template/src/types"
    mkdir -p "$PROJECT_ROOT/frontend/react-vite-template/src/utils"
    mkdir -p "$PROJECT_ROOT/frontend/react-vite-template/src/test"
    mkdir -p "$PROJECT_ROOT/frontend/react-vite-template/public"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating React main application" "minimal" "main_setup"
    log "INFO" "Creating React main application..."
    cat > "$PROJECT_ROOT/frontend/react-vite-template/src/main.tsx" << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating React App component" "minimal" "main_setup"
    log "INFO" "Creating React App component..."
    cat > "$PROJECT_ROOT/frontend/react-vite-template/src/App.tsx" << 'EOF'
import { useState } from 'react'
import './App.css'

function App() {
  const [count, setCount] = useState(0)

  return (
    <div className="App">
      <header className="App-header">
        <h1>Java Developer Toolkit</h1>
        <p>
          <button onClick={() => setCount((count) => count + 1)}>
            count is {count}
          </button>
        </p>
        <p>
          Edit <code>src/App.tsx</code> and save to test HMR.
        </p>
      </header>
    </div>
  )
}

export default App
EOF

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating React CSS styles" "minimal" "main_setup"
    log "INFO" "Creating React CSS styles..."
    cat > "$PROJECT_ROOT/frontend/react-vite-template/src/App.css" << 'EOF'
#root {
  max-width: 1280px;
  margin: 0 auto;
  padding: 2rem;
  text-align: center;
}

.App-header {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  font-size: calc(10px + 2vmin);
  color: white;
}

.App-header {
  background-color: #282c34;
}
EOF

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating index CSS" "minimal" "main_setup"
    log "INFO" "Creating index CSS..."
    cat > "$PROJECT_ROOT/frontend/react-vite-template/src/index.css" << 'EOF'
:root {
  font-family: Inter, system-ui, Avenir, Helvetica, Arial, sans-serif;
  line-height: 1.5;
  font-weight: 400;

  color-scheme: light dark;
  color: rgba(255, 255, 255, 0.87);
  background-color: #242424;

  font-synthesis: none;
  text-rendering: optimizeLegibility;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  -webkit-text-size-adjust: 100%;
}

body {
  margin: 0;
  display: flex;
  place-items: center;
  min-width: 320px;
  min-height: 100vh;
}

button {
  border-radius: 8px;
  border: 1px solid transparent;
  padding: 0.6em 1.2em;
  font-size: 1em;
  font-weight: 500;
  font-family: inherit;
  background-color: #1a1a1a;
  cursor: pointer;
  transition: border-color 0.25s;
}
button:hover {
  border-color: #646cff;
}
button:focus,
button:focus-visible {
  outline: 4px auto -webkit-focus-ring-color;
}
EOF

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating TypeScript configuration" "minimal" "main_setup"
    log "INFO" "Creating TypeScript configuration..."
    cat > "$PROJECT_ROOT/frontend/react-vite-template/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,

    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",

    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
EOF

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating test configuration" "minimal" "main_setup"
    log "INFO" "Creating test configuration..."
    cat > "$PROJECT_ROOT/frontend/react-vite-template/src/test/setup.ts" << 'EOF'
import { expect, afterEach } from 'vitest'
import { cleanup } from '@testing-library/react'
import * as matchers from '@testing-library/jest-dom/matchers'

expect.extend(matchers)

afterEach(() => {
  cleanup()
})
EOF

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Finalizing React template" "minimal" "main_setup"
    log "INFO" "Finalizing React template..."

    log "SUCCESS" "Enhanced React Vite template created!"
}

# Create comprehensive documentation
create_documentation() {
    log "INFO" "Creating comprehensive documentation..."

    # Force replace existing README.md if requested via command line
    if [[ "${FORCE_REPLACE_README:-false}" == "true" ]]; then
        if [ -f "$PROJECT_ROOT/README.md" ]; then
            log "INFO" "Force replacing existing README.md as requested..."
            rm -f "$PROJECT_ROOT/README.md"
        fi
    else
        # Check if README.md already exists and is comprehensive
        if [ -f "$PROJECT_ROOT/README.md" ]; then
            # Check if the existing README contains comprehensive content (has badges, emojis, etc.)
            if grep -q "Java Developer Toolkit" "$PROJECT_ROOT/README.md" && \
               grep -q "img.shields.io" "$PROJECT_ROOT/README.md" && \
               grep -q "🚀" "$PROJECT_ROOT/README.md" && \
               [ "$(wc -l < "$PROJECT_ROOT/README.md")" -gt 50 ]; then
                log "INFO" "Comprehensive README.md already exists, preserving existing documentation"
                return 0
            fi
        fi

        # Replace existing README.md if it doesn't meet comprehensive criteria
        if [ -f "$PROJECT_ROOT/README.md" ]; then
            log "INFO" "Replacing existing README.md with comprehensive version..."
            rm -f "$PROJECT_ROOT/README.md"
        fi
    fi

    # Enhanced README.md (only create if no comprehensive README exists)
    cat > "$PROJECT_ROOT/README.md" << EOF
# 🧩 Java Developer Toolkit

🚀 A complete open-source toolkit for Java Developers — featuring Spring Boot, React, Docker, Kubernetes, and modern DevOps templates for rapid, production-grade app development.

## ✨ Features

- **Adaptive Configuration**: Automatically adjusts to your system capabilities
- **Comprehensive Monitoring**: Real-time health checks and performance monitoring
- **Enhanced Security**: Secure credential management and best practices
- **DevOps Ready**: Docker, Kubernetes, and CI/CD pipeline templates
- **Testing Integration**: Unit, integration, and performance testing
- **Database Management**: Migration support and backup strategies

## 🚀 Quick Start

### 1️⃣ Setup the project
\`\`\`bash
./java-dev-toolkit.sh setup
\`\`\`

### 2️⃣ Start the development environment
\`\`\`bash
./java-dev-toolkit.sh start
\`\`\`

### 3️⃣ Access your applications
- **Backend API** → http://localhost:$BACKEND_PORT
- **Frontend App** → http://localhost:$FRONTEND_PORT
- **API Documentation** → http://localhost:$BACKEND_PORT/swagger-ui.html
- **Redis Commander** → http://localhost:8081

## 📁 Project Structure

\`\`\`
java-developer-toolkit/
│
├── backend/spring-boot-template/    # Spring Boot REST API
├── frontend/react-vite-template/    # React + TypeScript + Vite
├── database/                        # Database configurations & migrations
├── devops/                         # DevOps and deployment configs
├── testing/                        # Testing examples and configs
├── docs/                           # Documentation
├── scripts/                        # Utility scripts
├── config/                         # Environment configurations
├── logs/                           # Application logs
└── backups/                        # Database backups
\`\`\`

## 🛠️ Development

### Backend Development
\`\`\`bash
cd backend/spring-boot-template
./gradlew bootRun
\`\`\`

### Frontend Development
\`\`\`bash
cd frontend/react-vite-template
npm install
npm run dev
\`\`\`

### Database Management
\`\`\`bash
# Start databases with Docker
./java-dev-toolkit.sh start databases

# Run migrations
./java-dev-toolkit.sh db migrate

# Backup databases
./java-dev-toolkit.sh backup create
\`\`\`

## 🧪 Testing

\`\`\`bash
# Backend tests
cd backend/spring-boot-template
./gradlew test

# Frontend tests
cd frontend/react-vite-template
npm test

# Run all tests
./java-dev-toolkit.sh test all
\`\`\`

## 📦 Building for Production

\`\`\`bash
# Build backend
cd backend/spring-boot-template
./gradlew build

# Build frontend
cd frontend/react-vite-template
npm run build

# Build Docker images
docker-compose build

# Deploy to production
./java-dev-toolkit.sh deploy
\`\`\`

## 🔧 Configuration

\`\`\`bash
# Interactive configuration
./java-dev-toolkit.sh config

# View current configuration
./java-dev-toolkit.sh status

# Monitor system resources
./java-dev-toolkit.sh monitor
\`\`\`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

For issues and questions:
- Check the logs in the \`logs/\` directory
- Run \`./java-dev-toolkit.sh status\` for current system status
- Use \`./java-dev-toolkit.sh monitor\` for real-time monitoring

---
*Built with ❤️ using the Java Developer Toolkit v$SCRIPT_VERSION*
EOF

    log "SUCCESS" "Comprehensive documentation created!"
}

# Main setup function (enhanced)
setup_project() {
    echo ""
    echo "==============================================="
    echo "    JAVA DEVELOPER TOOLKIT SETUP"
    echo "==============================================="
    echo ""

    # Initialize progress system for clean minimal style (only once)
    init_progress_system

    local total_steps=12
    local current_step=0

    # Update overall progress and show clean log messages
    echo ">>> SYSTEM ANALYSIS"
    echo "----------------------------------------"
    ((current_step++)) && show_progress "$current_step" "$total_steps" "Analyzing system specifications" "minimal" "main_setup"
    log "INFO" "Analyzing system specifications..."
    detect_system

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Classifying device capabilities" "minimal" "main_setup"
    log "INFO" "Classifying device capabilities..."
    classify_device "$TOTAL_MEM" "$CPU_CORES" "$AVAILABLE_DISK"

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Monitoring current resource usage" "minimal" "main_setup"
    log "INFO" "Monitoring current resource usage..."
    monitor_resources

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Applying adaptive configuration" "minimal" "main_setup"
    log "INFO" "Applying adaptive configuration..."
    get_adaptive_config "$DEVICE_CLASS" "$MEM_PERCENTAGE"

    # Requirements check with progress tracking
    ((current_step++)) && show_progress "$current_step" "$total_steps" "Checking system requirements" "minimal" "main_setup"
    if ! check_requirements; then
        log "ERROR" "Please install missing dependencies manually and run setup again."
        cleanup_progress_system
        exit 1
    fi

    echo ""
    echo ">>> PROJECT INITIALIZATION"
    echo "----------------------------------------"

    # Setup steps with clean progress tracking
    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating project structure" "minimal" "main_setup"
    log "INFO" "Creating enhanced project structure..."
    create_directory_structure

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Initializing Git repository" "minimal" "main_setup"
    log "INFO" "Initializing Git repository..."
    if [ ! -d .git ]; then
        git init
        log "SUCCESS" "Git repository initialized!"
    else
        log "INFO" "Git repository already exists, skipping initialization."
    fi

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating dynamic configuration" "minimal" "main_setup"
    log "INFO" "Creating dynamic configuration..."
    create_env_files

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Setting up Docker Compose" "minimal" "main_setup"
    log "INFO" "Setting up enhanced Docker Compose..."
    create_docker_compose

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Building Spring Boot template" "minimal" "main_setup"
    log "INFO" "Building enhanced Spring Boot template..."
    create_spring_boot_template

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Creating React Vite template" "minimal" "main_setup"
    log "INFO" "Creating enhanced React Vite template..."
    create_react_vite_template

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Generating documentation" "minimal" "main_setup"
    log "INFO" "Generating comprehensive documentation..."
    create_documentation

    ((current_step++)) && show_progress "$current_step" "$total_steps" "Saving configuration" "minimal" "main_setup"
    log "INFO" "Saving configuration..."
    # Save configuration
    save_config

    complete_progress "Setup completed successfully!" "minimal" "main_setup"

    # Cleanup progress system (only once)
    cleanup_progress_system

    echo ""
    echo "==============================================="
    echo "         SETUP COMPLETED SUCCESSFULLY"
    echo "==============================================="
    echo ""

    # Configuration summary
    echo ">>> SYSTEM CONFIGURATION SUMMARY"
    echo "----------------------------------------"
    echo "  Device Class: $DEVICE_CLASS"
    echo "  JVM Heap Size: $JVM_HEAP_SIZE"
    echo "  Database Pool Size: $DB_POOL_SIZE"
    echo "  Spring Profiles: $SPRING_PROFILES"
    echo "  Parallel Processes: $PARALLEL_PROCESSES"
    echo "  Monitoring: $ENABLE_MONITORING"
    echo ""

    echo ">>> NEXT STEPS"
    echo "----------------------------------------"
    echo "1. Run './java-dev-toolkit.sh start' to start the development environment"
    echo "2. Access your backend at http://localhost:$BACKEND_PORT"
    echo "3. Access your frontend at http://localhost:$FRONTEND_PORT"
    echo "4. Use './java-dev-toolkit.sh --help' to see all available commands"
    echo ""

    echo ">>> STATUS: Ready for development!"
}

# =============================================================================
# START MODULE
# =============================================================================

# Start all services with enhanced management
start_all() {
    echo ""
    echo "==============================================="
    echo "     JAVA DEVELOPER TOOLKIT LAUNCH"
    echo "==============================================="
    echo ""

    # Check if setup has been run
    if [ ! -f "README.md" ] || [ ! -d "backend/spring-boot-template" ]; then
        log "ERROR" "Project not set up. Please run './java-dev-toolkit.sh setup' first."
        exit 1
    fi

    # Load configuration
    load_config

    # System analysis
    echo ">>> SYSTEM ANALYSIS"
    echo "----------------------------------------"
    log "INFO" "Analyzing system resources..."
    detect_system

    log "INFO" "Classifying device capabilities..."
    classify_device "$TOTAL_MEM" "$CPU_CORES" "$AVAILABLE_DISK"

    log "INFO" "Monitoring current resource usage..."
    monitor_resources

    log "INFO" "Applying adaptive configuration..."
    get_adaptive_config "$DEVICE_CLASS" "$MEM_PERCENTAGE"

    # Configuration display
    echo ""
    echo ">>> ADAPTIVE CONFIGURATION"
    echo "----------------------------------------"
    echo "  Device Class: $DEVICE_CLASS"
    echo "  JVM max heap: $JVM_HEAP_SIZE"
    echo "  Database connections: $DB_POOL_SIZE"
    echo "  Parallel build: $PARALLEL_PROCESSES"
    echo "  Monitoring: $ENABLE_MONITORING"
    echo ""

    # Start services
    echo ">>> SERVICE INITIALIZATION"
    echo "----------------------------------------"
    log "INFO" "Starting database services..."
    start_databases

    log "INFO" "Starting Spring Boot backend..."
    start_backend

    log "INFO" "Starting React frontend..."
    start_frontend

    echo ""
    echo "==============================================="
    echo "       SERVICES STARTED SUCCESSFULLY"
    echo "==============================================="
    echo ""

    # Status display
    show_status

    echo ">>> QUICK ACTIONS"
    echo "----------------------------------------"
    echo "  • Press Ctrl+C to stop all services"
    echo "  • Check logs in logs/ directory"
    echo "  • Use './java-dev-toolkit.sh status' for service status"
    echo "  • Use './java-dev-toolkit.sh monitor' for real-time monitoring"
    echo ""

    echo ">>> STATUS: Ready for development!"

    # Wait for user interrupt
    wait
}

# =============================================================================
# STATUS & LOGGING MODULE
# =============================================================================

# Show service status with enhanced details
show_status() {
    log "HEADER" "Enhanced Service Status"

    echo ""
    log "INFO" "Service URLs:"
    echo "   Backend API           → http://localhost:$BACKEND_PORT"
    echo "   Frontend App          → http://localhost:$FRONTEND_PORT"
    echo "   API Documentation     → http://localhost:$BACKEND_PORT/swagger-ui.html"
    echo "   Redis Commander       → http://localhost:8081"
    echo ""

    if command_exists docker && docker ps | grep -q "java-dev-"; then
        log "INFO" "Database Services:"
        echo "   PostgreSQL            → localhost:$POSTGRES_PORT"
        echo "   MongoDB               → localhost:$MONGO_PORT"
        echo "   Redis                 → localhost:$REDIS_PORT"
        echo ""
    fi

    log "INFO" "Log Files:"
    echo "   Main log              → logs/fjdtool.log"
    echo "   Backend logs          → backend/backend.log"
    echo "   Frontend logs         → frontend/frontend.log"
    echo ""

    log "INFO" "System Configuration:"
    echo "   Device Class          → ${DEVICE_CLASS:-Not detected yet}"
    echo "   JVM Heap Size         → ${JVM_HEAP_SIZE:-Not configured yet}"
    echo "   Database Pool Size    → ${DB_POOL_SIZE:-Not configured yet}"
    echo "   Monitoring Enabled    → ${ENABLE_MONITORING:-Not configured yet}"
    echo ""

    # Show helpful next steps
    echo "💡 Quick Start Tips:"
    echo "   1. Run './java-dev-toolkit.sh setup' to initialize the project"
    echo "   2. Run './java-dev-toolkit.sh start' to launch all services"
    echo "   3. Use './java-dev-toolkit.sh --help' for all available commands"
    echo ""
}

# Show logs with filtering and following options
show_logs() {
    echo ""
    log "HEADER" "Log Management"
    echo ""

    echo "Available log files:"
    echo "1. Main log (fjdtool.log)"
    echo "2. Backend log (backend/backend.log)"
    echo "3. Frontend log (frontend/frontend.log)"
    echo "4. All logs"
    echo ""

    read -p "Select log file (1-4) or press Enter for main log: " choice
    choice="${choice:-1}"

    case "$choice" in
        1) log_file="logs/fjdtool.log" ;;
        2) log_file="backend/backend.log" ;;
        3) log_file="frontend/frontend.log" ;;
        4) show_all_logs; return ;;
        *) log_file="logs/fjdtool.log" ;;
    esac

    if [ -f "$log_file" ]; then
        echo ""
        log "INFO" "Showing logs for: $log_file"
        echo "Commands: f=follow, s=search, c=clear, q=quit"
        echo ""

        # Show last 50 lines by default
        tail -n 50 -f "$log_file" 2>/dev/null || cat "$log_file"
    else
        log "WARN" "Log file not found: $log_file"
    fi
}

# Show all logs in a consolidated view
show_all_logs() {
    echo ""
    log "HEADER" "All System Logs"
    echo ""

    if [ -f "logs/fjdtool.log" ]; then
        echo -e "${BLUE}=== Java Dev Toolkit Log ===${NC}"
        tail -n 20 "logs/fjdtool.log"
        echo ""
    fi

    if [ -f "backend/backend.log" ]; then
        echo -e "${BLUE}=== Backend Log ===${NC}"
        tail -n 20 "backend/backend.log"
        echo ""
    fi

    if [ -f "frontend/frontend.log" ]; then
        echo -e "${BLUE}=== Frontend Log ===${NC}"
        tail -n 20 "frontend/frontend.log"
        echo ""
    fi
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

# Show help information
show_help() {
    cat << EOF
       JAVA DEVELOPER TOOLKIT v$SCRIPT_VERSION

USAGE:
  $SCRIPT_NAME [COMMAND] [OPTIONS]

CORE COMMANDS:
  setup                    Set up the complete development environment
  start                    Start all services with adaptive configuration
  stop                     Stop all running services
  status                   Show detailed service status
  logs                     View and manage application logs
  config                   Interactive configuration wizard

ADVANCED COMMANDS:
  start backend           Start only backend service
  start frontend          Start only frontend service
  start databases         Start only database services

OPTIONS:
  -v, --version           Show version information
  -h, --help              Show this help message
  --debug                 Enable debug logging
  --no-color              Disable colored output

EXAMPLES:
  $SCRIPT_NAME setup
  $SCRIPT_NAME start
  $SCRIPT_NAME status
  $SCRIPT_NAME logs

For more information, visit: https://github.com/your-repo/java-developer-toolkit
EOF
}

# Test retro gaming progress bar functionality
test_retro_gaming_progress() {
    log "HEADER" "Testing Retro Gaming Progress Bar"

    echo ""
    log "INFO" "Testing retro gaming progress bar with animated demonstration..."
    echo ""

    # Initialize progress system
    init_progress_system

    # Test 1: Basic progress simulation
    log "INFO" "Test 1: Basic progress simulation"
    for ((i=0; i<=100; i+=5)); do
        show_progress "$i" "100" "Loading Game Assets" "retro" "test1"
        sleep 0.1
    done
    complete_progress "Game Assets Loaded" "retro" "test1"

    echo ""

    # Test 2: Operation progress simulation
    log "INFO" "Test 2: Operation progress simulation"
    for ((i=0; i<=100; i+=3)); do
        show_operation_progress "Compiling Pixel Art" "$i" "100" "retro"
        sleep 0.08
    done
    complete_progress "Pixel Art Compilation Complete" "retro" "op_test"

    echo ""

    # Test 3: Multiple simultaneous progress bars
    log "INFO" "Test 3: Multiple simultaneous progress bars"
    for ((i=0; i<=100; i+=4)); do
        show_progress "$i" "100" "Player Health" "retro" "health"
        show_progress "$((i/2))" "50" "Enemy AI" "retro" "enemy"
        show_progress "$((i*2))" "200" "Score Multiplier" "retro" "score"
        sleep 0.12
    done
    complete_progress "Game Level Complete" "retro" "health"
    complete_progress "Enemy AI Complete" "retro" "enemy"
    complete_progress "Score Multiplier Complete" "retro" "score"

    echo ""

    # Test 4: Fast completion test
    log "INFO" "Test 4: Fast completion test"
    for ((i=0; i<=100; i+=10)); do
        show_progress "$i" "100" "Speed Run Challenge" "retro" "speed"
        sleep 0.05
    done
    complete_progress "Speed Run Challenge Complete" "retro" "speed"

    echo ""

    # Test 5: Slow detailed progress
    log "INFO" "Test 5: Slow detailed progress simulation"
    for ((i=0; i<=100; i+=2)); do
        show_progress "$i" "100" "Detailed Pixel Rendering" "retro" "detailed"
        sleep 0.15
    done
    complete_progress "Detailed Pixel Rendering Complete" "retro" "detailed"

    echo ""
    log "SUCCESS" "Retro gaming progress bar test completed successfully!"
    log "INFO" "All animations, colors, and completion effects are working properly."

    # Cleanup progress system
    cleanup_progress_system
}

# Parse command line arguments
parse_args() {
    case "${1:-}" in
        "setup") setup_project ;;
        "start")
            case "${2:-}" in
                "backend") start_backend ;;
                "frontend") start_frontend ;;
                "databases") start_databases ;;
                *) start_all ;;
            esac
            ;;
        "stop") stop_all_services ;;
        "status") show_status ;;
        "logs") show_logs ;;
        "config") configure_interactive ;;
        "test-retro"|"test-retro-gaming") test_retro_gaming_progress ;;
        "-v"|"--version") echo "Java Developer Toolkit version $SCRIPT_VERSION" ;;
        "-h"|"--help"|*) show_help ;;
    esac
}

# =============================================================================
# SIGNAL HANDLING & CLEANUP
# =============================================================================

# Cleanup function for graceful shutdown
cleanup() {
    log "INFO" "Received shutdown signal, cleaning up..."

    # Stop all services
    stop_all_services

    # Kill monitoring if running
    if [ -n "$MONITOR_PID" ] && ps -p "$MONITOR_PID" >/dev/null 2>&1; then
        kill -TERM "$MONITOR_PID" 2>/dev/null || true
    fi

    log "SUCCESS" "Cleanup completed!"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

# Main function
main() {
    # Load existing configuration
    load_config

    # Override log level if debug is requested
    if [[ "${1:-}" == "--debug" ]]; then
        LOG_LEVEL="DEBUG"
        shift
    fi

    # Disable colors if requested
    if [[ "${1:-}" == "--no-color" ]]; then
        RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' BOLD='' NC=''
        shift
    fi

    # Parse and execute command
    parse_args "$@"
}

# Run main function with all arguments
main "$@"
