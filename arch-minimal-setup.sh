#!/bin/bash

set -euo pipefail
trap 'echo "Error occurred at line $LINENO. Exiting."; exit 1' ERR

echo "Updating system..."
sudo pacman -Syu --noconfirm

# Detect CPU
CPU_VENDOR=$(lscpu | grep -i 'vendor id' | awk '{print $3}')
echo "Detected CPU vendor: $CPU_VENDOR"

if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
  echo "Installing Intel microcode..."
  sudo pacman -S --noconfirm --needed intel-ucode
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
  echo "Installing AMD microcode..."
  sudo pacman -S --noconfirm --needed amd-ucode
else
  echo "Unknown CPU vendor. Skipping microcode install."
fi

# Detect GPU
GPU_INFO=$(lspci | grep -E "VGA|3D")
echo "Detected GPU: $GPU_INFO"

if echo "$GPU_INFO" | grep -qi "NVIDIA"; then
  echo "Installing NVIDIA drivers..."
  sudo pacman -S --noconfirm --needed \
  nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings \
  vulkan-icd-loader lib32-vulkan-icd-loader mesa lib32-mesa

elif echo "$GPU_INFO" | grep -qi "AMD"; then
  echo "Installing AMD GPU drivers..."
  sudo pacman -S --noconfirm --needed \
  xf86-video-amdgpu mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon

elif echo "$GPU_INFO" | grep -qi "Intel"; then
  echo "Installing Intel GPU drivers..."
  sudo pacman -S --noconfirm --needed \
  mesa lib32-mesa vulkan-intel lib32-vulkan-intel

else
  echo "Unknown GPU detected. Skipping driver install."
fi

# Core
echo "Installing essential packages..."
sudo pacman -S --noconfirm --needed \
base-devel git fastfetch curl htop vim \
gnome-tweaks gnome-shell-extensions gnome-terminal gnome-shell \
gnome-control-center nautilus file-roller loupe evince \
xdg-user-dirs-gtk gnome-keyring gdm \
thermald cpupower power-profiles-daemon \
gvfs gvfs-mtp xdg-user-dirs xdg-utils vlc flatpak gedit

# Install Yay
echo "Checking for yay..."
if ! command -v yay &>/dev/null; then
  cd /tmp
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
fi

# AUR packages
echo "Installing AUR packages..."
yay -S --noconfirm --needed \
brave-bin unityhub spotify steam motrix-bin vlc-plugins-all

# Flatpak
echo "Configuring Flatpak..."
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Flatpak user directories
echo "Setting up user directories..."
xdg-user-dirs-update

# NVIDIA Persistence
if echo "$GPU_INFO" | grep -qi "NVIDIA"; then
  echo "Enabling NVIDIA persistence mode..."
  sudo nvidia-smi -pm 1 || true
fi

# Maximize CPU Performance
echo "Setting CPU governor to performance..."
sudo cpupower frequency-set -g performance || true

# Enable services
echo "Enabling services..."
sudo systemctl enable --now gdm.service
sudo systemctl enable --now thermald.service
sudo systemctl enable --now power-profiles-daemon.service
sudo systemctl enable --now cpupower.service

# Cleanup
echo "Cleaning package cache..."
sudo pacman -Sc --noconfirm || true

echo "Setup complete! Please reboot your system."

