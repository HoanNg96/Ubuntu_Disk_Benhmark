#!/bin/bash

##### PREPARE BEFORE TEST #####
#set environtments for test
loops=5
size=1G
filename=diskmark_testfile

# Check if fio is installed
if ! command -v fio &> /dev/null
then
    echo "fio is not installed. Installing fio..."

    # Identify the package manager and install fio accordingly
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update
        sudo apt-get install -y fio
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y fio
    elif [ -x "$(command -v dnf)" ]; then
        sudo dnf install -y fio
    elif [ -x "$(command -v zypper)" ]; then
        sudo zypper install -y fio
    else
        echo "Unsupported package manager. Please install fio manually."
        exit 1
    fi

    # Verify the installation
    if command -v fio &> /dev/null
    then
        echo "fio has been successfully installed."
    else
        echo "Failed to install fio."
        exit 1
    fi
fi

##### SHOW BENCHMARK RESULT #####
# Define a function to safely get variable values or return "N/A"
safe_var() {
    local var="$1"
    echo "${!var:-N/A}"
}

print_loading_animation() {
    local delay=0.1
    local spinstr='|/-\\'
    local end=false
    trap 'end=true' SIGINT SIGTERM  # Trap signals to end animation gracefully

#    printf "Loading... "
    while ! $end; do
        printf "%s " "${spinstr:0:1}"
        spinstr=${spinstr:1}${spinstr:0:1}
        sleep $delay
        printf "\b\b\b"  # Clear previous characters
    done

    # Clear remaining characters from the animation
    printf "\b\b\b   \b\b\b\b"
#    printf "\n"  # Move to the next line
}

# Function to print a blank table
print_blank_table() {
    printf "+-----------------+-----------------+-----------------+\n"
    printf "|      TYPE       |       READ      |      WRITE      |\n"
    printf "+-----------------+-----------------+-----------------+\n"
    printf "| SEQ1M (Q8T1)    |                 |                 |\n"
    printf "| SEQ1M (Q1T1)    |                 |                 |\n"
    printf "| RND4K (Q32T1)   |                 |                 |\n"
    printf "| RND4K (Q1T1)    |                 |                 |\n"
    printf "+-----------------+-----------------+-----------------+\n"
}

print_table_with_values() {
    printf "+-----------------+-----------------+-----------------+\n"
    printf "|      TYPE       |       READ      |      WRITE      |\n"
    printf "+-----------------+-----------------+-----------------+\n"
    printf "| SEQ1M (Q8T1)    | %-15s | %-15s |\n" "$(safe_var seq_read_q8)" "$(safe_var seq_write_q8)"
    printf "| SEQ1M (Q1T1)    | %-15s | %-15s |\n" "$(safe_var seq_read_q1)" "$(safe_var seq_write_q1)"
    printf "| RND4K (Q32T1)   | %-15s | %-15s |\n" "$(safe_var ran_read_q32)" "$(safe_var ran_write_q32)"
    printf "| RND4K (Q1T1)    | %-15s | %-15s |\n" "$(safe_var ran_read_q1)" "$(safe_var ran_write_q1)"
    printf "+-----------------+-----------------+-----------------+\n"
}



