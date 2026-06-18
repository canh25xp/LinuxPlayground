#!/bin/bash

# Create shared git group
if ! getent group git-users >/dev/null; then
    groupadd git-users
fi

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
    chmod 700 "$home_dir"

    if [ ! -d "$home_dir/.config" ]; then
        # First-time setup: copy all dotfiles
        cp -a /dotfiles/. "$home_dir/"
        echo "Seeded dotfiles for: $username"
    fi

    chown -R "$username:$username" "$home_dir"
    usermod -aG git-users "$username"
done

# Shared directory accessible by all users
SHARED_DIR="/home/shared"
if [ ! -d $SHARED_DIR ]; then
    mkdir -p $SHARED_DIR
    chmod 1777 $SHARED_DIR # sticky bit: anyone can write, but only owner can delete their own files
    echo "Created $SHARED_DIR"
fi

REPOS_DIR="$SHARED_DIR/repos"
if [ ! -d $REPOS_DIR ]; then
    mkdir -p $REPOS_DIR
    chown root:git-users $REPOS_DIR
    chmod 2775 $REPOS_DIR
    echo "Created $REPOS_DIR"
fi

LINUX101_DIR="$REPOS_DIR/Linux101"
if [ ! -d "$LINUX101_DIR" ]; then
    echo "Cloning Linux101..."
    git clone --bare https://github.com/canh25xp/Linux101 "$LINUX101_DIR"
    echo "Cloned Linux101 to $LINUX101_DIR"
else
    echo "Linux101 already cloned, fetching latest..."
    git -C "$LINUX101_DIR" fetch
fi

# Give read+execute access to all files/dirs; add write only to the repo itself
chmod -R a+rX "$LINUX101_DIR"

git config --system --add safe.directory "*"

# Cleanup one-time init files
rm -rf /users.json dotfiles/

echo "Starting SSH daemon..."
exec /usr/sbin/sshd -D -e
