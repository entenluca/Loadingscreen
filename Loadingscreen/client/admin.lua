local RESOURCE = GetCurrentResourceName()

local function notify(title, description, ntype)
    lib.notify({
        title = title,
        description = description,
        type = ntype or 'inform'
    })
end

local function ensureAdmin()
    local allowed = lib.callback.await('loadingscreen:server:canAdmin', false)
    if not allowed then
        notify('Loading-Screen', 'Du hast keine Berechtigung für das Admin-Panel.', 'error')
    end
    return allowed
end

local function getConfig()
    return lib.callback.await('loadingscreen:server:getConfig', false)
end

local function savePatch(patch, successMessage)
    local ok, result = lib.callback.await('loadingscreen:server:updateConfig', false, patch)
    if ok then
        notify('Loading-Screen', successMessage or 'Einstellungen gespeichert.', 'success')
        return result
    end

    notify('Loading-Screen', result or 'Speichern fehlgeschlagen.', 'error')
    return nil
end

local function splitLines(value)
    local items = {}
    for line in string.gmatch(value or '', '[^\r\n]+') do
        local trimmed = line:match('^%s*(.-)%s*$')
        if trimmed ~= '' then
            items[#items + 1] = trimmed
        end
    end
    return items
end

local function joinLines(items)
    if type(items) ~= 'table' then
        return ''
    end

    return table.concat(items, '\n')
end

local function confirmDialog(title, content)
    return lib.alertDialog({
        header = title,
        content = content,
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Bestätigen',
            cancel = 'Abbrechen'
        }
    }) == 'confirm'
end

local function editGeneral()
    local config = getConfig()
    if not config then return end

    local input = lib.inputDialog('Allgemein', {
        { type = 'input', label = 'Akzentfarbe (Hex)', default = config.accentColor or '#5b9cff', required = true },
        { type = 'input', label = 'Welcome-Titel', default = config.welcomeTitle or '', required = true },
        { type = 'textarea', label = 'Welcome-Text', default = config.welcomeText or '', required = true },
        { type = 'input', label = 'Titel Zeile 1 (Hero)', default = config.centerTitle and config.centerTitle[1] or config.serverTitleWhite or 'LOADING', required = true },
        { type = 'input', label = 'Titel Zeile 2 (Hero)', default = config.centerTitle and config.centerTitle[2] or config.serverTitleYellow or 'SCREEN', required = true },
        { type = 'input', label = 'Untertitel', default = config.subtitle or '' }
    })

    if not input then return end

    savePatch({
        accentColor = input[1],
        welcomeTitle = input[2],
        welcomeText = input[3],
        serverTitleWhite = input[4],
        serverTitleYellow = input[5],
        centerTitle = { input[4], input[5] },
        subtitle = input[6]
    }, 'Allgemeine Einstellungen gespeichert.')
end

local function editBackground()
    local config = getConfig()
    if not config then return end

    local input = lib.inputDialog('Hintergrund', {
        {
            type = 'select',
            label = 'Modus',
            options = {
                { value = 'video', label = 'Video (MP4)' },
                { value = 'images', label = 'Bilder-Slideshow' }
            },
            default = config.mediaMode or 'video',
            required = true
        },
        { type = 'input', label = 'Video-Pfad', default = config.backgroundVideo or 'assets/background.mp4' },
        { type = 'textarea', label = 'Slideshow-Bilder (eine Zeile pro Bild)', default = joinLines(config.backgroundImages) },
        { type = 'number', label = 'Slideshow-Intervall (ms)', default = config.slideshowInterval or 5000, min = 1000 },
        { type = 'number', label = 'Slideshow-Fade (ms)', default = config.slideshowFadeMs or 800, min = 0 },
        { type = 'input', label = 'Separate Audio-Datei (Bilder-Modus)', default = config.backgroundAudio or '' },
        { type = 'checkbox', label = 'Musik standardmäßig stumm starten', checked = config.startMuted or false }
    })

    if not input then return end

    savePatch({
        mediaMode = input[1],
        backgroundVideo = input[2],
        backgroundImages = splitLines(input[3]),
        slideshowInterval = input[4],
        slideshowFadeMs = input[5],
        backgroundAudio = input[6],
        startMuted = input[7] == true
    }, 'Hintergrund-Einstellungen gespeichert.')
