#!/bin/bash

# Read users from JSON and create them
echo "Creating users..."

# Parse users.json and create users
users=$(cat /users.json)
count=$(echo "$users" | jq length)

for ((i = 0; i < count; i++)); do
    username=$(echo "$users" | jq -r ".[$i].username")
    password=$(echo "$users" | jq -r ".[$i].password")

    # Check if user already exists in /etc/passwd
    if ! id "$username" &>/dev/null; then
        # Create user (home dir may already exist on the persistent volume)
        useradd -m -s /bin/bash "$username"
        echo "${username}:${password}" | chpasswd
        echo "Created user: $username"
    else
        echo "User already exists: $username"
    fi

    # Seed home directory if it looks like a fresh mount (no dotfiles yet).
    # This runs on every start so new users added to users.json are also seeded,
    # but existing files are never overwritten (cp -n).
    home_dir="/home/$username"
    mkdir -p "$home_dir"

    if [ ! -f "$home_dir/.profile" ]; then
        # First-time setup: copy all dotfiles
        cp -a /dotfiles/. "$home_dir/"
        echo "Seeded dotfiles for: $username"
    fi

    # Ensure the test directory/README is present (safe to re-run)
    if [ ! -f "$home_dir/test/README.md" ]; then
        mkdir -p "$home_dir/test"
        cp /test/REAME.md "$home_dir/test/README.md"
    fi

    chown -R "$username:$username" "$home_dir"
done

echo "Starting SSH daemon..."
exec /usr/sbin/sshd -D -e
