#!/bin/bash

# Configuration
MIN_BATCH_SIZE=10
MAX_BATCH_SIZE=100
MIN_INTERVAL=1    # minimum seconds between batches
MAX_INTERVAL=10   # maximum seconds between batches
CONCURRENCY=50    # concurrent requests per batch

# Post data (inline, no external files needed)
POST_DATA_A="vote=a"
POST_DATA_B="vote=b"

# Prompt user for configuration
echo "Random Voting Script"
echo "==================="
echo ""

# Get vote URL
read -p "Enter vote URL [default: http://vote/]: " input_url
if [ -z "$input_url" ]; then
    VOTE_URL="http://vote/"
else
    VOTE_URL="$input_url"
fi
echo "Using URL: $VOTE_URL"
echo ""

# Get voting mode
echo "Voting mode:"
echo "1) Enter total number of votes"
echo "2) Run continuously (CTRL+C to stop)"
echo ""
read -p "Choose option (1 or 2): " choice

INFINITE_MODE=false
TOTAL_VOTES=0

case $choice in
    1)
        read -p "Enter total number of votes: " TOTAL_VOTES
        if ! [[ "$TOTAL_VOTES" =~ ^[0-9]+$ ]] || [ "$TOTAL_VOTES" -le 0 ]; then
            echo "Error: Please enter a valid positive number"
            exit 1
        fi
        echo "Will send $TOTAL_VOTES total votes"
        ;;
    2)
        INFINITE_MODE=true
        echo "Running in infinite mode - press CTRL+C to stop"
        # Set up trap to handle CTRL+C gracefully
        trap 'echo -e "\n\nVoting stopped by user. Total votes sent: $votes_sent"; exit 0' SIGINT
        ;;
    *)
        echo "Invalid option. Please choose 1 or 2."
        exit 1
        ;;
esac

echo ""

# Function to generate random number between min and max (inclusive)
random_between() {
    local min=$1
    local max=$2
    echo $((RANDOM % (max - min + 1) + min))
}

# Function to send a single vote
send_single_vote() {
    local option=$1
    local post_data=""
    
    if [ "$option" = "A" ]; then
        post_data="$POST_DATA_A"
    else
        post_data="$POST_DATA_B"
    fi
    
    curl -s -X POST \
         -H "Content-Type: application/x-www-form-urlencoded" \
         --data "$post_data" \
         "$VOTE_URL" > /dev/null
}

# Function to send votes with concurrency
send_votes() {
    local option=$1
    local count=$2
    local pids=()
    
    echo "Sending $count votes for option $option..."
    
    # Send votes in batches to maintain concurrency limit
    local sent=0
    while [ $sent -lt $count ]; do
        # Start up to CONCURRENCY parallel requests
        local batch_count=0
        while [ $batch_count -lt $CONCURRENCY ] && [ $sent -lt $count ]; do
            send_single_vote "$option" &
            pids+=($!)
            ((sent++))
            ((batch_count++))
        done
        
        # Wait for this batch to complete
        for pid in "${pids[@]}"; do
            wait "$pid"
        done
        pids=()
    done
}

# Main voting loop
votes_sent=0
if [ "$INFINITE_MODE" = true ]; then
    echo "Starting infinite random voting process..."
else
    echo "Starting random voting process for $TOTAL_VOTES total votes..."
fi

while true; do
    # Check if we've reached the target (only in finite mode)
    if [ "$INFINITE_MODE" = false ] && [ $votes_sent -ge $TOTAL_VOTES ]; then
        break
    fi
    
    # In finite mode, calculate remaining votes and adjust batch size
    if [ "$INFINITE_MODE" = false ]; then
        remaining_votes=$((TOTAL_VOTES - votes_sent))
        max_batch=$((remaining_votes < MAX_BATCH_SIZE ? remaining_votes : MAX_BATCH_SIZE))
        batch_size=$(random_between $MIN_BATCH_SIZE $max_batch)
    else
        # In infinite mode, use full range
        batch_size=$(random_between $MIN_BATCH_SIZE $MAX_BATCH_SIZE)
    fi
    
    # Randomly choose option A or B
    if [ $((RANDOM % 2)) -eq 0 ]; then
        option="A"
    else
        option="B"
    fi
    
    # Send the votes
    send_votes "$option" "$batch_size"
    
    # Update vote counter
    votes_sent=$((votes_sent + batch_size))
    
    # Random interval before next batch
    interval=$(random_between $MIN_INTERVAL $MAX_INTERVAL)
    if [ "$INFINITE_MODE" = true ]; then
        echo "Waiting $interval seconds before next batch... (Total votes sent: $votes_sent)"
    else
        echo "Waiting $interval seconds before next batch... ($votes_sent/$TOTAL_VOTES votes sent)"
    fi
    sleep "$interval"
done

if [ "$INFINITE_MODE" = false ]; then
    echo "Voting complete! Sent $votes_sent total votes."
fi