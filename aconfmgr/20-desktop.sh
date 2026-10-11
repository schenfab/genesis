# shellcheck shell=bash
# Common to every host: GNOME desktop, audio, fonts, desktop applications.

# Packages
AddPackage alsa-utils # Advanced Linux Sound Architecture - Utilities
AddPackage audacity # A program that lets you manipulate digital audio waveforms
AddPackage baobab # A graphical directory tree analyzer
AddPackage chromium # A web browser built for speed, simplicity, and security
AddPackage cups # OpenPrinting CUPS - daemon package
AddPackage endeavour # Personal task manager (Formerly GNOME Todo)
AddPackage eog # Eye of Gnome: An image viewing and cataloging program
AddPackage epiphany # A GNOME web browser based on the WebKit rendering engine
AddPackage evince # Document viewer (PDF, PostScript, XPS, djvu, dvi, tiff, cbr, cbz, cb7, cbt)
AddPackage feh # Fast and light imlib2-based image viewer
AddPackage file-roller # Create and modify archives
AddPackage foomatic-db # Foomatic - The collected knowledge about printers, drivers, and driver options in XML files, used by foomatic-db-engine to generate PPD files.
AddPackage foomatic-db-ppds # Foomatic - PPDs from printer manufacturers
AddPackage freecad # Feature based parametric 3D CAD modeler
AddPackage gdm # Display manager and login screen
AddPackage gedit # Easy-to-use general-purpose text editor
AddPackage gimp # GNU Image Manipulation Program
AddPackage gnome-backgrounds # Background images and data for GNOME
AddPackage gnome-calculator # GNOME Scientific calculator
AddPackage gnome-calendar # Simple and beautiful calendar application designed to perfectly fit the GNOME desktop
AddPackage gnome-characters # A character map application
AddPackage gnome-clocks # Clocks applications for GNOME
AddPackage gnome-color-manager # GNOME Color Profile Tools
AddPackage gnome-contacts # Contacts Manager for GNOME
AddPackage gnome-control-center # GNOME's main interface to configure various aspects of the desktop
AddPackage gnome-dictionary # Look up words in dictionary sources
AddPackage gnome-disk-utility # Disk Management Utility for GNOME
AddPackage gnome-font-viewer # A font viewer utility for GNOME
AddPackage gnome-keyring # Stores passwords and encryption keys
AddPackage gnome-logs # A log viewer for the systemd journal
AddPackage gnome-maps # Find places around the world
AddPackage gnome-menus # GNOME menu specifications
AddPackage gnome-music # Music player and management application
AddPackage gnome-photos # Access, organize, and share your photos on GNOME
AddPackage gnome-remote-desktop # GNOME Remote Desktop server
AddPackage gnome-screenshot # Take pictures of your screen
AddPackage gnome-session # The GNOME Session Handler
AddPackage gnome-settings-daemon # GNOME Settings Daemon
AddPackage gnome-shell # Next generation desktop shell
AddPackage gnome-shell-extensions # Extensions for GNOME shell, including classic mode
AddPackage gnome-software # Allows you to find and install new apps
AddPackage gnome-system-monitor # View current processes and monitor system state
AddPackage gnome-terminal # The GNOME Terminal Emulator
AddPackage gnome-themes-extra # Extra GNOME themes (legacy HighContrast icon theme and index files for Adwaita)
AddPackage gnome-tweaks # Graphical interface for advanced GNOME 3 settings (Tweak Tool)
AddPackage gnome-user-docs # User documentation for GNOME
AddPackage gnome-user-share # Easy to use user-level file sharing for GNOME
AddPackage gnome-video-effects # Collection of GStreamer effects for GNOME
AddPackage gnome-weather # Access current weather conditions and forecasts
AddPackage goobox # CD player and ripper for GNOME
AddPackage grilo-plugins # A collection of plugins for the Grilo framework
AddPackage gst-libav # Multimedia graph framework - libav plugin
AddPackage gvfs # Virtual filesystem implementation for GIO
AddPackage gvfs-afc # Virtual filesystem implementation for GIO - AFC backend (Apple mobile devices)
AddPackage gvfs-goa # Virtual filesystem implementation for GIO - Gnome Online Accounts backend (e.g. OwnCloud)
AddPackage gvfs-gphoto2 # Virtual filesystem implementation for GIO - gphoto2 backend (PTP camera, MTP media player)
AddPackage gvfs-mtp # Virtual filesystem implementation for GIO - MTP backend (Android, media player)
AddPackage gvfs-nfs # Virtual filesystem implementation for GIO - NFS backend
AddPackage gvfs-smb # Virtual filesystem implementation for GIO - SMB/CIFS backend (Windows file sharing)
AddPackage handbrake # Multithreaded video transcoder
AddPackage hplip # Drivers for HP DeskJet, OfficeJet, Photosmart, Business Inkjet and some LaserJet
AddPackage inkscape # Professional vector graphics editor
AddPackage keepass # Easy-to-use password manager for Windows, Linux, Mac OS X and mobile devices
AddPackage keepassxc # Cross-platform community-driven port of Keepass password manager
AddPackage kicad # Electronic schematic and printed circuit board (PCB) design tools
AddPackage kicad-library # KiCad symbol, footprint and template libraries
AddPackage kicad-library-3d # KiCad 3D model libraries
AddPackage libappindicator # Allow applications to extend a menu via Ayatana indicators in Unity, KDE or Systray
AddPackage libdvdcss # Portable abstraction library for DVD decryption
AddPackage libreoffice-fresh # LibreOffice branch which contains new features and program enhancements
AddPackage meld # Compare files, directories and working copies
AddPackage mousetweaks # Mouse accessibility enhancements
AddPackage mutter # Window manager and compositor for GNOME
AddPackage nautilus # Default file manager for GNOME
AddPackage nautilus-image-converter # Nautilus extension to rotate/resize image files
AddPackage noto-fonts-emoji # Google Noto Color Emoji font
AddPackage openscad # The programmers solid 3D CAD modeller
AddPackage orca # Screen reader for individuals who are blind or visually impaired
AddPackage pdf2svg # A pdf to svg converter
AddPackage pdftricks # Simple, efficient application for small manipulations in PDF files using Ghostscript
AddPackage pipewire-alsa # Low-latency audio/video router and processor - ALSA configuration
AddPackage pipewire-pulse # Low-latency audio/video router and processor - PulseAudio replacement
AddPackage profile-sync-daemon # Symlinks and syncs browser profile dirs to RAM
AddPackage rygel # UPnP AV MediaServer and MediaRenderer
AddPackage seahorse # GNOME application for managing PGP keys
AddPackage signal-desktop # Signal Private Messenger for Linux
AddPackage simple-scan # Simple scanning utility
AddPackage smplayer # Media player with built-in codecs that can play virtually all video and audio formats
AddPackage sushi # A quick previewer for Nautilus
AddPackage totem # Movie player for the GNOME desktop based on GStreamer
AddPackage ttf-droid # General-purpose fonts released by Google as part of Android
AddPackage wtype # xdotool type for wayland
AddPackage xdg-user-dirs-gtk # Creates user dirs and asks to relocalize them
AddPackage xdotool # Command-line X11 automation tool
AddPackage xorg-xeyes # Follow the mouse/SHAPE extension X demo
AddPackage xournalpp # Handwriting notetaking software with PDF annotation support
AddPackage xsel # Command-line program for getting and setting the contents of the X selection
AddPackage yelp # Get help with GNOME
AddPackage --foreign asunder # a graphical CD ripper and encoder
AddPackage --foreign autocutsel # synchronizes the two copy/paste buffers mainly used by X applications
AddPackage --foreign chromium-widevine # A browser plugin designed for the viewing of premium video content
AddPackage --foreign dropbox # A free service that lets you bring your photos, docs, and videos anywhere and share them easily.
AddPackage --foreign freefilesync-bin # Folder comparison and synchronization
AddPackage --foreign hplip-plugin # Binary plugin for HPs hplip printer driver library
AddPackage --foreign nautilus-dropbox # Dropbox Nautilus Extension
AddPackage --foreign playonlinux # GUI for managing Windows programs under linux
AddPackage --foreign spotify # A proprietary music streaming service
AddPackage --foreign teams-for-linux-bin # Unofficial Microsoft Teams for Linux client (binary version)