end

local function editMusic()
    local config = getConfig()
    if not config then return end

    local music = config.music or {}
    local input = lib.inputDialog('Musik', {
        { type = 'input', label = 'Track-Titel', default = music.title or '', required = true },
        { type = 'input', label = 'Künstler', default = music.artist or '', required = true }
    })

    if not input then return end

    savePatch({
        music = {
            title = input[1],
            artist = input[2]
        }
    }, 'Musik-Einstellungen gespeichert.')
end

local function editLoadingPhases()
    local config = getConfig()
    if not config then return end

    local lines = {}
    for _, phase in ipairs(config.loadingPhases or {}) do
        lines[#lines + 1] = ('%s|%s'):format(phase.until or 0, phase.text or '')
    end

    local input = lib.inputDialog('Lade-Phasen', {
        {
            type = 'textarea',
            label = 'Format: pro Zeile "Prozent|Text" (z.B. 55|Ressourcen werden geladen...)',
            default = table.concat(lines, '\n'),
            required = true
        }
    })

    if not input then return end

    local phases = {}
    for _, line in ipairs(splitLines(input[1])) do
        local untilPercent, text = line:match('^(%d+)|(.+)$')
        if untilPercent and text then
            phases[#phases + 1] = {
                until = tonumber(untilPercent),
                text = text:match('^%s*(.-)%s*$')
            }
        end
    end

    savePatch({ loadingPhases = phases }, 'Lade-Phasen gespeichert.')
end

local function editGallery()
    local config = getConfig()
    if not config then return end

    local input = lib.inputDialog('Galerie', {
        {
            type = 'textarea',
            label = 'Galerie-Bilder (eine Zeile pro Bild)',
            default = joinLines(config.galleryImages),
            required = true
        }
    })

    if not input then return end

    savePatch({ galleryImages = splitLines(input[1]) }, 'Galerie gespeichert.')
end

local function editRule(index)
    local config = getConfig()
    if not config then return end

    local rules = config.serverRules or {}
    local rule = rules[index]
    if not rule then return end

    local input = lib.inputDialog(('Regel #%s bearbeiten'):format(index), {
        { type = 'input', label = 'Titel', default = rule.title or '', required = true },
        { type = 'textarea', label = 'Text', default = rule.text or '', required = true }
    })

    if not input then
        OpenRulesMenu()
        return
    end

    rules[index] = { title = input[1], text = input[2] }
    savePatch({ serverRules = rules }, 'Regel aktualisiert.')
    OpenRulesMenu()
end

local function deleteRule(index)
    local config = getConfig()
    if not config then return end

    local rules = config.serverRules or {}
    if not rules[index] then return end

    if not confirmDialog('Regel löschen', ('Regel "%s" wirklich löschen?'):format(rules[index].title or index)) then
        OpenRulesMenu()
        return
    end

    table.remove(rules, index)
    savePatch({ serverRules = rules }, 'Regel gelöscht.')
    OpenRulesMenu()
end

function OpenRulesMenu()
    local config = getConfig()
    if not config then return end

    local options = {
        {
            title = '+ Neue Regel',
            icon = 'plus',
            onSelect = function()
                local input = lib.inputDialog('Neue Regel', {
                    { type = 'input', label = 'Titel', required = true },
                    { type = 'textarea', label = 'Text', required = true }
                })

                if not input then
                    OpenRulesMenu()
                    return
                end

                local fresh = getConfig()
                if not fresh then
                    OpenRulesMenu()
                    return
                end

                local rules = fresh.serverRules or {}
                rules[#rules + 1] = { title = input[1], text = input[2] }
                savePatch({ serverRules = rules }, 'Regel hinzugefügt.')
                OpenRulesMenu()
            end
        }
    }

    for index, rule in ipairs(config.serverRules or {}) do
        options[#options + 1] = {
            title = rule.title or ('Rule #' .. index),
            description = rule.text,
            icon = 'list',
            arrow = true,
            onSelect = function()
                lib.registerContext({
                    id = 'loadingscreen_admin_rule_item',
                    menu = 'loadingscreen_admin_rules',
                    title = rule.title or ('Rule #' .. index),
                    options = {
                        {
                            title = 'Bearbeiten',
                            icon = 'pen',
                            onSelect = function()
                                editRule(index)
                            end
                        },
                        {
                            title = 'Löschen',
                            icon = 'trash',
                            onSelect = function()
                                deleteRule(index)
                            end
                        }
                    }
                })
                lib.showContext('loadingscreen_admin_rule_item')
            end
        }
    end

    lib.registerContext({
        id = 'loadingscreen_admin_rules',
        menu = 'loadingscreen_admin_main',
        title = 'Server Rules',
        options = options
    })

    lib.showContext('loadingscreen_admin_rules')
end

local function editUpdate(index)
    local config = getConfig()
    if not config then return end

    local updates = config.serverUpdates or {}
    local update = updates[index]
    if not update then return end

    local input = lib.inputDialog(('Update #%s bearbeiten'):format(index), {
        { type = 'input', label = 'Datum', default = update.date or '' },
        { type = 'input', label = 'Titel', default = update.title or '', required = true },
        { type = 'textarea', label = 'Text', default = update.text or '', required = true },
        { type = 'input', label = 'Avatar-Pfad (optional)', default = update.avatar or '' }
    })

    if not input then
        OpenUpdatesMenu()
        return
    end

    updates[index] = {
        date = input[1],
        title = input[2],
        text = input[3],
        avatar = input[4]
    }

    savePatch({ serverUpdates = updates }, 'Update gespeichert.')
    OpenUpdatesMenu()
end

local function deleteUpdate(index)
    local config = getConfig()
    if not config then return end

    local updates = config.serverUpdates or {}
    if not updates[index] then return end

    if not confirmDialog('Update löschen', ('Update "%s" wirklich löschen?'):format(updates[index].title or index)) then
        OpenUpdatesMenu()
        return
    end

    table.remove(updates, index)
    savePatch({ serverUpdates = updates }, 'Update gelöscht.')
    OpenUpdatesMenu()
end

function OpenUpdatesMenu()
    local config = getConfig()
    if not config then return end

    local options = {
        {
            title = '+ Neues Update',
            icon = 'plus',
            onSelect = function()
                local input = lib.inputDialog('Neues Update', {
                    { type = 'input', label = 'Datum', default = os.date('%d.%m %H:%M') },
                    { type = 'input', label = 'Titel', required = true },
                    { type = 'textarea', label = 'Text', required = true },
                    { type = 'input', label = 'Avatar-Pfad (optional)' }
                })

                if not input then
                    OpenUpdatesMenu()
                    return
                end

                local fresh = getConfig()
                if not fresh then
                    OpenUpdatesMenu()
                    return
                end

                local updates = fresh.serverUpdates or {}
                updates[#updates + 1] = {
                    date = input[1],
                    title = input[2],
                    text = input[3],
                    avatar = input[4] or ''
                }

                savePatch({ serverUpdates = updates }, 'Update hinzugefügt.')
                OpenUpdatesMenu()
            end
        }
    }

    for index, update in ipairs(config.serverUpdates or {}) do
        options[#options + 1] = {
            title = update.title or ('Update #' .. index),
            description = update.date,
            icon = 'newspaper',
            arrow = true,
            onSelect = function()
                lib.registerContext({
                    id = 'loadingscreen_admin_update_item',
                    menu = 'loadingscreen_admin_updates',
                    title = update.title or ('Update #' .. index),
                    options = {
                        { title = 'Bearbeiten', icon = 'pen', onSelect = function() editUpdate(index) end },
                        { title = 'Löschen', icon = 'trash', onSelect = function() deleteUpdate(index) end }
                    }
                })
                lib.showContext('loadingscreen_admin_update_item')
            end
        }
    end

    lib.registerContext({
        id = 'loadingscreen_admin_updates',
        menu = 'loadingscreen_admin_main',
        title = 'Server Updates',
        options = options
    })

    lib.showContext('loadingscreen_admin_updates')
end

local function editTeamMember(index)
    local config = getConfig()
    if not config then return end

    local members = config.teamMembers or {}
    local member = members[index]
    if not member then return end

    local input = lib.inputDialog(('Teammitglied #%s'):format(index), {
        { type = 'input', label = 'Name', default = member.name or '', required = true },
        { type = 'input', label = 'Rolle', default = member.role or '', required = true },
        { type = 'input', label = 'Discord', default = member.discord or '' },
        { type = 'input', label = 'Avatar-Pfad (optional)', default = member.avatar or '' }
    })

    if not input then
        OpenTeamMenu()
        return
    end

    members[index] = {
        name = input[1],
        role = input[2],
        discord = input[3],
        avatar = input[4] or ''
    }

    savePatch({ teamMembers = members }, 'Teammitglied gespeichert.')
    OpenTeamMenu()
end

local function deleteTeamMember(index)
    local config = getConfig()
    if not config then return end

    local members = config.teamMembers or {}
    if not members[index] then return end

    if not confirmDialog('Teammitglied löschen', ('"%s" wirklich entfernen?'):format(members[index].name or index)) then
        OpenTeamMenu()
        return
    end

    table.remove(members, index)
    savePatch({ teamMembers = members }, 'Teammitglied entfernt.')
    OpenTeamMenu()
end

function OpenTeamMenu()
    local config = getConfig()
    if not config then return end

    local options = {
        {
            title = '+ Teammitglied hinzufügen',
            icon = 'plus',
            onSelect = function()
                local input = lib.inputDialog('Neues Teammitglied', {
                    { type = 'input', label = 'Name', required = true },
                    { type = 'input', label = 'Rolle', default = 'Admin', required = true },
                    { type = 'input', label = 'Discord' },
                    { type = 'input', label = 'Avatar-Pfad (optional)' }
                })

                if not input then
                    OpenTeamMenu()
                    return
                end

                local fresh = getConfig()
                if not fresh then
                    OpenTeamMenu()
                    return
                end

                local members = fresh.teamMembers or {}
                members[#members + 1] = {
                    name = input[1],
                    role = input[2],
                    discord = input[3],
                    avatar = input[4] or ''
                }

                savePatch({ teamMembers = members }, 'Teammitglied hinzugefügt.')
                OpenTeamMenu()
            end
        }
    }

    for index, member in ipairs(config.teamMembers or {}) do
        options[#options + 1] = {
            title = member.name or ('Member #' .. index),
            description = member.role,
            icon = 'users',
            arrow = true,
            onSelect = function()
                lib.registerContext({
                    id = 'loadingscreen_admin_team_item',
                    menu = 'loadingscreen_admin_team',
                    title = member.name or ('Member #' .. index),
                    options = {
                        { title = 'Bearbeiten', icon = 'pen', onSelect = function() editTeamMember(index) end },
                        { title = 'Löschen', icon = 'trash', onSelect = function() deleteTeamMember(index) end }
                    }
                })
                lib.showContext('loadingscreen_admin_team_item')
            end
        }
    end

    lib.registerContext({
        id = 'loadingscreen_admin_team',
        menu = 'loadingscreen_admin_main',
        title = 'Authorized Teams',
        options = options
    })

    lib.showContext('loadingscreen_admin_team')
end

local function editSocial(index)
    local config = getConfig()
    if not config then return end

    local socials = config.socials or {}
    local social = socials[index]
    if not social then return end

    local input = lib.inputDialog(('Social #%s'):format(index), {
        { type = 'input', label = 'Label', default = social.label or 'Discord', required = true },
        { type = 'input', label = 'URL', default = social.url or '', required = true }
    })

    if not input then
        OpenSocialsMenu()
        return
    end

    socials[index] = { label = input[1], url = input[2] }
    savePatch({ socials = socials }, 'Social-Link gespeichert.')
    OpenSocialsMenu()
end

local function deleteSocial(index)
    local config = getConfig()
    if not config then return end

    local socials = config.socials or {}
    if not socials[index] then return end

    if not confirmDialog('Social löschen', ('"%s" wirklich löschen?'):format(socials[index].label or index)) then
        OpenSocialsMenu()
        return
    end

    table.remove(socials, index)
    savePatch({ socials = socials }, 'Social-Link gelöscht.')
    OpenSocialsMenu()
end

function OpenSocialsMenu()
    local config = getConfig()
    if not config then return end

    local options = {
        {
            title = '+ Social hinzufügen',
            icon = 'plus',
            onSelect = function()
                local input = lib.inputDialog('Neuer Social-Link', {
                    { type = 'input', label = 'Label', default = 'Discord', required = true },
                    { type = 'input', label = 'URL', required = true }
                })

                if not input then
                    OpenSocialsMenu()
                    return
                end

                local fresh = getConfig()
                if not fresh then
                    OpenSocialsMenu()
                    return
                end

                local socials = fresh.socials or {}
                socials[#socials + 1] = { label = input[1], url = input[2] }
                savePatch({ socials = socials }, 'Social-Link hinzugefügt.')
                OpenSocialsMenu()
            end
        }
    }

    for index, social in ipairs(config.socials or {}) do
        options[#options + 1] = {
            title = social.label or ('Social #' .. index),
            description = social.url,
            icon = 'link',
            arrow = true,
            onSelect = function()
                lib.registerContext({
                    id = 'loadingscreen_admin_social_item',
                    menu = 'loadingscreen_admin_socials',
                    title = social.label or ('Social #' .. index),
                    options = {
                        { title = 'Bearbeiten', icon = 'pen', onSelect = function() editSocial(index) end },
                        { title = 'Löschen', icon = 'trash', onSelect = function() deleteSocial(index) end }
                    }
                })
                lib.showContext('loadingscreen_admin_social_item')
            end
        }
    end

    lib.registerContext({
        id = 'loadingscreen_admin_socials',
        menu = 'loadingscreen_admin_main',
        title = 'Socials',
        options = options
    })

    lib.showContext('loadingscreen_admin_socials')
end

local function resetConfig()
    if not confirmDialog('Zurücksetzen', 'Alle Loading-Screen-Einstellungen auf Standard zurücksetzen?') then
        return
    end

    local ok = lib.callback.await('loadingscreen:server:resetConfig', false)
    if ok then
        notify('Loading-Screen', 'Standard-Konfiguration wiederhergestellt.', 'success')
    else
        notify('Loading-Screen', 'Zurücksetzen fehlgeschlagen.', 'error')
    end
end

function OpenAdminMenu()
    if not ensureAdmin() then
        return
    end

    lib.registerContext({
        id = 'loadingscreen_admin_main',
        title = 'Loading-Screen Admin',
        options = {
            {
                title = 'Allgemein',
                description = 'Welcome, Titel, Untertitel, Akzentfarbe',
                icon = 'palette',
                onSelect = editGeneral
            },
            {
                title = 'Hintergrund',
                description = 'Video, Slideshow, Audio, Stummschaltung',
                icon = 'image',
                onSelect = editBackground
            },
            {
                title = 'Server Rules',
                description = 'Regeln verwalten',
                icon = 'list',
                arrow = true,
                onSelect = OpenRulesMenu
            },
            {
                title = 'Server Updates',
                description = 'Changelog / Updates verwalten',
                icon = 'newspaper',
                arrow = true,
                onSelect = OpenUpdatesMenu
            },
            {
                title = 'Server Gallery',
                description = 'Galerie-Bilder bearbeiten',
                icon = 'images',
                onSelect = editGallery
            },
            {
                title = 'Authorized Teams',
                description = 'Teamliste verwalten',
                icon = 'users',
                arrow = true,
                onSelect = OpenTeamMenu
            },
            {
                title = 'Musik',
                description = 'Track-Titel und Künstler',
                icon = 'music',
                onSelect = editMusic
            },
            {
                title = 'Socials',
                description = 'Discord & Social-Links',
                icon = 'share-nodes',
                arrow = true,
                onSelect = OpenSocialsMenu
            },
            {
                title = 'Lade-Phasen',
                description = 'Footer-Status je Fortschritt',
                icon = 'gauge',
                onSelect = editLoadingPhases
            },
            {
                title = 'Auf Standard zurücksetzen',
                description = 'Alle Einstellungen zurücksetzen',
                icon = 'rotate-left',
                onSelect = resetConfig
            }
        }
    })

    lib.showContext('loadingscreen_admin_main')
end

RegisterCommand('loadingscreen', function()
    OpenAdminMenu()
end, false)

RegisterCommand('lsadmin', function()
    OpenAdminMenu()
end, false)

RegisterNetEvent('loadingscreen:client:openAdmin', function()
    OpenAdminMenu()
end)

RegisterNetEvent('loadingscreen:client:configUpdated', function()
    -- Hook für andere Client-Skripte / Vorschau-Integration
end)

exports('OpenAdminMenu', OpenAdminMenu)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    print(('[%s] Admin-Panel bereit. Befehle: /loadingscreen, /lsadmin'):format(RESOURCE))
end)
