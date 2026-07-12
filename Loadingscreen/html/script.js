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
    const mediaToggle = byId('mediaToggle');
    const mediaIcon = byId('mediaIcon');
    const mediaText = byId('mediaText');
    const progressFill = byId('progressFill');
    const progressPercent = byId('progressPercent');
    const loadingStatus = byId('loadingStatus');
    const progressTrack = document.querySelector('.progress-track');
    const playerProfile = byId('playerProfile');
    const profileAvatar = byId('profileAvatar');
    const profileInitial = byId('profileInitial');
    const profileName = byId('profileName');
    const profileUsername = byId('profileUsername');
    const profileStatus = byId('profileStatus');
    const profileStatusDot = byId('profileStatusDot');

    const ICONS = window.ICON_LIBRARY || {};

    const PROFILE_STATUS_CLASSES = ['is-idle', 'is-dnd', 'is-offline', 'is-loading', 'is-connecting'];

    const LANYARD_STATUS_LABELS = {
        online: 'Online',
        idle: 'Abwesend',
        dnd: 'Bitte nicht stören',
        offline: 'Offline'
    };

    let activeProfile = null;
    let lanyardPollTimer = null;

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
        mediaMode: 'video',
        slideshowIntervalId: null
    };

    function getMediaStorageKey() {
        return typeof cfg.mediaStorageKey === 'string' && cfg.mediaStorageKey.trim() !== ''
            ? cfg.mediaStorageKey.trim()
            : 'loadingscreen_media_mode';
    }

    function getBackgroundImages() {
        const imagesFromArray = Array.isArray(cfg.backgroundImages) ? cfg.backgroundImages : [];
        return imagesFromArray
            .concat(typeof cfg.backgroundImage === 'string' ? [cfg.backgroundImage] : [])
            .filter((src, index, arr) => typeof src === 'string' && src.trim() !== '' && arr.indexOf(src) === index);
    }

    function hasVideoBackground() {
        return typeof cfg.backgroundVideo === 'string' && cfg.backgroundVideo.trim() !== '';
    }

    function hasImageBackground() {
        return getBackgroundImages().length > 0;
    }

    function normalizeMediaMode(mode) {
        return String(mode || '').toLowerCase() === 'images' ? 'images' : 'video';
    }

    function loadSavedMediaMode() {
        const fallback = normalizeMediaMode(cfg.mediaMode || 'video');

        try {
            const saved = localStorage.getItem(getMediaStorageKey());
            if (saved === 'video' || saved === 'images') {
                return saved;
            }
        } catch {
            // localStorage in CEF manchmal blockiert – Fallback nutzen
        }

        return fallback;
    }

    function saveMediaMode(mode) {
        try {
            localStorage.setItem(getMediaStorageKey(), mode);
        } catch {
            // Speichern optional – Modus gilt trotzdem fuer diese Session
        }
    }

    function resolveMediaMode(mode) {
        let resolved = normalizeMediaMode(mode);

        if (resolved === 'video' && !hasVideoBackground() && hasImageBackground()) {
            resolved = 'images';
        }

        if (resolved === 'images' && !hasImageBackground() && hasVideoBackground()) {
            resolved = 'video';
        }

        return resolved;
    }

    function canSwitchMedia() {
        if (cfg.allowMediaSwitch === false) {
            return false;
        }

        return hasVideoBackground() && hasImageBackground();
    }

    state.mediaMode = resolveMediaMode(loadSavedMediaMode());

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

    function updateMediaUI() {
        if (!mediaToggle) return;

        mediaToggle.setAttribute('data-mode', state.mediaMode);
        setIcon(
            mediaIcon,
            state.mediaMode === 'images' ? (cfg.mediaImagesIcon || 'image') : (cfg.mediaVideoIcon || 'video'),
            state.mediaMode === 'images' ? 'image' : 'video'
        );

        const label = state.mediaMode === 'images'
            ? (cfg.mediaImagesLabel || 'Bilder')
            : (cfg.mediaVideoLabel || 'Video');

        setText(mediaText, label);
        mediaToggle.setAttribute(
            'title',
            state.mediaMode === 'images'
                ? 'Zu Video-Hintergrund wechseln'
                : 'Zu Bild-Hintergrund wechseln'
        );
    }

    function resetBackgroundMedia() {
        if (state.slideshowIntervalId) {
            window.clearInterval(state.slideshowIntervalId);
            state.slideshowIntervalId = null;
        }

        if (bgVideo) {
            bgVideo.pause();
            bgVideo.removeAttribute('src');
            if (typeof bgVideo.load === 'function') {
                bgVideo.load();
            }
            hideElement(bgVideo);
        }

        if (bgAudio) {
            bgAudio.pause();
            bgAudio.removeAttribute('src');
            if (typeof bgAudio.load === 'function') {
                bgAudio.load();
            }
            hideElement(bgAudio);
        }

        [bgImageA, bgImageB].forEach((layer) => {
            if (!layer) return;
            layer.classList.remove('is-active');
            layer.style.backgroundImage = '';
            hideElement(layer);
        });

        state.soundElement = null;
    }

    function setMediaMode(mode, persist) {
        const nextMode = resolveMediaMode(mode);
        state.mediaMode = nextMode;

        if (persist !== false) {
            saveMediaMode(nextMode);
        }

        resetBackgroundMedia();
        setupBackground();
        updateMediaUI();
        updateSoundUI();
    }

    function toggleMediaMode() {
        const nextMode = state.mediaMode === 'images' ? 'video' : 'images';
        setMediaMode(nextMode, true);
    }

    function toggleSound() {
        state.muted = !state.muted;
        updateSoundUI();

        if (!state.muted) {
            ensureSoundPlayback();
        }
    }

    function setupVideo() {
        if (!bgVideo || !hasVideoBackground()) return;

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

        const images = getBackgroundImages();
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
            state.slideshowIntervalId = window.setInterval(() => {
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

    function resolveStatusLabel(status) {
        const normalized = String(status || 'connecting').toLowerCase();
        return LANYARD_STATUS_LABELS[normalized]
            || (normalized === 'loading' ? 'Status wird geladen...' : 'Verbindet...');
    }

    async function fetchLanyardStatus(discordId) {
        if (!discordId) {
            return null;
        }

        try {
            const response = await fetch(`https://api.lanyard.rest/v1/users/${discordId}`);
            if (!response.ok) {
                return null;
            }

            const payload = await response.json();
            if (!payload || !payload.success || !payload.data) {
                return null;
            }

            const status = payload.data.discord_status || 'offline';
            return {
                discordStatus: status,
                statusLabel: resolveStatusLabel(status)
            };
        } catch {
            return null;
        }
    }

    function shouldFetchLanyardStatus(profile) {
        if (cfg.useLanyard === false || !profile || !profile.discordId) {
            return false;
        }

        const status = String(profile.discordStatus || '').toLowerCase();
        return !LANYARD_STATUS_LABELS[status];
    }

    function scheduleLanyardStatusRefresh(profile) {
        if (!shouldFetchLanyardStatus(profile)) {
            return;
        }

        if (lanyardPollTimer) {
            window.clearInterval(lanyardPollTimer);
            lanyardPollTimer = null;
        }

        const pollMs = Number.isFinite(cfg.lanyardPollMs) ? Math.max(3000, cfg.lanyardPollMs) : 8000;

        const refresh = async () => {
            const statusData = await fetchLanyardStatus(profile.discordId);
            if (!statusData || !activeProfile || activeProfile.discordId !== profile.discordId) {
                return;
            }

            if (lanyardPollTimer) {
                window.clearInterval(lanyardPollTimer);
                lanyardPollTimer = null;
            }

            renderPlayerProfile({
                ...activeProfile,
                discordStatus: statusData.discordStatus,
                statusLabel: statusData.statusLabel,
                isOnline: statusData.discordStatus !== 'offline'
            }, { skipLanyard: true });
        };

        refresh();
        lanyardPollTimer = window.setInterval(refresh, pollMs);
    }

    function shouldShowProfile(profile) {
        if (!profile || typeof profile !== 'object') {
            return false;
        }

        return !!(profile.displayName || profile.name || profile.discordId || profile.discordUsername || profile.username);
    }

    function setProfileInitial(displayName) {
        if (!profileInitial) return;

        const letter = String(displayName || '?').trim().charAt(0).toUpperCase() || '?';
        profileInitial.textContent = letter;
    }

    function renderPlayerProfile(profile, options) {
        options = options || {};

        if (!playerProfile || cfg.showPlayerProfile === false) {
            hideElement(playerProfile);
            if (playerProfile) playerProfile.hidden = true;
            return;
        }

        if (!shouldShowProfile(profile)) {
            hideElement(playerProfile);
            if (playerProfile) playerProfile.hidden = true;
            return;
        }

        const displayName = profile.displayName || profile.name || 'Spieler';
        const username = profile.discordUsername || profile.username || '';
        const status = profile.discordStatus || 'connecting';
        const statusLabel = profile.statusLabel || resolveStatusLabel(status);
        const avatarSrc = profile.avatar || profile.avatarUrl || '';

        setText(profileName, displayName);
        setProfileInitial(displayName);

        if (profileUsername) {
            if (username) {
                const handle = username.startsWith('@') ? username : `@${username}`;
                setText(profileUsername, handle);
                profileUsername.hidden = false;
            } else {
                profileUsername.hidden = true;
            }
        }

        const avatarWrap = profileAvatar ? profileAvatar.closest('.player-avatar-wrap') : null;

        if (profileAvatar) {
            profileAvatar.alt = '';
            profileAvatar.classList.remove('is-fallback');

            if (typeof avatarSrc === 'string' && avatarSrc.trim() !== '') {
                profileAvatar.onerror = () => {
                    profileAvatar.removeAttribute('src');
                    profileAvatar.classList.add('is-fallback');
                    if (avatarWrap) avatarWrap.classList.remove('has-avatar');
                };
                profileAvatar.onload = () => {
                    if (avatarWrap) avatarWrap.classList.add('has-avatar');
                };
                profileAvatar.src = avatarSrc;
            } else {
                profileAvatar.removeAttribute('src');
                profileAvatar.classList.add('is-fallback');
                if (avatarWrap) avatarWrap.classList.remove('has-avatar');
            }
        }

        applyProfileStatus(status);
        setText(profileStatus, statusLabel);

        playerProfile.hidden = false;
        showElement(playerProfile, 'block');

        activeProfile = { ...profile, displayName, discordStatus: status, statusLabel };

        if (!options.skipLanyard) {
            scheduleLanyardStatusRefresh(activeProfile);
        }
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
    updateMediaUI();
    setupBackground();

    if (mediaToggle) {
        if (canSwitchMedia()) {
            mediaToggle.hidden = false;
            mediaToggle.addEventListener('click', toggleMediaMode);
        } else {
            mediaToggle.hidden = true;
        }
    }

    const handoverProfile = readHandoverProfile();
    if (handoverProfile) {
        renderPlayerProfile(handoverProfile);
    }
})();
