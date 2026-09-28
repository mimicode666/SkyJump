# Разработка SkyJump

Для игры скачайте [готовый релиз](https://github.com/mimicode666/SkyJump/releases/latest). Этот раздел — для изменения исходников.

## Открыть проект

1. Установите Git LFS, Godot **4.6 standard** и Export Templates **4.6.stable**.
2. Клонируйте `https://github.com/mimicode666/SkyJump.git`, затем выполните `git lfs pull`.
3. Откройте `game/project.godot` в Godot. Импорт ресурсов выполняется автоматически.

Исходные архивы GitHub могут содержать LFS-указатели вместо моделей. Для разработки используйте клонирование; для игры — готовый релиз.

## Собрать Web

Из корня репозитория; `godot` — путь к Godot 4.6 или команда в PATH.

```sh
mkdir -p build/web
godot --headless --path game --import
godot --headless --path game --export-release Web ../build/web/index.html
node server-game.mjs
```

В PowerShell создайте папку через `New-Item -ItemType Directory -Force build/web`. Локальный Windows-движок: `.tools/godot/Godot_v4.6-stable_win64_console.exe`.

Откройте `http://127.0.0.1:4174/`. Node.js нужен только для этого способа разработки. Windows-ярлык `Играть в браузере.cmd` использует уже собранную `build/web/`. Для редактора есть `Открыть проект Godot.cmd`; он ожидает движок в `.tools/godot/`.

## Собрать готовые архивы Windows и Linux

На машине сборки нужны PowerShell, Godot 4.6 с шаблонами и Go **1.23+**. У Go-запускателя нет сторонних зависимостей. Игрокам эти инструменты не нужны.

```powershell
./build-portable.ps1 -Godot 'C:/path/to/godot.exe' -Go 'C:/path/to/go.exe'
```

Скрипт экспортирует актуальную Web-игру и собирает автономные запускатели Windows/Linux x64. Результат: `build/releases/v<версия>/`, два архива и `SHA256SUMS.txt`. Версия берётся из `package.json`. Параметр `-SkipExport` — только для повторной упаковки проверенного release-экспорта.

Запускатель отдаёт файлы экспорта на `127.0.0.1:4174`, открывает браузер и работает до закрытия окна. Постоянный адрес сохраняет доступ к прежнему браузерному профилю. При занятом порте другой сборкой предлагает закрыть её; порт автоматически не меняет.

Сборка для Яндекс Игр: `./build-yandex.ps1` → `build/SkyJump-Yandex.zip`. Это Web-архив для консоли платформы, без локального запускателя. Скрипты ничего не публикуют.

## Проверки и ресурсы

- `go test ./...` из `tools/launcher/` — сервер и неполные архивы; CI проверяет Windows и Linux.
- `node --test game/tests/yandex_bridge_test.mjs` — адаптер SDK без сети.
- Проверки игрового кода — [WEB.md](WEB.md), карта файлов — [AGENTS.md](../AGENTS.md).
- Рабочие модели: `assets/models/`. Оригиналы активных моделей: `source-models/`, исключены из импорта/экспорта.
- `prepare-characters.mjs <id>` подготавливает копии GLB без изменения текстур и анимаций. Зависимости из `package.json` нужны только для этого инструмента.

Экспорты, инструменты и снимки не коммитятся. Снятые модели сохранены локально в игнорируемом архиве; в текущем дереве Git — ресурсы актуальной игры.
