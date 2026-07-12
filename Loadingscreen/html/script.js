(() => {
    const cfg = window.LOADING_CONFIG || {};

    const byId = (id) => document.getElementById(id);
    const titleWhite = byId('titleWhite');
    const titleYellow = byId('titleYellow');
    const subtitle = byId('subtitle');
    const brandLabel = byId('brandLabel');
    const infoIcon = byId('infoIcon');
    const infoTitle = byId('infoTitle');
    const infoText = byId('infoText');
    const bgVideo = byId('bgVideo');
    const bgAudio = byId('bgAudio');
    const bgImageA = byId('bgImageA');
    const bgImageB = byId('bgImageB');
    const soundToggle = byId('soundToggle');
    const soundIcon = byId('soundIcon');
    const soundText = byId('soundText');
    const progressFill = byId('progressFill');
    const progressPercent = byId('progressPercent');
    const loadingStatus = byId('loadingStatus');
    const progressTrack = document.querySelector('.progress-track');
    const playerProfile = byId('playerProfile');
    const profileAvatar = byId('profileAvatar');
    const profileName = byId('profileName');
    const profileUsername = byId('profileUsername');
    const profileStatus = byId('profileStatus');
    const profileStatusDot = byId('profileStatusDot');

    const ICONS = window.ICON_LIBRARY || {};

    const PROFILE_STATUS_CLASSES = ['is-idle', 'is-dnd', 'is-offline', 'is-loading', 'is-connecting'];

    const LOADING_PHASES = [
        { until: 25, text: 'Verbindung wird hergestellt' },
        { until: 55, text: 'Ressourcen werden geladen' },
        { until: 85, text: 'Welt wird vorbereitet' },
        { until: 100, text: 'Fast geschafft' }
    ];

    const state = {
        progress: Number.isFinite(cfg.previewPercent) ? cfg.previewPercent : 68,
        gotFiveMProgress: false,
        muted: !!cfg.startMuted,
        soundElement: null,
        mediaMode: String(cfg.mediaMode || 'video').toLowerCase() === 'images' ? 'images' : 'video'
    };

    function setText(el, value) {
        if (el && typeof value === 'string') el.textContent = value;
    }

    function setIcon(el, iconName, fallbackName) {
        if (!el) return;
        const safeIcon = ICONS[iconName] ? iconName : fallbackName;
        el.innerHTML = ICONS[safeIcon] || ICONS.info;
    }

    function showElement(el, displayValue = 'block') {
        if (el) el.style.display = displayValue;
    }

    function hideElement(el) {
        if (el) el.style.display = 'none';
    }

    function resolveLoadingStatus(percent) {
        const customPhases = Array.isArray(cfg.loadingPhases) ? cfg.loadingPhases : null;

        if (customPhases) {
            for (const phase of customPhases) {
                if (percent <= phase.until) return phase.text;
            }
            return customPhases[customPhases.length - 1]?.text || 'Wird geladen';
        }

        for (const phase of LOADING_PHASES) {
            if (percent <= phase.until) return phase.text;
        }

        return 'Fast geschafft';
    }

    setText(titleWhite, cfg.serverTitleWhite || 'OSNABRÜCK');
    setText(titleYellow, cfg.serverTitleYellow || 'ROLEPLAY');
    setText(subtitle, cfg.subtitle || 'Willkommen in deiner neuen Heimat.');
    setText(brandLabel, cfg.brandLabel || 'Roleplay Server');
    setIcon(infoIcon, cfg.infoIcon || cfg.infoEmoji, 'video');
    setText(infoTitle, cfg.infoTitle || 'Wichtige Information');
    setText(infoText, cfg.infoText || 'Um im Supportfall schnelle und korrekte Entscheidungen treffen zu können, empfehlen wir euch, passende Videobeweise (Clips) für mögliche Supportgespräche bereitzuhalten.');

    function updateSoundUI() {
        if (state.soundElement) state.soundElement.muted = state.muted;
        if (soundToggle) soundToggle.setAttribute('data-muted', String(state.muted));
        setIcon(soundIcon, state.muted ? (cfg.musicStoppedIcon || cfg.musicStoppedEmoji) : (cfg.musicPlayingIcon || cfg.musicPlayingEmoji), state.muted ? 'volume-off' : 'volume-high');

        if (soundText) {
            soundText.innerHTML = state.muted
                ? '<b>[LEERTASTE]</b> Musik starten'
                : '<b>[LEERTASTE]</b> Musik stoppen';
        }
    }

    function tryPlay(mediaElement, onBlocked) {
        if (!mediaElement || typeof mediaElement.play !== 'function') return;

        const playPromise = mediaElement.play();
        if (playPromise && typeof playPromise.catch === 'function') {
            playPromise.catch(() => {
                if (typeof onBlocked === 'function') onBlocked();
            });
        }
    }

    function ensureSoundPlayback() {
        if (!state.soundElement) return;
        state.soundElement.muted = state.muted;
        tryPlay(state.soundElement, () => {
            state.muted = true;
            updateSoundUI();
        });
    }

    function toggleSound() {
        state.muted = !state.muted;
        updateSoundUI();

        if (!state.muted) {
            ensureSoundPlayback();
        }
    }

    function setupVideo() {
        if (!bgVideo || !cfg.backgroundVideo) return;

        hideElement(bgImageA);
        hideElement(bgImageB);
        hideElement(bgAudio);

        state.soundElement = bgVideo;
        bgVideo.muted = state.muted;
        bgVideo.src = cfg.backgroundVideo;
        showElement(bgVideo);

        bgVideo.addEventListener('canplay', () => {
            showElement(bgVideo);
        }, { once: true });

        bgVideo.addEventListener('error', () => {
            hideElement(bgVideo);
        });

        tryPlay(bgVideo, () => {
            state.muted = true;
            updateSoundUI();
            bgVideo.muted = true;
            tryPlay(bgVideo, () => hideElement(bgVideo));
        });
    }

    function setupImageSlideshow() {
        const imageLayers = [bgImageA, bgImageB].filter(Boolean);
        if (imageLayers.length === 0) return;

        hideElement(bgVideo);

        const imagesFromArray = Array.isArray(cfg.backgroundImages) ? cfg.backgroundImages : [];
        const images = imagesFromArray
            .concat(typeof cfg.backgroundImage === 'string' ? [cfg.backgroundImage] : [])
            .filter((src, index, arr) => typeof src === 'string' && src.trim() !== '' && arr.indexOf(src) === index);

        if (images.length === 0) return;

        const fadeMs = Number.isFinite(cfg.slideshowFadeMs) ? Math.max(0, cfg.slideshowFadeMs) : 800;
        const intervalMs = Number.isFinite(cfg.slideshowInterval) ? Math.max(1000, cfg.slideshowInterval) : 5000;

        document.documentElement.style.setProperty('--slideshow-fade-duration', `${fadeMs}ms`);

        imageLayers.forEach((layer) => {
            showElement(layer);
            layer.classList.remove('is-active');
        });

        let imageIndex = 0;
        let activeLayerIndex = 0;

        imageLayers[activeLayerIndex].style.backgroundImage = `url("${images[imageIndex]}")`;
        imageLayers[activeLayerIndex].classList.add('is-active');

        images.forEach((src) => {
            const preload = new Image();
            preload.src = src;
        });

        if (images.length > 1) {
            window.setInterval(() => {
                const nextLayerIndex = activeLayerIndex === 0 ? 1 : 0;
                imageIndex = (imageIndex + 1) % images.length;

                imageLayers[nextLayerIndex].style.backgroundImage = `url("${images[imageIndex]}")`;
                imageLayers[nextLayerIndex].classList.add('is-active');
                imageLayers[activeLayerIndex].classList.remove('is-active');

                activeLayerIndex = nextLayerIndex;
            }, intervalMs);
        }

        if (bgAudio && typeof cfg.backgroundAudio === 'string' && cfg.backgroundAudio.trim() !== '') {
            state.soundElement = bgAudio;
            bgAudio.muted = state.muted;
            bgAudio.src = cfg.backgroundAudio;
            tryPlay(bgAudio, () => {
                state.muted = true;
                updateSoundUI();
            });
        } else {
            state.soundElement = null;
        }
    }

    function setupBackground() {
        if (state.mediaMode === 'images') {
            setupImageSlideshow();
        } else {
            setupVideo();
        }
    }

    function setProgress(percent) {
        const safePercent = Math.max(0, Math.min(100, Math.round(percent)));
        state.progress = safePercent;

        if (progressFill) progressFill.style.width = `${safePercent}%`;
        if (progressPercent) progressPercent.textContent = `${safePercent}%`;
        if (loadingStatus) loadingStatus.textContent = resolveLoadingStatus(safePercent);
        if (progressTrack) progressTrack.setAttribute('aria-valuenow', String(safePercent));
    }

    function normalizeMessageData(rawData) {
        let data = rawData;

        if (typeof data === 'string') {
            try {
                data = JSON.parse(data);
            } catch {
                return null;
            }
        }

        return data && typeof data === 'object' ? data : null;
    }

    function applyProfileStatus(status) {
        const normalized = String(status || 'connecting').toLowerCase();

        if (profileStatusDot) {
            profileStatusDot.className = 'player-status-dot';
            if (normalized !== 'online') {
                profileStatusDot.classList.add(`is-${normalized}`);
            }
        }

        if (profileStatus) {
            profileStatus.className = 'player-status-label';
            PROFILE_STATUS_CLASSES.forEach((className) => profileStatus.classList.remove(className));
            if (normalized !== 'online') {
                profileStatus.classList.add(`is-${normalized}`);
            }
        }
    }

    function renderPlayerProfile(profile) {
        if (!playerProfile || cfg.showPlayerProfile === false) {
            hideElement(playerProfile);
            if (playerProfile) playerProfile.hidden = true;
            return;
        }

        if (!isRealPlayerProfile(profile)) {
            hideElement(playerProfile);
            if (playerProfile) playerProfile.hidden = true;
            return;
        }

        const displayName = profile.displayName || profile.name || 'Spieler';
        const username = profile.discordUsername || profile.username || '';
        const status = profile.discordStatus || 'connecting';
        const statusLabel = profile.statusLabel || 'Verbindet...';
        const avatarSrc = profile.avatar || profile.avatarUrl || '';

        setText(profileName, displayName);

        if (profileUsername) {
            if (username) {
                const handle = username.startsWith('@') ? username : `@${username}`;
                setText(profileUsername, handle);
                profileUsername.hidden = false;
            } else {
                profileUsername.hidden = true;
            }
        }

        if (profileAvatar) {
            profileAvatar.alt = '';
            profileAvatar.classList.remove('is-fallback');

            if (typeof avatarSrc === 'string' && avatarSrc.trim() !== '') {
                profileAvatar.onerror = () => {
                    profileAvatar.removeAttribute('src');
                    profileAvatar.classList.add('is-fallback');
                };
                profileAvatar.src = avatarSrc;
            } else {
                profileAvatar.removeAttribute('src');
                profileAvatar.classList.add('is-fallback');
            }
        }

        applyProfileStatus(status);
        setText(profileStatus, statusLabel);

        playerProfile.hidden = false;
        showElement(playerProfile, 'block');
    }

    function isInFiveM() {
        if (typeof window.invokeNative === 'function') {
            return true;
        }

        const handover = window.nuiHandoverData;
        return !!(handover && typeof handover.serverAddress === 'string');
    }

    function isRealPlayerProfile(profile) {
        if (!profile || typeof profile !== 'object') {
            return false;
        }

        return !!(profile.discordId || profile.discordUsername || profile.username);
    }

    function readHandoverProfile() {
        const handover = window.nuiHandoverData;
        if (handover && handover.playerProfile && typeof handover.playerProfile === 'object') {
            return handover.playerProfile;
        }
        return null;
    }

    window.addEventListener('message', (event) => {
        const data = normalizeMessageData(event.data);
        if (!data) return;

        if (data.eventName === 'loadProgress' && typeof data.loadFraction === 'number') {
            state.gotFiveMProgress = true;
            setProgress(data.loadFraction * 100);
        }

        if (data.eventName === 'playerProfile' && data.profile) {
            renderPlayerProfile(data.profile);
        }
    });

    setProgress(state.progress);
    const fakeProgress = window.setInterval(() => {
        if (state.gotFiveMProgress) {
            window.clearInterval(fakeProgress);
            return;
        }

        if (state.progress < 99) {
            const step = Math.random() * 0.38;
            setProgress(state.progress + step);
        }
    }, 900);

    document.addEventListener('keydown', (event) => {
        if (event.code === 'Space') {
            event.preventDefault();
            if (!event.repeat) toggleSound();
        }
    });

    updateSoundUI();
    setupBackground();

    const handoverProfile = readHandoverProfile();
    if (handoverProfile) {
        renderPlayerProfile(handoverProfile);
    }
})();
