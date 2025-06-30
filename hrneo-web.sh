#!/bin/sh

# === HRNeo WebUI Installer by @pegakmop ===

HRNEO_DIR="/opt/share/www/hrneo"
INDEX_FILE="$HRNEO_DIR/index.php"
MANIFEST_FILE="$HRNEO_DIR/manifest.json"
LIGHTTPD_CONF_DIR="/opt/etc/lighttpd/conf.d"
LIGHTTPD_CONF_FILE="$LIGHTTPD_CONF_DIR/80-hrneo.conf"

echo "[*] Проверка Entware..."
if ! command -v opkg >/dev/null 2>&1; then
    echo "❌ Entware не найден. Убедитесь, что он установлен и /opt примонтирован."
    exit 1
fi

echo "[*] Обновление списка пакетов..."
if ! opkg update >/dev/null 2>&1; then
    echo "❌ Не удалось обновить список пакетов."
    echo "Возможно у вас не установлены DoT и DoH DNS"
    exit 1
fi

echo "[*] Установка Lighttpd и PHP8..."
if ! opkg install lighttpd lighttpd-mod-cgi lighttpd-mod-setenv lighttpd-mod-redirect lighttpd-mod-rewrite php8 php8-cgi php8-cli php8-mod-curl php8-mod-openssl php8-mod-session jq >/dev/null 2>&1; then
    echo "❌ Ошибка при установке пакетов."
    exit 1
fi

echo "[*] Создание директорий..."
mkdir -p "$HRNEO_DIR"
mkdir -p "$LIGHTTPD_CONF_DIR"

if [ -f "$MANIFEST_FILE" ]; then
    echo "[*] Удаление старого manifest.json..."
    rm "$MANIFEST_FILE"
fi

echo "[*] Создание нового manifest.json..."
cat > "$MANIFEST_FILE" << 'EOF'
{
  "name": "HydraRoute Neo",
  "short_name": "hr neo",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#1b2434",
  "theme_color": "#fff",
  "orientation": "any",
  "prefer_related_applications": false,
  "icons": [
    {
      "src": "180x180.png",
      "sizes": "180x180",
      "type": "image/png"
    }
  ]
}
EOF

if [ -f "$INDEX_FILE" ]; then
    echo "[*] Удаление старого index.php..."
    //rm "$INDEX_FILE"
fi

echo "[*] Создание нового index.php..."
cat > "$INDEX_FILE" << 'EOF'
<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
$currentVersion = '0.0.0.2'; // текущая локальная версия
$remoteVersionUrl = 'https://raw.githubusercontent.com/pegakmop/hrneo/main/version.txt';
$updateNotice = '';
$context = stream_context_create(['http' => ['timeout' => 3]]);
$remoteContent = @file_get_contents($remoteVersionUrl, false, $context);

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['run_update'])) {
    $updateScript = 'curl -L -s "https://raw.githubusercontent.com/pegakmop/hrneo/refs/heads/main/hrneo-web.sh" > /tmp/hrneo-web.sh && sh /tmp/hrneo-web.sh';
    
    // Запускаем обновление в фоне
    shell_exec($updateScript . ' > /dev/null 2>&1 &');
    
    // Перенаправляем на страницу с информацией об обновлении
    header("Location: ?updating=1");
    exit;
}

