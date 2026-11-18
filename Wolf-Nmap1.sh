#!/bin/bash
# ============================================
#   WOLF-NMAP v2.1 (Bash Edition)
#   IP and Website Port Scanner
#   CREDIT BY Gr!m_R34p3r
#   Use only on your own device/system!
# ============================================

RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
CYAN='\033[96m'
BOLD='\033[1m'
RESET='\033[0m'

banner() {
echo -e "${RED}${BOLD}"
cat << "EOF"
 __        __   _  __     _   _ __  __    _    ____  
 \ \      / /__| |/ _|   | \ | |  \/  |  / \  |  _ \ 
  \ \ /\ / / _ \ | |_    |  \| | |\/| | / _ \ | |_) |
   \ V  V /  __/ |  _|   | |\  | |  | |/ ___ \|  __/ 
    \_/\_/ \___|_|_|     |_| \_|_|  |_/_/   \_\_|    
EOF
echo -e "${RESET}${CYAN}     IP + Website Scanner  |  v2.1 (Bash)${RESET}"
echo -e "${CYAN}     Use only on your own device/system${RESET}"
echo -e "${YELLOW}${BOLD}     CREDIT BY Gr!m_R34p3r${RESET}"
}

TARGET="127.0.0.1"
START=1
END=1000
THREADS=200

usage() {
    echo "Usage: $0 [-t target_ip_or_website] [-p start-end] [-T threads] [-h]"
    echo ""
    echo "  -t  IP or Website    (default: 127.0.0.1)"
    echo "  -p  Port range       (default: 1-1000)"
    echo "  -T  Threads          (default: 200)"
    echo "  -h  Help"
    echo ""
    echo "Examples:"
    echo "  $0 -t 127.0.0.1 -p 1-1000"
    echo "  $0 -t example.com -p 80-443"
    echo "  $0 -t https://example.com -p 1-1000"
    echo ""
    echo "CREDIT BY Gr!m_R34p3r"
    exit 0
}

while getopts "t:p:T:h" opt; do
    case $opt in
        t) TARGET="$OPTARG" ;;
        p)
            if [[ "$OPTARG" == *-* ]]; then
                START="${OPTARG%-*}"
                END="${OPTARG#*-}"
            else
                START="$OPTARG"
                END="$OPTARG"
            fi
            ;;
        T) THREADS="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate port range
if ! [[ "$START" =~ ^[0-9]+$ ]] || ! [[ "$END" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}[-] Invalid port range! Use: -p 1-1000${RESET}"
    exit 1
fi
if [ "$START" -lt 1 ] || [ "$END" -gt 65535 ] || [ "$START" -gt "$END" ]; then
    echo -e "${RED}[-] Port range must be between 1 and 65535${RESET}"
    exit 1
fi

# Resolve target (IP or website)
resolve_target() {
    local input="$1"
    input="${input#http://}"
    input="${input#https://}"
    input="${input%%/*}"

    if [[ "$input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$input"
        return 0
    fi

    local ip=""
    if command -v getent &> /dev/null; then
        ip=$(getent hosts "$input" | awk '{print $1}' | head -n1)
    fi
    if [ -z "$ip" ] && command -v dig &> /dev/null; then
        ip=$(dig +short "$input" A | head -n1)
    fi
    if [ -z "$ip" ] && command -v nslookup &> /dev/null; then
        ip=$(nslookup "$input" 2>/dev/null | awk '/^Address: / {print $2}' | tail -n1)
    fi
    if [ -z "$ip" ]; then
        echo ""
        return 1
    fi
    echo "$ip"
    return 0
}

# Check netcat
if ! command -v nc &> /dev/null; then
    echo -e "${YELLOW}[!] netcat (nc) not found. Installing...${RESET}"
    if command -v pkg &> /dev/null; then
        pkg install netcat-openbsd -y
    elif command -v apt &> /dev/null; then
        sudo apt update && sudo apt install netcat-openbsd -y
    else
        echo -e "${RED}[-] Please install netcat manually.${RESET}"
        exit 1
    fi
fi

banner

# Resolve input
ORIGINAL="$TARGET"
RESOLVED=$(resolve_target "$TARGET")

if [ -z "$RESOLVED" ]; then
    echo -e "${RED}[-] Could not resolve '$ORIGINAL'!${RESET}"
    echo -e "${YELLOW}[!] Check your internet connection or enter a valid domain.${RESET}"
    exit 1
fi

if [ "$ORIGINAL" != "$RESOLVED" ]; then
    echo -e "${CYAN}[*] Input:    ${ORIGINAL}${RESET}"
    echo -e "${CYAN}[*] Resolved: ${RESOLVED}${RESET}"
else
    echo -e "${CYAN}[*] Target:   ${RESOLVED}${RESET}"
fi

echo -e "${CYAN}[*] Ports:    ${START}-${END}${RESET}"
echo -e "${CYAN}[*] Threads:  ${THREADS}${RESET}"
echo ""
echo -e "${CYAN}[*] Wolf scanning...${RESET}"
echo ""

TMP_RESULTS=$(mktemp)
START_TIME=$(date +%s)

scan_port() {
    local port=$1
    local target=$2
    if nc -z -w1 "$target" "$port" 2>/dev/null; then
        local service="unknown"
        if command -v getent &> /dev/null; then
            service=$(getent services "$port/tcp" 2>/dev/null | awk '{print $1}')
            [ -z "$service" ] && service="unknown"
        fi
        echo -e "${RED}[OPEN] Port ${port} is open (${service})${RESET}"
        echo "$port|$service" >> "$TMP_RESULTS"
    fi
}

running=0
for ((port=START; port<=END; port++)); do
    scan_port "$port" "$RESOLVED" &
    running=$((running + 1))
    if [ "$running" -ge "$THREADS" ]; then
        wait
        running=0
    fi
done
wait

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo -e "${CYAN}=====================================${RESET}"

if [ -s "$TMP_RESULTS" ]; then
    COUNT=$(wc -l < "$TMP_RESULTS")
    echo -e "${RED}[!] Total ${COUNT} open ports found:${RESET}"
    sort -t'|' -k1 -n "$TMP_RESULTS" | while IFS='|' read -r p s; do
        echo -e "${RED}    -> Port ${p} (${s})${RESET}"
    done
else
    echo -e "${GREEN}[+] No open ports found. Safe!${RESET}"
fi

echo -e "${CYAN}[*] Time: ${ELAPSED} seconds${RESET}"
echo -e "${CYAN}=====================================${RESET}"

if [ -s "$TMP_RESULTS" ]; then
    mkdir -p wolf_results
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    OUT="wolf_results/wolf_${TIMESTAMP}.txt"
    {
        echo "WOLF-NMAP SCAN REPORT"
        echo "CREDIT BY Gr!m_R34p3r"
        echo "Input: $ORIGINAL"
        echo "Resolved IP: $RESOLVED"
        echo "Ports: $START-$END"
        echo "Time: $(date)"
        echo "Open Ports: $(wc -l < "$TMP_RESULTS")"
        echo "----------------------------------------"
        while IFS='|' read -r p s; do
            echo "Port $p  ->  $s"
        done < "$TMP_RESULTS"
    } > "$OUT"
    echo -e "${GREEN}[+] Results saved: ${OUT}${RESET}"
fi

rm -f "$TMP_RESULTS"

echo -e "${YELLOW}${BOLD}CREDIT BY Gr!m_R34p3r${RESET}"
