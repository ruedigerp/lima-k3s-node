{ config, modulesPath, pkgs, lib, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking.hostName = "k3s-node";

  # lima-init imperatively adds a user at startup. `users.mutableUsers` must stay
  # `true` or `nixos-rebuild` overwrites that user and login breaks.
  users.mutableUsers = true;

  # lima-init, lima-guestagent, and other Lima glue (via nixos-lima.nixosModules.lima)
  services.lima.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.openssh.enable = true;

  security.sudo.wheelNeedsPassword = false;

  # Matches the disk layout of the pre-built nixos-lima VM image.
  boot.loader.grub = {
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  fileSystems."/boot" = {
    device = lib.mkForce "/dev/vda1"; # /dev/disk/by-label/ESP
    fsType = "vfat";
  };
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
    options = [ "noatime" "nodiratime" "discard" ];
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.systemPackages = with pkgs; [
    vim
    git
    kubectl
    htop
  ];

  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--tls-san=127.0.0.1"
      "--tls-san=localhost"
      "--write-kubeconfig-mode=644"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 22 6443 ];

  system.stateVersion = "26.05";
}
