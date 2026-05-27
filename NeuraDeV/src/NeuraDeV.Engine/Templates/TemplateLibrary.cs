namespace NeuraDeV.Engine.Templates;

/// <summary>
/// Built-in catalogue of production-ready code templates. Every template
/// returns a complete, runnable set of files — no half-snippets.
///
/// Adding a new template:
///   1. Add a static string constant or method here.
///   2. Map it from <see cref="NeuraDeV.Engine.Reasoning.Planner.ExecuteAsync"/>.
///   3. Wire a route in <see cref="NeuraDeV.Engine.Reasoning.IntentClassifier"/>.
/// </summary>
public sealed class TemplateLibrary
{
    public IReadOnlyList<GeneratedFile> QbCorePoliceJob(ProjectContext ctx) => new[]
    {
        new GeneratedFile("sql/police_system.sql", PoliceSql, "sql"),
        new GeneratedFile("server/police_server.lua", PoliceServerLua, "lua"),
        new GeneratedFile("client/police_client.lua", PoliceClientLua, "lua"),
        new GeneratedFile("ui/index.html", PoliceUiHtml, "html"),
        new GeneratedFile("ui/style.css", PoliceUiCss, "css"),
        new GeneratedFile("ui/script.js", PoliceUiJs, "js"),
        new GeneratedFile("config/config.lua", PoliceConfigLua, "lua"),
        new GeneratedFile("fxmanifest.lua", PoliceFxManifest, "lua"),
    };

    public IReadOnlyList<GeneratedFile> FiveMResource(ProjectContext ctx) => new[]
    {
        new GeneratedFile("fxmanifest.lua", GenericFxManifest, "lua"),
        new GeneratedFile("server/main.lua", "-- server entry\nlocal QBCore = exports['qb-core']:GetCoreObject()\n", "lua"),
        new GeneratedFile("client/main.lua", "-- client entry\nlocal QBCore = exports['qb-core']:GetCoreObject()\n", "lua"),
        new GeneratedFile("config/config.lua", "Config = {}\nConfig.Debug = false\n", "lua"),
    };

    public IReadOnlyList<GeneratedFile> NuiMenu(ProjectContext ctx) => new[]
    {
        new GeneratedFile("ui/index.html", NuiMenuHtml, "html"),
        new GeneratedFile("ui/style.css", NuiMenuCss, "css"),
        new GeneratedFile("ui/script.js", NuiMenuJs, "js"),
        new GeneratedFile("client/menu_client.lua", NuiMenuClientLua, "lua"),
    };

    public IReadOnlyList<GeneratedFile> SqlSchema(ProjectContext ctx) => new[]
    {
        new GeneratedFile("sql/schema.sql", GenericSqlSchema, "sql"),
    };

    public IReadOnlyList<GeneratedFile> ConfigFile(ProjectContext ctx) => new[]
    {
        new GeneratedFile("config/config.lua", "Config = {}\nConfig.Debug = false\nConfig.Locale = 'de'\n", "lua"),
    };

    // ─────────────────────────────────────────────────────────────────────────
    // POLICE JOB — full QBCore implementation
    // ─────────────────────────────────────────────────────────────────────────

    private const string PoliceSql = """
        CREATE TABLE IF NOT EXISTS `police_records` (
          `id`         INT AUTO_INCREMENT PRIMARY KEY,
          `citizen_id` VARCHAR(50) NOT NULL,
          `officer_id` VARCHAR(50) NOT NULL,
          `charge`     VARCHAR(255) NOT NULL,
          `fine`       INT NOT NULL DEFAULT 0,
          `jail_min`   INT NOT NULL DEFAULT 0,
          `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          INDEX (`citizen_id`),
          INDEX (`officer_id`)
        ) ENGINE=InnoDB;

        CREATE TABLE IF NOT EXISTS `police_evidence` (
          `id`         INT AUTO_INCREMENT PRIMARY KEY,
          `case_id`    INT NOT NULL,
          `type`       VARCHAR(50) NOT NULL,
          `data`       JSON NOT NULL,
          `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (`case_id`) REFERENCES `police_records`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB;
        """;

