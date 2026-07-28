


#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


DISK_USAGE_THRESHOLD=80
RAM_USAGE_THRESHOLD=80

LOG_FILE="system_health_$(date +%Y-%m-%d_%H-%M-%S).log"
HISTORY_FILE="history.csv"
ENABLE_LOGGING=true


if [ ! -f "$HISTORY_FILE" ]; then
    echo "Timestamp,Resource,Detail,Value" > "$HISTORY_FILE"
fi

log_message() {
    if [ "$ENABLE_LOGGING" = true ]; then
        echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    fi
}

print_header() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  System Resource & Health Monitoring   ${NC}"
    echo -e "${BLUE}=========================================${NC}"
    log_message "========================================="
    log_message "  System Resource & Health Monitoring   "
    log_message "========================================="
}

monitor_disk_usage() {
    echo -e "\n${BLUE}--- Disk Usage ---${NC}"
    log_message "\n--- Disk Usage ---"
    df -h | awk 'NR==1 || /^\/dev\//{printf "%-30s %-10s %-10s %-10s %-5s %-10s\n", $1, $2, $3, $4, $5, $6}' | while read -r line; do
        echo "$line"
        log_message "$line"
        usage=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        partition=$(echo "$line" | awk '{print $1}')
        if [[ "$usage" =~ ^[0-9]+$ ]]; then
            echo "$(date +'%Y-%m-%d %H:%M:%S'),Disk,$partition,${usage}%" >> "$HISTORY_FILE"
            if [ "$usage" -ge "$DISK_USAGE_THRESHOLD" ]; then
                echo -e "${RED}WARNING: Disk usage for $partition is at ${usage}%${NC}"
                log_message "WARNING: Disk usage for $partition is at ${usage}%"
            fi
        fi
    done
}

monitor_ram_usage() {
    echo -e "\n${BLUE}--- RAM Usage ---${NC}"
    log_message "\n--- RAM Usage ---"
    free_output=$(free -m)
    echo "$free_output"
    log_message "$free_output"

    total_mem=$(echo "$free_output" | awk '/^Mem:/{print $2}')
    used_mem=$(echo "$free_output" | awk '/^Mem:/{print $3}')

    if [[ "$used_mem" =~ ^[0-9]+$ ]] && [[ "$total_mem" =~ ^[0-9]+$ ]] && [ "$total_mem" -ne 0 ]; then
        ram_percentage=$(( used_mem * 100 / total_mem ))
        echo "$(date +'%Y-%m-%d %H:%M:%S'),RAM,Total:${total_mem}MB,${ram_percentage}%" >> "$HISTORY_FILE"
        if [ "$ram_percentage" -ge "$RAM_USAGE_THRESHOLD" ]; then
            echo -e "${YELLOW}WARNING: RAM usage is at ${ram_percentage}%${NC}"
            log_message "WARNING: RAM usage is at ${ram_percentage}%"
        fi
    else
        echo -e "${YELLOW}INFO: Could not calculate RAM usage percentage.${NC}"
        log_message "INFO: Could not calculate RAM usage percentage."
    fi
}

monitor_cpu_usage() {
    echo -e "\n${BLUE}--- CPU Usage (Top 5 processes) ---${NC}"
    log_message "\n--- CPU Usage (Top 5 processes) ---"
    ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 6 | tee -a >(log_message)

    total_cpu=$(ps -eo %cpu --no-headers | awk '{sum+=$1} END {print sum}')
    total_cpu_int=$(printf "%.0f" "$total_cpu")
    echo "$(date +'%Y-%m-%d %H:%M:%S'),CPU,Total,${total_cpu_int}%" >> "$HISTORY_FILE"
}

monitor_uptime_load() {
    echo -e "\n${BLUE}--- System Uptime & Load Average ---${NC}"
    log_message "\n--- System Uptime & Load Average ---"
    uptime_info=$(uptime)
    echo "$uptime_info"
    log_message "$uptime_info"
}

check_service_status() {
    service_name="$1"
    echo -e "\n${BLUE}--- Service Status: $service_name ---${NC}"
    log_message "\n--- Service Status: $service_name ---"
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet "$service_name"; then
            echo -e "${GREEN}$service_name is running.${NC}"
            log_message "$service_name is running."
            echo "$(date +'%Y-%m-%d %H:%M:%S'),Service,$service_name,Running" >> "$HISTORY_FILE"
        else
            echo -e "${RED}ALERT: $service_name is NOT running.${NC}"
            log_message "ALERT: $service_name is NOT running."
            echo "$(date +'%Y-%m-%d %H:%M:%S'),Service,$service_name,Not Running" >> "$HISTORY_FILE"
        fi
    elif command -v service &> /dev/null; then
        if service "$service_name" status &> /dev/null; then
            echo -e "${GREEN}$service_name is running.${NC}"
            log_message "$service_name is running."
            echo "$(date +'%Y-%m-%d %H:%M:%S'),Service,$service_name,Running" >> "$HISTORY_FILE"
        else
            echo -e "${RED}ALERT: $service_name is NOT running.${NC}"
            log_message "ALERT: $service_name is NOT running."
            echo "$(date +'%Y-%m-%d %H:%M:%S'),Service,$service_name,Not Running" >> "$HISTORY_FILE"
        fi
    else
        echo -e "${YELLOW}WARNING: Could not determine status of $service_name.${NC}"
        log_message "WARNING: Could not determine status of $service_name."
    fi
}

monitor_network_usage() {
    echo -e "\n${BLUE}--- Network Interfaces ---${NC}"
    log_message "\n--- Network Interfaces ---"
    ip -s link | tee -a >(log_message)

    echo -e "\n${BLUE}--- Internet Connectivity Check (ping google.com) ---${NC}"
    log_message "\n--- Internet Connectivity Check (ping google.com) ---"
    if ping -c 1 -W 2 google.com &> /dev/null; then
        echo -e "${GREEN}Internet connection is UP.${NC}"
        log_message "Internet connection is UP."
        echo "$(date +'%Y-%m-%d %H:%M:%S'),Internet,Connection,UP" >> "$HISTORY_FILE"
    else
        echo -e "${RED}ALERT: Internet connection is DOWN.${NC}"
        log_message "ALERT: Internet connection is DOWN."
        echo "$(date +'%Y-%m-%d %H:%M:%S'),Internet,Connection,DOWN" >> "$HISTORY_FILE"
    fi
}

main() {
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "Logging to: $LOG_FILE"
        echo "System Health Report - $(date)" > "$LOG_FILE"
        echo "=======================================" >> "$LOG_FILE"
    fi

    while true; do
        clear
        print_header
        monitor_disk_usage
        monitor_ram_usage
        monitor_cpu_usage
        monitor_uptime_load
        check_service_status "sshd"
        monitor_network_usage

        echo -e "\n${BLUE}=========================================${NC}"
        echo -e "Dashboard updates every 10 seconds. Press [CTRL+C] to exit."
        echo -e "Log file: $LOG_FILE"
        echo -e "History file: $HISTORY_FILE"
        log_message "--- End of current cycle ---"

        sleep 10
    done
}

trap ctrl_c INT
ctrl_c() {
    echo -e "\n${YELLOW}Monitoring stopped by user.${NC}"
    log_message "Monitoring stopped by user."
    exit 0
}

main