// Проверяем, показывать ли страницу обновления
if (isset($_GET['updating'])) {
    ?>
    <!DOCTYPE html>
    <html lang="ru">
    <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Обновление HR Neo WebUI</title>
    <style>
    body {
      background: #1e1e2f;
      color: #e0e0e0;
      font-family: 'Roboto', sans-serif;
      margin: 0;
      padding: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      flex-direction: column;
    }
    .update-message {
      background: #68b0ab;
      color: #1e1e2f;
      padding: 2rem;
      border-radius: 10px;
      text-align: center;
      font-size: 1.2rem;
      font-weight: bold;
      box-shadow: 0 0 20px rgba(104, 176, 171, 0.5);
    }
    .spinner {
      border: 4px solid #292c42;
      border-top: 4px solid #68b0ab;
      border-radius: 50%;
      width: 50px;
      height: 50px;
      animation: spin 1s linear infinite;
      margin: 1rem auto;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    </style>
    <script>
    // Перезагружаем страницу через 10 секунд
    setTimeout(function() {
        window.location.href = '/';
    }, 10000);
    </script>
    </head>
    <body>
    <div class="update-message">
        <div class="spinner"></div>
        <h2>✔ Обновление запущено</h2>
        <p>Пожалуйста, подождите...<br>Страница автоматически перезагрузится через 10 секунд</p>
        <p><a href="/" style="color: #1e1e2f; text-decoration: underline;">Перезагрузить вручную</a></p>
    </div>
    </body>
    </html>
    <?php
    exit;
}

if ($remoteContent !== false) {
    $lines = explode("\n", $remoteContent);
    $versionInfo = [];
    foreach ($lines as $line) {
        $parts = explode('=', trim($line), 2);
        if (count($parts) == 2) {
            $versionInfo[trim($parts[0])] = trim($parts[1]);
        }
    }

    if (!empty($versionInfo['Version']) && version_compare($versionInfo['Version'], $currentVersion, '>')) {
        $updateNotice = '<div class="update-banner">'
                      . '⚠️ <b>Доступно обновление: v' . htmlspecialchars($versionInfo['Version']) . '</b><br>'
                      . nl2br(htmlspecialchars($versionInfo['Show'])) . '<br><br>'
                      . '<form method="post"><button type="submit" name="run_update">⬇️ Обновить сейчас</button></form>'
                      . '</div>';
    }
}
    if (isset($_POST['reboot'])) {
        $output = exec('reboot');
        $message = "<pre>Результат команды reboot:\n" . htmlspecialchars($output) . "</pre>";
        //echo "<pre>Результат команды neo restart:\n" . htmlspecialchars($output) . "</pre>";
    }
    if (isset($_POST['run'])) {
        $output = exec('/opt/etc/init.d/S99hrneo restart');
        $message = "<pre>Результат команды neo restart:\n" . htmlspecialchars($output) . "</pre>";
        //echo "<pre>Результат команды neo restart:\n" . htmlspecialchars($output) . "</pre>";
    }
$confPath = (function() {
    $lines = @file('/opt/etc/HydraRoute/hrneo.conf', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if ($lines) {
        foreach ($lines as $line) {
            if (strpos(trim($line), 'watchlistPath=') === 0) {
                return trim(substr($line, strpos($line, '=') + 1));
            }
        }
    }
    return '/opt/etc/HydraRoute/domain.conf';
})();
$ipListPath = (function() {
    $lines = @file('/opt/etc/HydraRoute/hrneo.conf', FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if ($lines) {
        foreach ($lines as $line) {
            if (strpos(trim($line), 'CIDRfile=') === 0) {
                return trim(substr($line, strpos($line, '=') + 1));
            }
        }
    }
    return '/opt/etc/HydraRoute/ip.list';
})();
$message = '';
$configFile = '/opt/etc/HydraRoute/hrneo.conf';

function getCIDRState($filePath) {
    $lines = file($filePath, FILE_IGNORE_NEW_LINES);
    foreach ($lines as $line) {
        if (strpos($line, 'CIDR=') === 0) {
            return trim(explode('=', $line, 2)[1]) === 'true';
        }
    }
    return false; // значение по умолчанию
}

function toggleCIDR($filePath) {
    $lines = file($filePath);
    foreach ($lines as &$line) {
        if (strpos($line, 'CIDR=') === 0) {
            $current = trim(explode('=', $line)[1]);
            $new = ($current === 'true') ? 'false' : 'true';
            $line = "CIDR=$new\n";
        }
    }
    file_put_contents($filePath, implode('', $lines));
}

// Читаем конфиг доменов
$raw = file_get_contents($confPath);
if ($raw === false) {
    die("Ошибка: не удалось прочитать конфиг доменов.");
}

// Читаем ip.list
$ipRaw = file_get_contents($ipListPath);
if ($ipRaw === false) {
    $ipRaw = ''; // Если файла нет, считаем пустым
}

function parseConfig(string $text): array {
    $policies = [];
    $lines = preg_split("/\r?\n/", $text);
    $currentPolicy = null;

    foreach ($lines as $line) {
        $line = trim($line);
        if (preg_match('/^##(.+)$/', $line, $m)) {
            $currentPolicy = $m[1];
            $policies[$currentPolicy] = '';
        } elseif ($currentPolicy !== null && $line !== '') {
            $policies[$currentPolicy] .= $line;
        }
    }
    return $policies;
}

function saveConfig(string $path, array $policies): bool {
    $content = "";
    foreach ($policies as $policy => $domains) {
        $content .= "##" . $policy . "\n" . $domains . "\n\n";
    }
    return file_put_contents($path, trim($content)) !== false;
}

$isAll = ($_GET['policy'] ?? '') === '__ALL__';
$isIPList = ($_GET['policy'] ?? '') === '__IPLIST__';

$policies = parseConfig($raw);

$currentPolicy = $_GET['policy'] ?? '';
$currentContent = '';

if ($isAll) {
    $currentContent = $raw;
} elseif ($isIPList) {
    $currentContent = $ipRaw;
} elseif ($currentPolicy && isset($policies[$currentPolicy])) {
    $currentContent = $policies[$currentPolicy];
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['new_policy_name'])) {
        $newName = trim($_POST['new_policy_name']);
        if ($newName === '') {
            $message = "❗ Имя группы не может быть пустым.";
        } elseif (isset($policies[$newName])) {
            $message = "❗ Группа с таким именем уже существует.";
        } else {
            $policies[$newName] = '';
            if (saveConfig($confPath, $policies)) {
                $message = "✔ Новая группа '$newName' успешно добавлена.";
                shell_exec('/opt/etc/init.d/S99hrneo stop');
                shell_exec('/opt/etc/init.d/S99hrneo restart');
                header("Location: ?policy=" . urlencode($newName));
                exit;
            } else {
                $message = "❗ Ошибка при сохранении файла.";
            }
        }
    } else {
        $postPolicy = $_POST['policy'] ?? '';
        $postContent = $_POST['content'] ?? '';

        if ($postPolicy === '__ALL__') {
            if (file_put_contents($confPath, $postContent) !== false) {
                shell_exec('/opt/etc/init.d/S99hrneo stop');
                shell_exec('/opt/etc/init.d/S99hrneo restart');
                $message = "✔ Конфиг успешно сохранён и hrneo перезапущен.";
                $currentPolicy = '__ALL__';
                $currentContent = $postContent;
                $isAll = true;
            } else {
                $message = "❗ Ошибка при сохранении файла.";
            }
        } elseif ($postPolicy === '__IPLIST__') {
            if (file_put_contents($ipListPath, $postContent) !== false) {
                shell_exec('ipset flush');
                shell_exec('/opt/etc/init.d/S99hrneo stop');
                shell_exec('/opt/etc/init.d/S99hrneo restart');
                $message = "✔ ip.list успешно сохранён, ipset очищен, hrneo перезапущен.";
                $currentPolicy = '__IPLIST__';
                $currentContent = $postContent;
                $isIPList = true;
            } else {
                $message = "❗ Ошибка при сохранении ip.list.";
            }
        } elseif ($postPolicy && isset($policies[$postPolicy])) {
            $postContent = preg_replace('/\s+/', '', $postContent);
            $policies[$postPolicy] = $postContent;

            if (saveConfig($confPath, $policies)) {
                shell_exec('/opt/etc/init.d/S99hrneo stop');
                shell_exec('/opt/etc/init.d/S99hrneo restart');
                $message = "✔ Группа '$postPolicy' успешно сохранена и hrneo перезапущен.";
                $currentPolicy = $postPolicy;
                $currentContent = $postContent;
            } else {
                $message = "❗ Ошибка при сохранении файла.";
            }
        } else {
            $message = "❗ Группа не выбрана или не найдена или было переключение CIDR в конфиге hrneo"; // . htmlspecialchars($output) . "";
        }
    }
}
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['toggleCIDR'])) {
    toggleCIDR($configFile);
    shell_exec('/opt/etc/init.d/S99hrneo restart');
    $currentCIDR = getCIDRState($configFile); // обновить состояние
}
$currentCIDR = getCIDRState($configFile);
?>

