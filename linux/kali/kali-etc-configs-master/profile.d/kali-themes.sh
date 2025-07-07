# Kali Themes customizations

if [ -z "$QT_QPA_PLATFORMTHEME" ] && [ "$XDG_CURRENT_DESKTOP" != "KDE" ]; then
    export QT_QPA_PLATFORMTHEME=qt5ct
    export QT_AUTO_SCREEN_SCALE_FACTOR=0
fi