##### RUN FIO TESTS #####
fio_benchmark() {
# RUNNING TEST SEQUENCE READ - 8 QUEUE DEPTH - 1 THREAD
# Run the fio command and capture its output
seq_read_q8=$(fio --ioengine=libaio --direct=1 --bs=1M --size=$size --runtime=60 --time_based --group_reporting --name=seq_read_q8 --rw=read --iodepth=8 --filename=$filename --loops=$loops)

# Check if the previous command was successful
if [ $? -eq 0 ]; then
    rm $filename
else
    echo "Test READ SEQ1M (Q8T1) failed."
fi

# Extract the read bandwidth using grep and awk
seq_read_q8=$(echo "$seq_read_q8" | grep "READ: bw" | awk -F'[()]' '{print $2}')

# RUNNING TEST SEQUENCE READ - 1 QUEUE DEPTH - 1 THREAD
seq_read_q1=$(fio --ioengine=libaio --direct=1 --bs=1M --size=$size --runtime=60 --time_based --group_reporting --name=seq_read_q1 --rw=read --iodepth=1 --filename=$filename --loops=$loops)
if [ $? -eq 0 ]; then
    rm $filename
else
    echo "Test READ SEQ1M (Q1T1) failed."
fi
seq_read_q1=$(echo "$seq_read_q1" | grep "READ: bw" | awk -F'[()]' '{print $2}')

# RUNNING TEST RANDOM READ - 32 QUEUE DEPTH - 1 THREAD
ran_read_q32=$(fio --ioengine=libaio --direct=1 --bs=4k --size=$size --runtime=60 --time_based --group_reporting --name=rand_read_q32 --rw=randread --iodepth=32 --filename=$filename --loops=$loops)
if [ $? -eq 0 ]; then
    rm $filename
else
    echo "Test READ RND4K (Q32T1) failed."
fi
ran_read_q32=$(echo "$ran_read_q32" | grep "READ: bw" | awk -F'[()]' '{print $2}')

# RUNNING TEST RANDOM READ - 1 QUEUE DEPTH - 1 THREAD
ran_read_q1=$(fio --ioengine=libaio --direct=1 --bs=4k --size=$size --runtime=60 --time_based --group_reporting --name=rand_read_q1 --rw=randread --iodepth=1 --filename=$filename --loops=$loops)
if [ $? -eq 0 ]; then
    rm $filename
else
    echo "Test READ RND4K (Q1T1) failed."
fi
ran_read_q1=$(echo "$ran_read_q1" | grep "READ: bw" | awk -F'[()]' '{print $2}')

# RUNNING TEST SEQUENCE WRITE - 8 QUEUE DEPTH - 1 THREAD
seq_write_q8=$(fio --ioengine=libaio --direct=1 --bs=1M --size=$size --runtime=60 --time_based --group_reporting --name=seq_write_q8 --rw=write --iodepth=8 --filename=$filename --loops=$loops)
if [ $? -eq 0 ]; then
    rm $filename
else
    echo "Test WRITE SEQ1M (Q8T1) failed."
fi
seq_write_q8=$(echo "$seq_write_q8" | grep "WRITE: bw" | awk -F'[()]' '{print $2}')

# RUNNING TEST SEQUENCE WRITE - 1 QUEUE DEPTH - 1 THREAD
seq_write_q1=$(fio --ioengine=libaio --direct=1 --bs=1M --size=$size --runtime=60 --time_based --group_reporting --name=seq_write_q1 --rw=write --iodepth=1 --filename=$filename --loops=$loops)
if [ $? -eq 0 ]; then
    rm $filename
else
    echo "Test WRITE SEQ1M (Q1T1) failed."
fi
seq_write_q1=$(echo "$seq_write_q1" | grep "WRITE: bw" | awk -F'[()]' '{print $2}')

# RUNNING TEST RANDOM WRITE - 32 QUEUE DEPTH - 1 THREAD
ran_write_q32=$(fio --ioengine=libaio --direct=1 --bs=4k --size=$size --runtime=60 --time_based --group_reporting --name=rand_write_q32 --rw=randwrite --iodepth=32 --filename=$filename --loops=$loops)
if [ $? -eq 0 ]; then
    rm $filename
else
    echo "Test WRITE RND4K (Q32T1) failed."
fi
ran_write_q32=$(echo "$ran_write_q32" | grep "WRITE: bw" | awk -F'[()]' '{print $2}')

# RUNNING TEST RANDOM WRITE - 1 QUEUE DEPTH - 1 THREAD
ran_write_q1=$(fio --ioengine=libaio --direct=1 --bs=4k --size=$size --runtime=60 --time_based --group_reporting --name=rand_write_q1 --rw=randwrite --iodepth=1 --filename=$filename --loops=$loops)
if [ $? -eq 0 ]; then
    rm $filename
else
    echo "Test WRITE RND4K (Q1T1) failed."
fi
ran_write_q1=$(echo "$ran_write_q1" | grep "WRITE: bw" | awk -F'[()]' '{print $2}')
}

# Start the loading animation in the background
print_loading_animation &

# Save the PID of the loading animation process
loading_pid=$!

# Call function to set variable values (simulated command execution)
fio_benchmark

# Wait for a brief moment to simulate some processing time
sleep 2

# Kill the loading animation process
kill $loading_pid >/dev/null 2>&1
wait $loading_pid 2>/dev/null

# Print the table with values
print_table_with_values $seq_read_q8 $seq_write_q8 $seq_read_q1 $seq_write_q1 $ran_read_q32 $ran_write_q32 $ran_read_q1 $ran_write_q1
