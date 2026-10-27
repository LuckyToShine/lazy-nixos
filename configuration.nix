{ config, pkgs, lib, zen-browser, inputs, ... }:

{
  virtualisation = {
    waydroid.enable = true;
    waydroid.package = pkgs.waydroid-nftables;
  };

  imports = [
    # Hardware scan results and module inputs
    ./hardware-configuration.nix
    inputs.niri.nixosModules.niri
    inputs.inir.nixosModules.inir
  ];
  # ==========================================
  # BOOTLOADER CONFIGURATION (GRUB2 for UEFI)
  # ==========================================
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  boot.loader.grub = {
    enable = true;
    theme = ./minegrub-world-sel-theme/minegrub-world-selection;
    efiSupport = true;
    device = "nodev";
    useOSProber = true; # Detect other OSes
    configurationLimit = 5; # Limit generations to prevent USB storage exhaustion
  };

  # ==========================================
  # KERNEL & PERFORMANCE OPTIMIZATIONS
  # ==========================================
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "tcp_bbr" ];

  # Network Congestion Control (TCP BBR)
  boot.kernel.sysctl = {
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
    "net.core.wmem_max" = 1073741824;
    "net.core.rmem_max" = 1073741824;
    "net.ipv4.tcp_rmem" = "4096 87380 1073741824";
    "net.ipv4.tcp_wmem" = "4096 87380 1073741824";
  };

  powerManagement.cpuFreqGovernor = "performance";

  # Wayland LED (WLED)
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="leds", KERNEL=="*::scrolllock", RUN+="${pkgs.coreutils}/bin/chmod a+w /sys/class/leds/%k/brightness"
  '';

  services.envfs.enable = true;

  # ==========================================
  # NETWORKING & LOCALE
  # ==========================================
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Mexico_City";
  i18n.defaultLocale = "en_US.UTF-8";
  services.timesyncd.enable = true;

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # ==========================================
  # DISPLAY & WINDOW MANAGER (Niri + inir)
  # ==========================================
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
    desktopManager = {
      xterm.enable = false;
      xfce.enable = false;
    };
 
    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        dmenu #application launcher most people use
        i3status # gives you the default i3 status bar
        i3lock #default i3 screen locker
      ];
    };
  };

  services.displayManager.sddm.enable = true;
  services.displayManager.defaultSession = "niri";

  networking.firewall.allowedTCPPorts = [ 53317 ];
  networking.firewall.allowedUDPPorts = [ 53317 ];

  # Window Manager
  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

  programs.inir = {
    enable = true;
    service.compositor = "niri";
    extraPackages = [ config.programs.niri.package ];
  };

  # XDG Portals
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  # ==========================================
  # FONTS CONFIGURATION
  # ==========================================
  fonts.packages = with pkgs; [
    udev-gothic-nf
    noto-fonts
    liberation_ttf
    material-symbols
    material-design-icons
    (pkgs.runCommand "miracode-font" {} ''
      mkdir -p $out/share/fonts/truetype
      cp ${pkgs.fetchurl {
        url = "https://github.com/IdreesInc/Miracode/releases/download/v1.0/Miracode.ttf";
        sha256 = "sha256-Q+/D/TPlqOt779qYS/dF7ahEd3Mm4a4G+wdHB+Gutmo=";
      }} $out/share/fonts/truetype/Miracode.ttf
    '')
  ];

  fonts.fontconfig = {
    enable = true;
    hinting.style = "slight";
    subpixel.rgba = "rgb";
  };

  # ==========================================
  # AUDIO & SERVICES
  # ==========================================
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.blueman.enable = true;
  services.openssh.enable = true;
  services.power-profiles-daemon.enable = true;
  services.printing.enable = false;
  services.fwupd.enable = false;

  # Enable disk mounting capabilities for Dolphin
  services.udisks2.enable = true;

  # Periodic TRIM for flash memory wear leveling
  services.fstrim.enable = true;

  # Limit journal logs size on USB
  services.journald.settings.Journal = {
    SystemMaxUse = "100M";
    RuntimeMaxUse = "50M";
  };

  # In-memory compressed swap (ZRAM) to protect USB from flash wear
  zramSwap = {
    enable = true;
    priority = 100;
    memoryPercent = 50;
  };

  # ==========================================
  # NIX STORE & DISK SPACE OPTIMIZATIONS
  # ==========================================
  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    inputs.nix-matlab.overlay
    inputs.nix-claude-code.overlays.default
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true; # Hard-link duplicate files to save GBs on USB
    warn-dirty = false;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Disable HTML / DocBook documentation to conserve USB space
  documentation = {
    enable = true;
    doc.enable = false;
    info.enable = false;
    nixos.enable = false;
  };

  # ==========================================
  # CORE PROGRAMS & INTEGRATION
  # ==========================================
  programs.bash.enable = true;
  programs.dconf.enable = true;
  programs.nix-ld.enable = true;

  # Qt / KDE Theming configuration for Dolphin & Niri
  qt = {
    enable = true;
    platformTheme = "kde";
    style = "breeze";
  };

  # ==========================================
  # USER ACCOUNT
  # ==========================================
  users.users."lazy" = {
    isNormalUser = true;
    description = "lazy";
    extraGroups = [ "networkmanager" "wheel" "video" "adbusers" ];
    shell = pkgs.bash;
    packages = with pkgs; [ ];
  };

  users.defaultUserShell = pkgs.bash;

  # ==========================================
  # SYSTEM PACKAGES (Optimized for 64GB USB)
  # ==========================================
  environment.systemPackages = with pkgs; [
    # Essentials & Core CLI Utilities
    ani-cli
    aria2
    bat
    btop
    claude-code
    curl
    direnv
    dtc
    dysk
    efibootmgr
    ente-auth
    evtest
    fastfetch
    fetch
    ffmpeg
    file
    flutter
    foot
    fzf
    gh
    git
    grim
    inotify-tools
    jdk21
    xwayland
    killall
    libreoffice-stable
    localsend
    lsd
    lutris
    matlab
    matlab-shell
    matugen
    mpv
    nodejs_22
    octave
    p7zip
    playerctl
    pnpm
    procps
    satty
    slurp
    spotify
    syncplay
    tldr
    unrar
    unzip
    vim
    vivaldi
    wev
    wget
    whitesur-icon-theme
    wmctrl
    wl-clipboard
    ydotool
    yq-go
    yt-dlp
    zbar
    zenity
    zen-browser.packages."x86_64-linux".default

    # Android tools
    android-studio
    android-tools
    androguard
    apktool
    apksigner
    binutils
    dex2jar
    jadx
    (python3.withPackages (ps: with ps; [
      capstone
      cryptography
      pycryptodome
      pyelftools
    ]))
    radare2
    scrcpy
    yara

    # Dependencies for inir
    brightnessctl
    cava
    cliphist
    fuzzel
    imagemagick
    jq
    libnotify
    libqalculate
    python3
    socat
    songrec
    translate-shell
    uv
    wf-recorder
    wl-clipboard
    wlsunset

    # -------------------------
    # Standalone KDE Apps & Dolphin Integration
    # -------------------------
    kdePackages.dolphin
    kdePackages.kio            # Core KIO service
    kdePackages.kio-extras     # Extra protocols (SFTP, SMB, thumbnails)
    kdePackages.kio-fuse       # Remote filesystem mounting via FUSE
    kdePackages.qtsvg          # SVG Icon support for Dolphin
    kdePackages.breeze-icons   # Fallback theme for KDE apps
    kdePackages.qtwayland      # Wayland support for Qt Apps
    kdePackages.ark            # Archive manager integrated with Dolphin

    # -------------------------
    # Quickshell Wrapped with Qt6 & Kirigami
    # -------------------------
    (pkgs.symlinkJoin {
      name = "quickshell-wrapped";
      paths = [ pkgs.quickshell ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for bin in $out/bin/quickshell $out/bin/qs; do
          wrapProgram "$bin" \
            --prefix QML_IMPORT_PATH : "${lib.makeSearchPath "lib/qt-6/qml" (with pkgs; [
              kdePackages.kirigami.unwrapped
              kdePackages.syntax-highlighting
              qt6.qt5compat
              qt6.qtmultimedia
            ])}" \
            --prefix QML2_IMPORT_PATH : "${lib.makeSearchPath "lib/qt-6/qml" (with pkgs; [
              kdePackages.kirigami.unwrapped
              kdePackages.syntax-highlighting
              qt6.qt5compat
              qt6.qtmultimedia
            ])}"
        done
      '';
    })
  ];

  environment.variables = (import ./abbr.nix).variables or {};

  environment.shellAliases = (import ./abbr.nix).shellAliases // {
    yt-dlp-zen = "yt-dlp --cookies-from-browser firefox";
  };

  # ==========================================
  # GPU / GRAPHICS CONFIGURATION
  # ==========================================
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Stateful Data Tracking
  system.stateVersion = "26.05";
}
