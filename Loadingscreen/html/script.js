(() => {
    const cfg = window.LOADING_CONFIG || {};

    const byId = (id) => document.getElementById(id);
    const titleWhite = byId('titleWhite');
    const titleYellow = byId('titleYellow');
    const subtitle = byId('subtitle');
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

    // Icons kommen jetzt aus der ausgelagerten, lokal gebuendelten Icon-Bibliothek
    // (icons.js, muss in index.html VOR script.js eingebunden sein).
    const ICONS = window.ICON_LIBRARY || {};

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

    setText(titleWhite, cfg.serverTitleWhite || 'OSNABRÜCK');
    setText(titleYellow, cfg.serverTitleYellow || 'ROLEPLAY');
    setText(subtitle, cfg.subtitle || 'Willkommen in deiner neuen Heimat.');
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
            // Falls Autoplay mit Ton blockiert wird, läuft das Video stumm weiter.
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
    }

    // FiveM sendet während des Ladens Message Events an den LoadingScreen.
    window.addEventListener('message', (event) => {
        const data = event.data || {};

        if (data.eventName === 'loadProgress' && typeof data.loadFraction === 'number') {
            state.gotFiveMProgress = true;
            setProgress(data.loadFraction * 100);
        }
    });

    // Browser-Vorschau / Fallback, falls keine FiveM-Progress-Events ankommen.
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

    // Leertaste funktioniert als Umschalter: Ton an <-> stumm.
    document.addEventListener('keydown', (event) => {
        if (event.code === 'Space') {
            event.preventDefault();
            if (!event.repeat) toggleSound();
        }
    });

    updateSoundUI();
    setupBackground();
})();