<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<link rel="manifest" href="manifest.json">
<title>HR Neo WebUI created by @pegakmop</title>
<style>
  /* === Базовый стиль (ПК и планшеты) === */
body {
  background: #1e1e2f;
  color: #e0e0e0;
  font-family: 'Roboto', sans-serif;
  margin: 0; padding: 0;
  display: flex; height: 100vh;
}

.sidebar {
  width: 280px;
  background: #292c42;
  padding: 1rem;
  overflow-y: auto;
  border-right: 1px solid #444;
  display: flex;
  flex-direction: column;
}

.sidebar a {
  display: block;
  padding: 0.6rem 1rem;
  color: #aaa;
  text-decoration: none;
  margin-bottom: 0.2rem;
  border-radius: 3px;
}

.sidebar a.active, .sidebar a:hover {
  background: #68b0ab;
  color: #1e1e2f;
  font-weight: bold;
}

.add-new-btn {
  margin-top: auto;
  background: #68b0ab;
  color: #1e1e2f;
  border: none;
  padding: 0.7rem 1rem;
  font-weight: 700;
  font-size: 1rem;
  cursor: pointer;
  border-radius: 4px;
  text-align: center;
}

.add-new-btn:hover {
  background: #55958f;
}

main {
  flex-grow: 1;
  padding: 1rem;
  display: flex;
  flex-direction: column;
}

