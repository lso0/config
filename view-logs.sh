#!/bin/bash

# Log Viewer for WGMS Setup Scripts
# Usage: ./view-logs.sh [options]

LOG_DIR="$HOME/.config/wgms-setup"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo "WGMS Setup Log Viewer"
    echo ""
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  -l, --list       List all log files"
    echo "  -r, --recent     Show most recent log"
    echo "  -a, --all        Show all logs concatenated"
    echo "  -f, --failed     Show only failed setups"
    echo "  -s, --success    Show only successful setups"
    echo "  -e, --errors     Show only error lines"
    echo "  -w, --warnings   Show only warning lines"
    echo "  -c, --commands   Show only executed commands"
    echo "  -h, --help       Show this help"
    echo ""
    echo "Log directory: $LOG_DIR"
}

list_logs() {
    echo -e "${BLUE}Available log files:${NC}"
    if [[ -d "$LOG_DIR" ]]; then
        ls -lt "$LOG_DIR"/*.log 2>/dev/null | while read -r line; do
            echo "  $line"
        done
    else
        echo "No log directory found at $LOG_DIR"
    fi
}

show_recent() {
    local recent_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
    if [[ -n "$recent_log" ]]; then
        echo -e "${GREEN}Most recent log: $recent_log${NC}"
        echo ""
        cat "$recent_log"
    else
        echo "No log files found"
    fi
}

show_all() {
    echo -e "${BLUE}All logs (chronological order):${NC}"
    echo ""
    find "$LOG_DIR" -name "*.log" 2>/dev/null | sort | while read -r log_file; do
        echo -e "${YELLOW}=== $log_file ===${NC}"
        cat "$log_file"
        echo ""
    done
}

show_failed() {
    echo -e "${RED}Failed setup logs:${NC}"
    grep -l "Exit code: [1-9]" "$LOG_DIR"/*.log 2>/dev/null | while read -r log_file; do
        echo -e "${YELLOW}=== $log_file ===${NC}"
        cat "$log_file"
        echo ""
    done
}

show_success() {
    echo -e "${GREEN}Successful setup logs:${NC}"
    grep -l "Exit code: 0" "$LOG_DIR"/*.log 2>/dev/null | while read -r log_file; do
        echo -e "${YELLOW}=== $log_file ===${NC}"
        cat "$log_file"
        echo ""
    done
}

show_errors() {
    echo -e "${RED}Error lines from all logs:${NC}"
    grep -h "ERROR:" "$LOG_DIR"/*.log 2>/dev/null | sort -u
}

show_warnings() {
    echo -e "${YELLOW}Warning lines from all logs:${NC}"
    grep -h "WARNING:" "$LOG_DIR"/*.log 2>/dev/null | sort -u
}

show_commands() {
    echo -e "${BLUE}Commands executed:${NC}"
    grep -h "COMMAND:" "$LOG_DIR"/*.log 2>/dev/null | sort -u
}

# Main logic
case "${1:-}" in
    -l|--list)
        list_logs
        ;;
    -r|--recent)
        show_recent
        ;;
    -a|--all)
        show_all
        ;;
    -f|--failed)
        show_failed
        ;;
    -s|--success)
        show_success
        ;;
    -e|--errors)
        show_errors
        ;;
    -w|--warnings)
        show_warnings
        ;;
    -c|--commands)
        show_commands
        ;;
    -h|--help|"")
        show_help
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac 