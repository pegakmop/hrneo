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
opkg update

echo "[*] Установка Lighttpd + PHP8 + PHP8-cli..."
opkg install lighttpd lighttpd-mod-cgi php8 php8-cgi php8-cli php8-mod-curl lighttpd-mod-setenv lighttpd-mod-redirect php8-mod-session lighttpd-mod-rewrite jq php8-mod-openssl

echo "[*] Создание директорий..."
mkdir -p "$HRNEO_DIR"
mkdir -p "$LIGHTTPD_CONF_DIR"

echo "[*] Создание manifest.json..."
cat > "$MANIFEST_FILE" << 'EOF'
{
  "name": "HydraRoute Neo",
  "short_name": "hr neo",
  "start_url": "/hrneo/",
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

echo "[*] Создание index.php..."
cat > "$INDEX_FILE" << 'EOF'
<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
    if (isset($_POST['run'])) {
        $output = exec('reboot');
        echo "<pre>Результат команды neo restart:\n" . htmlspecialchars($output) . "</pre>";
    }
$confPath = '/opt/etc/HydraRoute/domain.conf';
$ipListPath = '/opt/etc/HydraRoute/ip.list';
$message = '';

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
            $message = "❗ Группа не выбрана или не найдена.";
        }
    }
}
?>

<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<link rel="manifest" href="manifest.json">
<title>HR Neo WebUI created by @pegakmop</title>
<style>
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
    height: 400px;
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
    background-color: rgba(0,0,0,0.6);
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
</style>
</head>
<body>

  <nav class="sidebar">
    <h3><button style="font-size:12px;" onclick="history.back();return false;">HRNeo</button></h3>
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
    <button class="add-new-btn" id="openModalBtn">Добавь группу</button>
    <p></p>
    <form method="post">
        <button type="submit" name="run">⚠️reboot</button>
    </form>
  </nav>

  <main>
    <?php if ($message): ?>
      <div class="message"><?=htmlspecialchars($message)?></div>
    <?php endif; ?>

    <?php if ($currentPolicy || $isAll || $isIPList): ?>
      <form method="post">
        <input type="hidden" name="policy" value="<?=htmlspecialchars($currentPolicy)?>" />
        <textarea name="content" spellcheck="false"><?=htmlspecialchars($currentContent)?></textarea>
        <button type="submit">Сохранить и перезапустить</button>
      </form>
    <?php else: ?>
      <p>Выберите группу слева или &laquo;Все группы&raquo; для редактирования доменов.</p> 
      <p>Выберите Подсети слева и &laquo;ip.list&raquo; для редактирования подсетей.</p>
      <p>Для работы подсетей neo stop, сменить CIDR с false на true в hrneo.conf и перезагрузить роутер</p>
      <p>Тестовый вариант веб интерфейса для проекта HydraRoute Neo сделал @pegakmop для личного использования</p>
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

rm "$LIGHTTPD_CONF_FILE"
echo "[*] Создание конфигурации Lighttpd..."
cat > "$LIGHTTPD_CONF_FILE" << 'EOF'
server.port := 8088
server.username := ""
server.groupname := ""

$HTTP["host"] =~ "^(.+):8088$" {
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

chmod +x "$INDEX_FILE"
/opt/etc/init.d/S80php8-fastcgi enable
/opt/etc/init.d/S80php8-fastcgi start
/opt/etc/init.d/S80lighttpd enable
/opt/etc/init.d/S80lighttpd restart

echo "✅ HRNeo WebUI установлен! Перейдите на http://<IP-роутера>:88/hrneo/"