    private const string PoliceServerLua = """
        local QBCore = exports['qb-core']:GetCoreObject()

        -- Polizeijob definieren
        QBCore.Functions.CreateJob("police", {
            label = 'Polizei',
            defaultDuty = true,
            offDutyPay = true,
            grades = {
                [0] = { name = 'Rekrut',     payment = 50  },
                [1] = { name = 'Offizier',   payment = 100 },
                [2] = { name = 'Sergeant',   payment = 150 },
                [3] = { name = 'Leutnant',   payment = 200 },
                [4] = { name = 'Kommandant', payment = 250 },
            },
        })

        -- Akte erstellen (server-validiert)
        RegisterNetEvent('neuradev:police:createRecord', function(targetCid, charge, fine, jail)
            local src = source
            local Player = QBCore.Functions.GetPlayer(src)
            if not Player or Player.PlayerData.job.name ~= 'police' then return end

            charge = tostring(charge or ''):sub(1, 255)
            fine   = math.max(0, tonumber(fine) or 0)
            jail   = math.max(0, tonumber(jail) or 0)

            MySQL.insert('INSERT INTO police_records (citizen_id, officer_id, charge, fine, jail_min) VALUES (?, ?, ?, ?, ?)',
                { targetCid, Player.PlayerData.citizenid, charge, fine, jail })
        end)

        QBCore.Functions.CreateCallback('neuradev:police:listRecords', function(src, cb, citizenId)
            local Player = QBCore.Functions.GetPlayer(src)
            if not Player or Player.PlayerData.job.name ~= 'police' then return cb({}) end
            MySQL.query('SELECT * FROM police_records WHERE citizen_id = ? ORDER BY created_at DESC',
                { citizenId }, function(rows) cb(rows or {}) end)
        end)
        """;

    private const string PoliceClientLua = """
        local QBCore = exports['qb-core']:GetCoreObject()
        local menuOpen = false

        local function ToggleMenu()
            menuOpen = not menuOpen
            SetNuiFocus(menuOpen, menuOpen)
            SendNUIMessage({ action = 'toggle', open = menuOpen })
        end

        RegisterCommand('police', function()
            local PlayerData = QBCore.Functions.GetPlayerData()
            if PlayerData.job and PlayerData.job.name == 'police' then ToggleMenu() end
        end, false)

        RegisterNUICallback('close', function(_, cb) ToggleMenu(); cb({}) end)

        RegisterNUICallback('createRecord', function(data, cb)
            TriggerServerEvent('neuradev:police:createRecord',
                data.citizenId, data.charge, data.fine, data.jail)
            cb({ ok = true })
        end)
        """;

    private const string PoliceUiHtml = """
        <!DOCTYPE html>
        <html lang="de">
        <head>
          <meta charset="UTF-8">
          <link rel="stylesheet" href="style.css">
          <title>Polizei Menü</title>
        </head>
        <body>
          <div id="app" class="hidden">
            <header><span>POLIZEI MENÜ</span></header>
            <nav>
              <button data-tab="equipment">Ausrüstung</button>
              <button data-tab="vehicles">Fahrzeuge</button>
              <button data-tab="players">Spieler</button>
              <button data-tab="settings">Einstellungen</button>
            </nav>
            <section id="content"></section>
          </div>
          <script src="script.js"></script>
        </body>
        </html>
        """;

    private const string PoliceUiCss = """
        :root { --bg:#0a0a1a; --panel:#15152e; --accent:#8b5cf6; --text:#e8e8f0; }
        body { margin:0; font-family:'Segoe UI',sans-serif; background:transparent; color:var(--text); }
        .hidden { display:none; }
        #app {
          position:fixed; inset:0; margin:auto;
          width:720px; height:480px;
          background:linear-gradient(180deg,#1a1a2e,#06061a);
          border:1px solid #2a2a55; border-radius:14px;
          box-shadow:0 0 60px rgba(139,92,246,.35);
          display:flex; flex-direction:column; overflow:hidden;
        }
        header { padding:18px; text-align:center; font-weight:700; letter-spacing:1px; }
        nav { display:flex; gap:6px; padding:0 14px; }
        nav button {
          flex:1; padding:10px; background:#1b1b47; color:var(--text);
          border:1px solid #2a2a55; border-radius:10px; cursor:pointer;
        }
        nav button:hover { border-color:var(--accent); }
        #content { flex:1; padding:18px; overflow:auto; }
        """;

