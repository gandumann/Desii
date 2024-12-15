#!/bin/sh
#############################
# License Validation Script #
#############################

# URL of the licenses.txt file
license_url="https://raw.githubusercontent.com/Shivanshbrop/install.sh/refs/heads/main/license.txt"  # Replace with your actual URL

# Prompt user for their license key
read -p "Enter your license key: " user_license

# Fetch the licenses from the remote URL
license_list=$(curl -s "$license_url")

# Check if curl command succeeded
if [ $? -ne 0 ]; then
    echo "Error: Could not fetch license list from $license_url."
    echo "Please check your internet connection or the URL."
    exit 1
fi

# Check if the license list is empty
if [ -z "$license_list" ]; then
    echo "Error: License list is empty."
    exit 1
fi

# Create a temporary file to hold the license list
temp_file=$(mktemp)
echo "$license_list" > "$temp_file"

# Initialize a flag for valid license
valid_license_found=false

# Validate the license by checking each line in the temporary file
while IFS= read -r line; do
    line=$(echo "$line" | xargs)  # Trim leading/trailing whitespace
    if [ "$line" = "$user_license" ]; then
        echo "Valid license found. Proceeding with the operation."
        valid_license_found=true  # Set flag to true if a valid license is found
        break  # Exit the loop immediately after finding a valid license
    fi
done < "$temp_file"  # Read from the temporary file

# Clean up the temporary file
rm "$temp_file"

# Check if a valid license was found
if [ "$valid_license_found" = false ]; then
    echo "Invalid license. Aborting operation."
    exit 1  # Exit with error if no valid license was found
fi

#############################
# Alpine Linux Installation #
#############################

# Define the root directory to /home/container.
# We can only write in /home/container and /tmp in the container.
ROOTFS_DIR=/home/container

# Define the Alpine Linux version we are going to be using.
ALPINE_VERSION="3.18"
ALPINE_FULL_VERSION="3.18.3"
APK_TOOLS_VERSION="2.14.0-r2" # Make sure to update this too when updating Alpine Linux.
PROOT_VERSION="5.3.0" # Some releases do not have static builds attached.

# Detect the machine architecture.
ARCH=$(uname -m)

# Check machine architecture to make sure it is supported.
# If not, we exit with a non-zero status code.
if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
  ARCH_ALT=arm64
else
  printf "Unsupported CPU architecture: ${ARCH}\n"
  exit 1
fi

# Download & decompress the Alpine linux root file system if not already installed.
if [ ! -e $ROOTFS_DIR/.installed ]; then
    # Download Alpine Linux root file system.
    curl -Lo /tmp/rootfs.tar.gz \
    "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/${ARCH}/alpine-minirootfs-${ALPINE_FULL_VERSION}-${ARCH}.tar.gz"
    # Extract the Alpine Linux root file system.
    tar -xzf /tmp/rootfs.tar.gz -C $ROOTFS_DIR
fi

################################
# Package Installation & Setup #
################################

# Download static APK-Tools temporarily because minirootfs does not come with APK pre-installed.
if [ ! -e $ROOTFS_DIR/.installed ]; then
    # Download the packages from their sources.
    curl -Lo /tmp/apk-tools-static.apk "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main/${ARCH}/apk-tools-static-${APK_TOOLS_VERSION}.apk"
    curl -Lo /tmp/gotty.tar.gz "https://github.com/sorenisanerd/gotty/releases/download/v1.5.0/gotty_v1.5.0_linux_${ARCH_ALT}.tar.gz"
    curl -Lo $ROOTFS_DIR/usr/local/bin/proot "https://github.com/proot-me/proot/releases/download/v${PROOT_VERSION}/proot-v${PROOT_VERSION}-${ARCH}-static"
    # Extract everything that needs to be extracted.
    tar -xzf /tmp/apk-tools-static.apk -C /tmp/
    tar -xzf /tmp/gotty.tar.gz -C $ROOTFS_DIR/usr/local/bin
    # Install base system packages using the static APK-Tools.
    /tmp/sbin/apk.static -X "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main/" -U --allow-untrusted --root $ROOTFS_DIR add alpine-base apk-tools
    # Make PRoot and GoTTY executable.
    chmod 755 $ROOTFS_DIR/usr/local/bin/proot $ROOTFS_DIR/usr/local/bin/gotty
fi

# Clean-up after installation complete & finish up.
if [ ! -e $ROOTFS_DIR/.installed ]; then
    # Add DNS Resolver nameservers to resolv.conf.
    printf "nameserver 1.1.1.1\nnameserver 1.0.0.1" > ${ROOTFS_DIR}/etc/resolv.conf
    # Wipe the files we downloaded into /tmp previously.
    rm -rf /tmp/apk-tools-static.apk /tmp/rootfs.tar.gz /tmp/sbin
    # Create .installed to later check whether Alpine is installed.
    touch $ROOTFS_DIR/.installed
fi

# Print some useful information to the terminal before entering PRoot.
clear && cat << EOF

__  _______      _  ____     ____  __ 
\ \/ / ____|    | |/ /\ \   / /  \/  |
 \  /|  _| _____| ' /  \ \ / /| |\/| |
 /  \| |__|_____| . \   \ V / | |  | |
/_/\_\_____|    |_|\_\   \_/  |_|  |_|
XE  Premium KVM VPS Installation Script (Leaking this script will result in an instant blacklist and ban.)
Discord: bahi tri maki chodi the bro na

EOF

###########################
# Start PRoot environment #
###########################

# Check if Alpine is installed and run QEMU accordingly.
if [ -e $ROOTFS_DIR/root/ubuntu-22.qcow2 ]; then
    # If installed, directly run QEMU.
    $ROOTFS_DIR/usr/local/bin/proot \
    --rootfs="${ROOTFS_DIR}" \
    --link2symlink \
    --kill-on-exit \
    --root-id \
    --cwd=/root \
    --bind=/proc \
    --bind=/dev \
    --bind=/sys \
    --bind=/tmp \
    /bin/sh -c "qemu-system-x86_64 -drive file=ubuntu-22.qcow2,format=qcow2 -drive file=user-data.img,format=raw -device virtio-net-pci,netdev=n0 -netdev user,id=n0 -m 4G -accel tcg -cpu qemu64 -nographic"
else
    # If not installed, start the installation and QEMU.
    $ROOTFS_DIR/usr/local/bin/proot \
    --rootfs="${ROOTFS_DIR}" \
    --link2symlink \
    --kill-on-exit \
    --root-id \
    --cwd=/root \
    --bind=/proc \
    --bind=/dev \
    --bind=/sys \
    --bind=/tmp \
    /bin/sh -c "apk add curl && curl -Lo ubuntu-22.qcow2 https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img && apk add qemu qemu-img qemu-system-x86_64 qemu-ui-gtk && curl -Lo user-data https://raw.githubusercontent.com/Shivanshbrop/install.sh/refs/heads/main/user-data.txt && curl -Lo user-data.img https://github.com/Shivanshbrop/install.sh/raw/refs/heads/main/user-data.img && qemu-img resize ubuntu-22.qcow2 +10G && qemu-system-x86_64 -drive file=ubuntu-22.qcow2,format=qcow2 -drive file=user-data.img,format=raw -device virtio-net-pci,netdev=n0 -netdev user,id=n0 -m 4G -accel tcg -cpu qemu64 -nographic"
fi