# Files, links and services
CopyFile /etc/X11/xinit/xinitrc.d/40-autocutsel.sh 755
CopyFile /etc/X11/xorg.conf.d/00-keyboard.conf
CreateDir /etc/colord '' colord colord
CopyFile /etc/cups/cupsd.conf
CreateDir /etc/gnome-remote-desktop '' gnome-remote-desktop gnome-remote-desktop
CopyFile /etc/sane.d/dll.conf
CreateLink /etc/systemd/system/dbus-org.freedesktop.Avahi.service /usr/lib/systemd/system/avahi-daemon.service
CreateLink /etc/systemd/system/display-manager.service /usr/lib/systemd/system/gdm.service
CreateLink /etc/systemd/system/multi-user.target.wants/avahi-daemon.service /usr/lib/systemd/system/avahi-daemon.service
CreateLink /etc/systemd/system/multi-user.target.wants/cups.path /usr/lib/systemd/system/cups.path
CreateLink /etc/systemd/system/multi-user.target.wants/dropbox@fschenkel.service /usr/lib/systemd/system/dropbox@.service
CreateLink /etc/systemd/system/printer.target.wants/cups.service /usr/lib/systemd/system/cups.service
CreateLink /etc/systemd/system/sockets.target.wants/avahi-daemon.socket /usr/lib/systemd/system/avahi-daemon.socket
CreateLink /etc/systemd/system/sockets.target.wants/cups.socket /usr/lib/systemd/system/cups.socket
CreateLink /etc/systemd/user/graphical-session-pre.target.wants/xdg-user-dirs.service /usr/lib/systemd/user/xdg-user-dirs.service
CreateLink /etc/systemd/user/pipewire-session-manager.service /usr/lib/systemd/user/wireplumber.service
CreateLink /etc/systemd/user/pipewire.service.wants/wireplumber.service /usr/lib/systemd/user/wireplumber.service
CreateLink /etc/systemd/user/sockets.target.wants/gcr-ssh-agent.socket /usr/lib/systemd/user/gcr-ssh-agent.socket
CreateLink /etc/systemd/user/sockets.target.wants/gnome-keyring-daemon.socket /usr/lib/systemd/user/gnome-keyring-daemon.socket
CreateLink /etc/systemd/user/sockets.target.wants/p11-kit-server.socket /usr/lib/systemd/user/p11-kit-server.socket
CreateLink /etc/systemd/user/sockets.target.wants/pipewire-pulse.socket /usr/lib/systemd/user/pipewire-pulse.socket
CreateLink /etc/systemd/user/sockets.target.wants/pipewire.socket /usr/lib/systemd/user/pipewire.socket
CreateLink /etc/systemd/user/sockets.target.wants/speech-dispatcher.socket /usr/lib/systemd/user/speech-dispatcher.socket
CopyFile /etc/udev/rules.d/40-libsane.rules 755
CopyFile /etc/udev/rules.d/89-uinput-u.rules
CopyFile /etc/udev/rules.d/S99-2000S1.rules 755
CopyFile /usr/share/sounds/gnome/default/alerts/bark.ogg
