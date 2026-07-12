(() => {
    const ICONS = window.ICON_LIBRARY || {};

    function mergeConfig(base, override) {
        const result = { ...base };

        if (!override || typeof override !== 'object') {
            return result;
        }

        Object.keys(override).forEach((key) => {
            const value = override[key];
            if (value === undefined || value === null) return;

            if (
                typeof value === 'object' &&
                !Array.isArray(value) &&
                typeof base[key] === 'object' &&
                !Array.isArray(base[key])
            ) {
                result[key] = { ...base[key], ...value };
            } else {
                result[key] = value;
            }
        });

        return result;
    }

    async function loadRuntimeConfig() {
        const defaults = window.LOADING_CONFIG || {};

        try {
            const response = await fetch(`runtime-config.json?ts=${Date.now()}`);
            if (!response.ok) return defaults;

            const runtime = await response.json();
            if (!runtime || typeof runtime !== 'object' || Object.keys(runtime).length === 0) {
                return defaults;
            }

            return mergeConfig(defaults, runtime);
        } catch (_) {
            return defaults;
        }
    }

    async function bootstrap() {
    const cfg = await loadRuntimeConfig();

    const byId = (id) => document.getElementById(id);
    const bgVideo = byId('bgVideo');
    const bgAudio = byId('bgAudio');
    const bgImageA = byId('bgImageA');
    const bgImageB = byId('bgImageB');
    const soundIcon = byId('soundIcon');
    const soundText = byId('soundText');
    const progressFill = byId('progressFill');
    const progressPercent = byId('progressPercent');
    const loadingStatus = byId('loadingStatus');
    const progressTrack = document.querySelector('.progress-track');
    const volumeFill = () => document.querySelector('.volume-fill');
    const musicVisualizer = () => document.querySelector('.music-visualizer');

    const LOADING_PHASES = [
        { until: 25, text: 'Verbindung wird hergestellt...' },
        { until: 55, text: 'Ressourcen werden geladen...' },
        { until: 85, text: 'Welt wird vorbereitet...' },
        { until: 100, text: 'Es ist nicht mehr viel übrig, bitte warten.....' }
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

    function escapeHtml(value) {
        return String(value)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }

    function applyTheme() {
        if (typeof cfg.accentColor === 'string' && cfg.accentColor.trim()) {
            document.documentElement.style.setProperty('--accent', cfg.accentColor.trim());
        }
    }

    function resolveLoadingStatus(percent) {
        const customPhases = Array.isArray(cfg.loadingPhases) ? cfg.loadingPhases : null;

        if (customPhases) {
            for (const phase of customPhases) {
                if (percent <= phase.until) return phase.text;
            }
            return customPhases[customPhases.length - 1]?.text || 'Wird geladen...';
        }

        for (const phase of LOADING_PHASES) {
            if (percent <= phase.until) return phase.text;
        }

        return 'Fast geschafft...';
    }

    function renderAvatar(item, fallbackName) {
        const name = item?.name || fallbackName || '?';
        const initial = escapeHtml(name.charAt(0).toUpperCase());

        if (typeof item?.avatar === 'string' && item.avatar.trim()) {
            return `<div class="avatar"><img src="${escapeHtml(item.avatar)}" alt="" /></div>`;
        }

        return `<div class="avatar" aria-hidden="true">${initial}</div>`;
    }

    function createWidget(title, bodyHtml, options = {}) {
        const widget = document.createElement('div');
        widget.className = 'widget';

        if (options.open !== false) widget.classList.add('is-open');
        if (options.static) widget.classList.add('widget-static');

        widget.innerHTML = `
            <button type="button" class="widget-header">
                <span>${escapeHtml(title)}</span>
                <span class="chevron icon">${ICONS['chevron-down'] || ''}</span>
            </button>
            <div class="widget-body">${bodyHtml}</div>
        `;

        if (!options.static) {
            widget.querySelector('.widget-header').addEventListener('click', () => {
                widget.classList.toggle('is-open');
            });
        }

        return widget;
    }

    function renderRules() {
        const container = byId('rulesWidget');
        if (!container) return;

        const rules = Array.isArray(cfg.serverRules) ? cfg.serverRules : [];
        if (rules.length === 0) {
            container.remove();
            return;
        }

        const body = rules.map((rule, index) => `
            <div class="rule-item">
                <strong>${escapeHtml(rule.title || `Rule #${index + 1}`)}</strong>
                <p>${escapeHtml(rule.text || '')}</p>
            </div>
        `).join('');

        container.replaceWith(createWidget('Server Rules', body, { open: true }));
    }

    function renderUpdates() {
        const container = byId('updatesWidget');
        if (!container) return;

        const updates = Array.isArray(cfg.serverUpdates) ? cfg.serverUpdates : [];
        if (updates.length === 0) {
            container.remove();
            return;
        }

        const body = updates.map((update) => `
            <div class="update-item">
                ${renderAvatar(update, 'Update')}
                <div class="update-meta">
                    <span class="update-date">${escapeHtml(update.date || '')}</span>
                    <span class="update-title">${escapeHtml(update.title || 'Update')}</span>
                    <p class="update-text">${escapeHtml(update.text || '')}</p>
                </div>
            </div>
        `).join('');

        container.replaceWith(createWidget('Server Update', body, { open: true }));
    }

    function renderGallery() {
        const container = byId('galleryWidget');
        if (!container) return;

        const images = Array.isArray(cfg.galleryImages) ? cfg.galleryImages.filter(Boolean) : [];
        if (images.length === 0) {
            container.remove();
            return;
        }

        const body = `
            <div class="gallery-grid">
                ${images.map((src) => `<div class="gallery-item" style="background-image:url('${escapeHtml(src)}')"></div>`).join('')}
            </div>
        `;

        container.replaceWith(createWidget('Server Gallery', body, { open: true }));
    }

    function renderTeam() {
        const container = byId('teamWidget');
        if (!container) return;

        const members = Array.isArray(cfg.teamMembers) ? cfg.teamMembers : [];
        if (members.length === 0) {
            container.remove();
            return;
        }

        const body = members.map((member) => `
            <div class="team-item">
                ${renderAvatar(member, 'Team')}
                <div class="team-info">
                    <span class="team-role">${escapeHtml(member.role || 'Team')}</span>
                    <span class="team-name">${escapeHtml(member.name || 'Unbekannt')}</span>
                    <span class="team-discord">${escapeHtml(member.discord || '')}</span>
                </div>
            </div>
        `).join('');

        container.replaceWith(createWidget('Authorized Teams', body, { open: true }));
    }

    function renderMusic() {
        const container = byId('musicWidget');
        if (!container) return;

        const music = cfg.music || {};
        const body = `
            <div class="music-body">
                <div class="music-track">
                    <span class="music-title">${escapeHtml(music.title || 'Background Music')}</span>
                    <span class="music-artist">${escapeHtml(music.artist || 'Unbekannt')}</span>
                </div>
                <div class="music-visualizer${state.muted ? ' is-muted' : ''}" aria-hidden="true">
                    ${Array.from({ length: 8 }, () => '<span></span>').join('')}
                </div>
                <div class="volume-track" aria-hidden="true">
                    <div class="volume-fill"></div>
                </div>
            </div>
        `;

        container.replaceWith(createWidget('Music', body, { static: true, open: true }));
    }

    function renderSocials() {
        const container = byId('socialsWidget');
        if (!container) return;

        const socials = Array.isArray(cfg.socials) ? cfg.socials : [];
        if (socials.length === 0) {
            container.remove();
            return;
        }

        const body = `
            <div class="socials-grid">
                ${socials.map((social) => {
                    const label = escapeHtml(social.label || 'Link');
                    const url = typeof social.url === 'string' ? social.url.trim() : '';
                    if (url) {
                        return `<a class="social-btn" href="${escapeHtml(url)}" target="_blank" rel="noopener noreferrer">${label}</a>`;
                    }
                    return `<span class="social-btn">${label}</span>`;
                }).join('')}
            </div>
        `;

        container.replaceWith(createWidget('Socials', body, { open: true }));
    }

    function renderNavIcons() {
        document.querySelectorAll('.nav-btn[data-icon]').forEach((btn) => {
            setIcon(btn, btn.dataset.icon, 'play');
        });
    }

    function renderHeroTitle() {
        const line1 = byId('heroLine1');
        const line2 = byId('heroLine2');

        if (Array.isArray(cfg.centerTitle) && cfg.centerTitle.length >= 2) {
            setText(line1, cfg.centerTitle[0]);
            setText(line2, cfg.centerTitle[1]);
            return;
        }

        if (typeof cfg.centerTitle === 'string' && cfg.centerTitle.trim()) {
            const parts = cfg.centerTitle.trim().split(/\s+/);
            setText(line1, parts[0] || 'LOADING');
            setText(line2, parts.slice(1).join(' ') || 'SCREEN');
            return;
        }

        setText(line1, cfg.serverTitleWhite || 'LOADING');
        setText(line2, cfg.serverTitleYellow || 'SCREEN');
    }

    function renderStaticContent() {
        applyTheme();
        setText(byId('welcomeTitle'), cfg.welcomeTitle || `WELCOME TO ${(cfg.serverTitleWhite || 'SERVER').toUpperCase()}`);
        setText(byId('welcomeText'), cfg.welcomeText || cfg.subtitle || 'Willkommen auf unserem Roleplay-Server.');
        renderHeroTitle();
        renderNavIcons();
        renderRules();
        renderUpdates();
        renderGallery();
        renderTeam();
        renderMusic();
        renderSocials();
    }

    function updateSoundUI() {
        if (state.soundElement) state.soundElement.muted = state.muted;

        setIcon(soundIcon, state.muted ? (cfg.musicStoppedIcon || cfg.musicStoppedEmoji) : (cfg.musicPlayingIcon || cfg.musicPlayingEmoji), state.muted ? 'volume-off' : 'volume-high');

        if (soundText) {
            soundText.innerHTML = state.muted
                ? '<b>[LEERTASTE]</b> Musik starten'
                : '<b>[LEERTASTE]</b> Musik stoppen';
        }

        const visualizer = musicVisualizer();
        if (visualizer) visualizer.classList.toggle('is-muted', state.muted);

        const volume = volumeFill();
        if (volume) volume.style.width = state.muted ? '0%' : '72%';
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

        bgVideo.addEventListener('canplay', () => showElement(bgVideo), { once: true });
        bgVideo.addEventListener('error', () => hideElement(bgVideo));

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

    window.addEventListener('message', (event) => {
        const data = event.data || {};

        if (data.eventName === 'loadProgress' && typeof data.loadFraction === 'number') {
            state.gotFiveMProgress = true;
            setProgress(data.loadFraction * 100);
        }
    });

    renderStaticContent();
    updateSoundUI();
    setupBackground();
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
    }

    bootstrap();
})();