textarea {
  flex-grow: 1;
  height: 777px;
  width: 95%;
  max-width: 100%;
  background: #252538;
  border: 1px solid #444;
  color: #e0e0e0;
  font-family: monospace;
  font-size: 1rem;
  padding: 0.7rem;
  resize: none;
  border-radius: 4px;
  margin-bottom: 1rem;
  white-space: pre-wrap;
}

button {
  background: #68b0ab;
  color: #1e1e2f;
  border: none;
  padding: 0.7rem 1.2rem;
  font-weight: 700;
  font-size: 1rem;
  cursor: pointer;
  border-radius: 4px;
  align-self: flex-start;
}

button:hover {
  background: #55958f;
}

.message {
  margin-bottom: 1rem;
  padding: 0.5rem 1rem;
  border-radius: 4px;
  background: #33394a;
  color: #68b0ab;
  font-weight: 500;
}

.modal {
  display: none;
  position: fixed;
  z-index: 9999;
  left: 0; top: 0;
  width: 100%; height: 100%;
  overflow: auto;
  background-color: rgba(0, 0, 0, 0.6);
}

.modal-content {
  background-color: #292c42;
  margin: 15% auto;
  padding: 20px;
  border: 1px solid #444;
  width: 300px;
  border-radius: 6px;
  color: #e0e0e0;
  box-shadow: 0 0 10px #68b0ab;
}

.modal-content label {
  display: block;
  margin-bottom: 0.5rem;
}

.modal-content input[type="text"] {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #444;
  border-radius: 4px;
  background: #252538;
  color: #e0e0e0;
  font-size: 1rem;
}

