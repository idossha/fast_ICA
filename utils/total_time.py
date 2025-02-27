import sys

# Python script to calculate total time in hours from a /amicaout/out.txt file if the time is messed up

def calculate_total_time(file_path):
    total_seconds = 0

    with open(file_path, 'r') as file:
        for line in file:
            # Look for lines containing time in seconds (e.g., "(175.76 s")
            if '(' in line and 's' in line:
                try:
                    start_idx = line.index('(') + 1
                    end_idx = line.index('s')
                    time_in_seconds = float(line[start_idx:end_idx].strip())
                    total_seconds += time_in_seconds
                except ValueError:
                    continue

    total_hours = total_seconds / 3600
    return total_hours

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 total_time.py <file_path>")

    file_path = sys.argv[1]    
    total_hours = calculate_total_time(file_path)
    print(f"Total time in hours: {total_hours:.2f}")