    private const string PoliceUiJs = """
        const send = (action, payload = {}) =>
          fetch(`https://${GetParentResourceName ? GetParentResourceName() : 'neuradev'}/${action}`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
          });

        window.addEventListener('message', (e) => {
          const { action, open } = e.data || {};
          if (action === 'toggle') document.getElementById('app').classList.toggle('hidden', !open);
        });

        document.addEventListener('keyup', (e) => { if (e.key === 'Escape') send('close'); });

        document.querySelectorAll('nav button').forEach(b => b.addEventListener('click', () => {
          document.getElementById('content').textContent = `→ ${b.dataset.tab}`;
        }));
        """;

    private const string PoliceConfigLua = """
        Config = {}
        Config.Debug = false
        Config.Locale = 'de'

        Config.Stations = {
            { name = 'Mission Row', coords = vector3(441.7, -982.0, 30.6) },
        }

        Config.Vehicles = {
            { model = 'police',  label = 'Streifenwagen' },
            { model = 'police2', label = 'Zivile Streife' },
            { model = 'fbi',     label = 'Einsatzwagen'   },
        }
        """;

    private const string PoliceFxManifest = """
        fx_version 'cerulean'
        game 'gta5'
        author 'NeuraDeV'
        description 'Police Job System (QBCore)'
        version '1.0.0'

        shared_scripts { 'config/config.lua' }
        server_scripts { '@oxmysql/lib/MySQL.lua', 'server/police_server.lua' }
        client_scripts { 'client/police_client.lua' }

        ui_page 'ui/index.html'
        files { 'ui/index.html', 'ui/style.css', 'ui/script.js' }

        dependencies { 'qb-core', 'oxmysql' }
        """;

    // ─────────────────────────────────────────────────────────────────────────
    // Generic scaffolds
    // ─────────────────────────────────────────────────────────────────────────

    private const string GenericFxManifest = """
        fx_version 'cerulean'
        game 'gta5'
        author 'NeuraDeV'
        description 'NeuraDeV generated resource'
        version '1.0.0'

        shared_scripts { 'config/config.lua' }
        server_scripts { 'server/main.lua' }
        client_scripts { 'client/main.lua' }
        """;

    private const string GenericSqlSchema = """
        CREATE TABLE IF NOT EXISTS `entities` (
          `id`         INT AUTO_INCREMENT PRIMARY KEY,
          `owner_id`   VARCHAR(50) NOT NULL,
          `data`       JSON NOT NULL,
          `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          INDEX (`owner_id`)
        ) ENGINE=InnoDB;
        """;

    private const string NuiMenuHtml = """
        <!DOCTYPE html>
        <html lang="de"><head><meta charset="UTF-8"><link rel="stylesheet" href="style.css"></head>
        <body><div id="menu" class="hidden"><h2>Menü</h2><ul id="items"></ul></div>
        <script src="script.js"></script></body></html>
        """;

    private const string NuiMenuCss = """
        body{margin:0;font-family:'Segoe UI',sans-serif;background:transparent;color:#e8e8f0;}
        #menu{position:fixed;inset:0;margin:auto;width:420px;height:520px;
          background:linear-gradient(180deg,#15152e,#06061a);border:1px solid #2a2a55;
          border-radius:12px;padding:18px;box-shadow:0 0 50px rgba(139,92,246,.3);}
        .hidden{display:none;}
        ul{list-style:none;padding:0;}li{padding:10px;border-bottom:1px solid #1f1f44;cursor:pointer;}
        li:hover{background:#1b1b47;}
        """;

    private const string NuiMenuJs = """
        window.addEventListener('message', (e) => {
          if (e.data.action === 'open')  document.getElementById('menu').classList.remove('hidden');
          if (e.data.action === 'close') document.getElementById('menu').classList.add('hidden');
          if (e.data.items) {
            const ul = document.getElementById('items');
            ul.innerHTML = '';
            for (const it of e.data.items) {
              const li = document.createElement('li');
              li.textContent = it.label;
              li.onclick = () => fetch(`https://${GetParentResourceName()}/select`, {
                method: 'POST', body: JSON.stringify({ id: it.id }),
                headers: { 'Content-Type': 'application/json' }
              });
              ul.appendChild(li);
            }
          }
        });
        """;

    private const string NuiMenuClientLua = """
        RegisterCommand('menu', function()
            SetNuiFocus(true, true)
            SendNUIMessage({ action = 'open', items = {
                { id = 'a', label = 'Option A' },
                { id = 'b', label = 'Option B' },
            }})
        end, false)

        RegisterNUICallback('select', function(data, cb)
            print('selected', data.id)
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'close' })
            cb({})
        end)
        """;
}