.modal-buttons {
  margin-top: 1rem;
  text-align: right;
}

.modal-buttons button {
  margin-left: 0.5rem;
}

.update-banner {
  background: #ff5e5e;
  color: white;
  padding: 1rem;
  border-radius: 5px;
  font-weight: bold;
  margin-bottom: 1rem;
  box-shadow: 0 0 10px #ffaaaa;
  text-align: center;
}
.update-banner button {
  margin-top: 10px;
  background: white;
  color: #ff5e5e;
  font-weight: bold;
  border: none;
  padding: 0.5rem 1rem;
  cursor: pointer;
  border-radius: 4px;
}
.update-banner button:hover {
  background: #ffecec;
}

/* === Мобильная адаптация === */
@media (max-width: 768px) {
  body {
    flex-direction: column;
    height: auto;
  }

  .sidebar {
    width: 100%;
    border-right: none;
    border-bottom: 1px solid #444;
    flex-direction: column; /* <-- ВАЖНО: вернуть вертикальную ориентацию */
    white-space: normal;
    overflow-x: hidden;
    overflow-y: auto;
    max-height: 300px; /* можно подогнать под высоту экрана */
  }

  .sidebar a {
    display: block;
    margin: 0.2rem 0;
    padding: 0.6rem 1rem;
  }

  .add-new-btn {
    margin-top: 1rem;
    align-self: flex-start;
  }

  main {
    padding: 1rem;
  }

  textarea {
    height: 300px;
  }

  .modal-content {
    width: 90%;
    margin: 30% auto;
  }
}
</style>
</head>
<body>

  <nav class="sidebar">
    <h3><button style="font-size:12px;" onclick="history.back();return false;">HRNeo </button></h3>
    <p><button class="add-new-btn" id="openModalBtn">Добавь группу</button></p>
    <a href="?policy=__ALL__" class="<?= ($currentPolicy === '__ALL__' ? 'active' : '') ?>">
      ➤ Все группы
    </a>
    <?php foreach ($policies as $name => $domains): ?>
      <a href="?policy=<?=urlencode($name)?>" class="<?= ($name === $currentPolicy ? 'active' : '') ?>">
        <?=htmlspecialchars($name)?>
      </a>
    <?php endforeach; ?>
    <a href="?policy=__IPLIST__" class="<?= ($currentPolicy === '__IPLIST__' ? 'active' : '') ?>">
      ➤ Подсети ip.list
    </a> 
    <p><button onclick="location.reload();" style="padding: 0.5rem 1rem; font-size: 14px;"> Обновить страницу </button></p>
  </nav>

  <main>
  <?php if ($message): ?>
    <div class="message"><?=htmlspecialchars($message)?></div>
  <?php endif; ?>
  <?php if ($updateNotice): ?>
    <?= $updateNotice ?>
  <?php endif; ?>

    <?php if ($currentPolicy || $isAll || $isIPList): ?>
      <form method="post">
        <input type="hidden" name="policy" value="<?=htmlspecialchars($currentPolicy)?>" />
        <textarea name="content" spellcheck="false"><?=htmlspecialchars($currentContent)?></textarea>
        <button type="submit">Сохранить и перезапустить</button>
      </form>
    <?php else: ?>
      <p>Выберите одну из групп или &laquo;Все группы&raquo; для редактирования списка доменов.</p> 
      <p>Выберите Подсети и &laquo;ip.list&raquo; для редактирования списка подсетей.</p>
      <p>CIDR для работы подсетей ip.list: <strong><?= $currentCIDR ? 'Включен ✅' : 'Выключен ❌' ?></strong></p>
    <form method="post">
    <input type="hidden" name="toggleCIDR" value="1">
    <button type="submit">
        <?= $currentCIDR ? 'Выключить CIDR' : 'Включить CIDR' ?>
    </button>
    </form>
    <p><form method="post">
        <button type="submit" name="run">♻️Рестарт HydraRoute Neo</button>
    </form></p>
    <form method="post">
        <button type="submit" name="reboot">♻️Перезагрузить Keenetic</button>
    </form>
    <p>Тестовый вариант веб интерфейса для проекта: <a href='https://github.com/Ground-Zerro/HydraRoute/blob/main/Neo/README.md'>HydraRoute Neo<a> сделал для себя <a href='https://t.me/pegakmop'>@pegakmop</a> для личного использования, но подумав немного и решил поделиться и выложил в общий доступ, со временем думаю буду дорабатывать функционал...</p>
     <p>
  <button onclick="window.open('https://yoomoney.ru/to/410012481566554', '_blank')" style="padding: 0.5rem 1rem; font-size: 14px;">
     поддержать на ЮMoney
  </button>
