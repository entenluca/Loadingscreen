// Hier kannst du den LoadingScreen schnell anpassen.
//
// Hintergrund-Modus:
// - mediaMode: 'video'  = MP4-Video aus backgroundVideo verwenden
// - mediaMode: 'images' = PNG-Bilder aus backgroundImages als Slideshow verwenden
//
// MP4-Hintergrund: Lege deine Datei als html/assets/background.mp4 ab.
// PNG-Slideshow: Lege deine Bilder z. B. als html/assets/slide-1.png, slide-2.png ... ab.
window.LOADING_CONFIG = {
    accentColor: '#5b9cff',

    welcomeTitle: 'WELCOME TO MINDENRP',
    welcomeText: 'Willkommen auf unserem Roleplay-Server. Lies die Regeln und bleib auf dem Laufenden.',

    serverTitleWhite: 'LOADING',
    serverTitleYellow: 'SCREEN',
    centerTitle: ['LOADING', 'SCREEN'],
    subtitle: 'Willkommen in deiner neuen Heimat.',

    serverRules: [
        { title: 'Rule #1', text: 'Respektiere alle Spieler und das Roleplay aller Beteiligten.' },
        { title: 'Rule #2', text: 'Kein RDM, VDM oder Fail-RP. Halte dich an die Serverregeln.' },
        { title: 'Rule #3', text: 'Nutze den Support nur mit passenden Videobeweisen (Clips).' }
    ],

    serverUpdates: [
        {
            date: '19.11 23:28',
            title: 'Name of update',
            text: 'Kurze Beschreibung des Updates oder Changelogs.',
            avatar: ''
        },
        {
            date: '18.11 14:02',
            title: 'Neue Fahrzeuge',
            text: 'Mehrere neue Fahrzeuge wurden dem Händler hinzugefügt.',
            avatar: ''
        }
    ],

    galleryImages: [
        'assets/slide-1.png',
        'assets/slide-2.png',
        'assets/slide-3.png',
        'assets/slide-1.png',
        'assets/slide-2.png',
        'assets/slide-3.png'
    ],

    teamMembers: [
        {
            name: 'SOURCE INSENSITIVE',
            role: 'Owner',
            discord: 'discord.gg/sourceui',
            avatar: ''
        },
        {
            name: 'ADMIN NAME',
            role: 'Admin',
            discord: 'discord.gg/sourceui',
            avatar: ''
        }
    ],

    music: {
        title: 'SLAY!',
        artist: 'ETERNXLKZ'
    },

    socials: [
        { label: 'Discord', url: 'https://discord.gg/' },
        { label: 'Discord', url: 'https://discord.gg/' },
        { label: 'Discord', url: 'https://discord.gg/' },
        { label: 'Discord', url: 'https://discord.gg/' },
        { label: 'Discord', url: 'https://discord.gg/' },
        { label: 'Discord', url: 'https://discord.gg/' }
    ],

    // Optional: Lade-Phasen fuer die Statusanzeige (until = Prozent bis einschliesslich)
    // loadingPhases: [
    //     { until: 25, text: 'Verbindung wird hergestellt...' },
    //     { until: 55, text: 'Ressourcen werden geladen...' },
    //     { until: 85, text: 'Welt wird vorbereitet...' },
    //     { until: 100, text: 'Es ist nicht mehr viel uebrig, bitte warten.....' }
    // ],

    // 'video' oder 'images'
    mediaMode: 'video',

    // Video-Modus
    backgroundVideo: 'assets/background.mp4',

    // Bilder-Modus / Slideshow. Nur PNG-Dateien eintragen, wenn mediaMode: 'images' aktiv ist.
    backgroundImages: [
        'assets/slide-1.png',
        'assets/slide-2.png',
        'assets/slide-3.png'
    ],
    slideshowInterval: 5000,
    slideshowFadeMs: 800,

    // Optional: Separate Musikdatei für den Bilder-Modus, z. B. 'assets/music.mp3'.
    // Wenn leer, gibt es im Bilder-Modus keine separate Musikquelle.
    backgroundAudio: '',

    // Icons: verfuegbare Namen (siehe html/icons.js, Icon-Bibliothek auf Basis von Lucide,
    // lokal gebuendelt, kein Internet noetig):
    // alert-circle, alert-triangle, bell, book-open, calendar, check-circle, chevron-down,
    // circle-check, circle-x, clock, download, flag, gamepad-2, gauge, gift, globe, hammer,
    // headphones, heart, image, info, lock, map-pin, megaphone, message-circle, music,
    // newspaper, party-popper, play, rocket, server, settings, shield, shield-check,
    // sparkles, star, trophy, tv, unlock, users, video, volume-high, volume-off, wifi,
    // wrench, zap
    infoIcon: 'video',
    musicPlayingIcon: 'volume-high',
    musicStoppedIcon: 'volume-off',

    infoTitle: 'Wichtige Information',
    infoText: 'Um im Supportfall schnelle und korrekte Entscheidungen treffen zu können, empfehlen wir euch, passende Videobeweise (Clips) für mögliche Supportgespräche bereitzuhalten.',

    // false = Musik startet mit Ton, sofern FiveM/CEF Autoplay mit Ton zulässt.
    // Mit der Leertaste wird ab sofort zwischen stumm und aktiv umgeschaltet.
    startMuted: false,

    // Nur für Browser-Vorschau. FiveM überschreibt den Wert per loadProgress Event.
    previewPercent: 98
};
