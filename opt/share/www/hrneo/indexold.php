<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
$confPath = '/opt/etc/HydraRoute/domain.conf';
$message = '';

$full = file_get_contents($confPath);
preg_match_all('/##(.+?)\n(.*?)\/HydraRoute/s', $full, $m, PREG_SET_ORDER);
$policies = [];
foreach ($m as $e) $policies[trim($e[1])] = trim($e[2]);

$current = $_GET['policy'] ?? '';
$currentContent = $current && isset($policies[$current]) ? $policies[$current] : $full;
if ($current && !isset($policies[$current])) $message = "Политика «$current» не найдена.";

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $content = $_POST['content'] ?? '';
    $newFull = $current && isset($policies[$current])
        ? preg_replace("/##".preg_quote($current,'/')."\n.*?\/HydraRoute/s", "##$current\n".$content."\n/HydraRoute", $full)
        : $content;

    if (file_put_contents($confPath, $newFull) !== false) {
        shell_exec('/opt/etc/init.d/S99hrneo stop');
        shell_exec('ipset flush HydraRoute');
        shell_exec('ipset flush HydraRoutev6');
        shell_exec('/opt/etc/init.d/S99hrneo restart');
        $message = "✔ Сохранено и перезагружено.";
        $full = $newFull;
    } else {
        $message = "❗ Ошибка при сохранении.";
    }
}
?>
<!DOCTYPE html>
<html lang="ru" >
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <link rel="apple-touch-icon" href="apple-touch-icon.png">
  <link rel="manifest" href="manifest.json">
  <title>HydraRoute Neo WebUI</title>
  <style>
    /* Скопировано и адаптировано из https://raw.githubusercontent.com/Ground-Zerro/HydraRoute/main/Classic/webui/public/style.css */

    @import url('https://fonts.googleapis.com/css?family=Roboto:300,400,500,700&display=swap');

    * {
      box-sizing: border-box;
    }

    body {
      font-family: 'Roboto', sans-serif;
      margin: 0;
      background: #1e1e2f;
      color: #e0e0e0;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }

    .navbar {
      background-color: #292c42;
      padding: 1rem 2rem;
      font-weight: 700;
      font-size: 1.5rem;
      color: #68b0ab;
      user-select: none;
      flex-shrink: 0;
    }

    .container {
      display: flex;
      flex: 1 1 auto;
      min-height: 0;
      overflow: hidden;
    }

    .sidebar {
      width: 260px;
      background: #292c42;
      padding: 1rem 0;
      overflow-y: auto;
      border-right: 1px solid #444;
      flex-shrink: 0;
    }

    .sidebar-list {
      list-style: none;
      padding: 0;
      margin: 0;
    }

    .sidebar-list li {
      margin: 0;
    }

    .sidebar-list a {
      display: block;
      padding: 12px 24px;
      text-decoration: none;
      color: #aaa;
      font-weight: 500;
      transition: background-color 0.2s, color 0.2s;
      cursor: pointer;
    }

    .sidebar-list a.active, .sidebar-list a:hover {
      background: #68b0ab;
      color: #1e1e2f;
      font-weight: 700;
    }

    .content {
      flex-grow: 1;
      padding: 1rem 2rem;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }

    form {
      display: flex;
      flex-direction: column;
      height: 100%;
    }

    textarea {
      flex-grow: 1;
      font-family: monospace;
      font-size: 0.9rem;
      background: #1e1e2f;
      color: #e0e0e0;
      border: 1px solid #444;
      border-radius: 4px;
      padding: 10px;
      resize: none;
      min-height: 400px;
      margin-bottom: 1rem;
      overflow: auto;
      transition: border-color 0.2s;
    }

    textarea:focus {
      outline: none;
      border-color: #68b0ab;
      background: #252538;
    }

    button.btn {
      background: #68b0ab;
      border: none;
      padding: 12px 24px;
      color: #1e1e2f;
      font-weight: 700;
      font-size: 1rem;
      border-radius: 4px;
      cursor: pointer;
      transition: background-color 0.3s;
      align-self: flex-start;
    }

    button.btn:hover {
      background: #55958f;
    }

    .alert {
      background: #33394a;
      border: 1px solid #68b0ab;
      padding: 0.8rem 1rem;
      margin-bottom: 1rem;
      border-radius: 4px;
      color: #68b0ab;
      font-weight: 500;
      white-space: pre-wrap;
      user-select: text;
    }

    /* Адаптив для мобильных */
    @media (max-width: 768px) {
      .container {
        flex-direction: column;
      }
      .sidebar {
        width: 100%;
        height: auto;
        border-right: none;
        border-bottom: 1px solid #444;
      }
      .sidebar-list a {
        padding: 10px;
        text-align: center;
        font-size: 1rem;
      }
      .content {
        padding: 1rem;
        height: auto;
      }
      textarea {
        min-height: 250px;
      }
      button.btn {
        width: 100%;
        padding: 14px;
        font-size: 1.1rem;
      }
    }
  </style>
</head>
<body>
  <nav class="navbar">HydraRoute Neo</nav>
  <div class="container">
    <aside class="sidebar">
      <ul class="sidebar-list">
        <?php foreach ($policies as $name => $_): ?>
          <li><a href="?policy=<?=urlencode($name)?>" class="<?= ($name === $current ? 'active' : '') ?>"><?=htmlspecialchars($name)?></a></li>
        <?php endforeach; ?>
        <li><a href="?" class="<?= (!$current ? 'active' : '') ?>">Всё показать</a></li>
      </ul>
    </aside>
    <main class="content">
      <?php if ($message): ?>
        <div class="alert"><?=htmlspecialchars($message)?></div>
      <?php endif; ?>
      <form method="post">
        <textarea name="content" spellcheck="false"><?=htmlspecialchars($currentContent)?></textarea>
        <button type="submit" class="btn">Сохранить и перезапустить</button>
      </form>
    </main>
  </div>
</body>
</html>