</p>
<p>
  <button onclick="window.open('https://www.tinkoff.ru/rm/seroshtanov.aleksey9/HgzXr74936', '_blank')" style="padding: 0.5rem 1rem; font-size: 14px;">
     поддержать Тинькофф
  </button>
</p>
<p> текущая версия веб панели: v0.0.0.2
    <?php endif; ?>
  </main>

  <div id="modal" class="modal">
    <div class="modal-content">
      <h2>Добавить новую группу</h2>
      <form method="post" id="newGroupForm">
        <label for="new_policy_name">Имя новой группы без спец символов:</label>
        <input type="text" id="new_policy_name" name="new_policy_name" required />
        <div class="modal-buttons">
          <button type="button" id="cancelBtn">Отмена</button>
          <button type="submit">Добавить</button>
        </div>
      </form>
    </div>
  </div>

<script>
  const modal = document.getElementById('modal');
  const openBtn = document.getElementById('openModalBtn');
  const cancelBtn = document.getElementById('cancelBtn');

  openBtn.onclick = function() {
    modal.style.display = 'block';
    document.getElementById('new_policy_name').focus();
  };

  cancelBtn.onclick = function() {
    modal.style.display = 'none';
  };

  window.onclick = function(event) {
    if (event.target === modal) {
      modal.style.display = 'none';
    }
  };
</script>
</body>
</html>
EOF

if [ -f "$LIGHTTPD_CONF_FILE" ]; then
    echo "[*] Удаление конфигурации Lighttpd..."
    rm "$LIGHTTPD_CONF_FILE"
fi

echo "[*] Создание конфигурации Lighttpd..."
cat > "$LIGHTTPD_CONF_FILE" << 'EOF'
server.port := 8888
server.username := ""
server.groupname := ""

$HTTP["host"] =~ "^(.+):8888$" {
    url.redirect = ( "^/hrneo/" => "http://%1:88" )
    url.redirect-code = 301
}

$SERVER["socket"] == ":88" {
    server.document-root = "/opt/share/www/"
    server.modules += ( "mod_cgi" )
    cgi.assign = ( ".php" => "/opt/bin/php8-cgi" )
    setenv.set-environment = ( "PATH" => "/opt/bin:/usr/bin:/bin" )
    index-file.names = ( "index.php" )
    url.rewrite-once = ( "^/(.*)" => "/hrneo/$1" )
}
EOF

echo "[*] Установка прав и перезапуск..."
ln -sf /opt/etc/init.d/S99hrneo /opt/bin/hr
ln -sf /opt/etc/init.d/S80lighttpd /opt/bin/php
chmod +x "$INDEX_FILE"
/opt/etc/init.d/S80lighttpd enable
/opt/etc/init.d/S80lighttpd stop
/opt/etc/init.d/S80lighttpd restart
echo "[*] Установка завершена."
echo "[*] Установщик веб панели удален."
rm "$0"
echo ""
echo "HRNeo WebUI create @pegakmop installed"
echo ""
echo "Перейдите на http://<IP-роутера>:88"
echo ""
