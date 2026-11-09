# prot для Garry’s Mod

Серверный бинарный модуль на Rust со встроенным GLua-роутером. `ProtNative.Seed()` возвращает один случайный 128-битный seed на время жизни загруженного модуля. При полном перезапуске сервера seed генерируется заново.

Аддоны могут продолжать вызывать `util.AddNetworkString`, `net.Start` и `net.Receive` с исходными именами. После загрузки `000_prot.lua` новые регистрации получают имена вида `prot_net_<32 hex>`. Клиент читает seed из служебной записи в таблице сетевых строк и вычисляет имя из `seed .. ":" .. name:lower()`. Seed и итоговые имена доступны подключённому клиенту. Проверки прав, длины пакетов и частоты запросов выполняются в обработчиках приложения.

## Сборка

В корне проекта используется Rust nightly из `rust-toolchain.toml`.

**Windows** с Visual Studio Build Tools и компонентами MSVC для x86 и x64.

```powershell
rustup target add i686-pc-windows-msvc x86_64-pc-windows-msvc
cargo build --locked --release --target i686-pc-windows-msvc
cargo build --locked --release --target x86_64-pc-windows-msvc
```

**Linux** или WSL. Для i686 на Debian/Ubuntu нужны `gcc-multilib` и `libc6-dev-i386`.

```sh
rustup target add i686-unknown-linux-gnu x86_64-unknown-linux-gnu
cargo build --locked --release --target i686-unknown-linux-gnu
cargo build --locked --release --target x86_64-unknown-linux-gnu
```

Скопируй файл из `target/<target>/release/` в `garrysmod/lua/bin/` под именем из последней колонки.

| Цель | Файл Cargo | Имя для GMod |
| --- | --- | --- |
| `i686-pc-windows-msvc` | `prot.dll` | `gmsv_prot_win32.dll` |
| `x86_64-pc-windows-msvc` | `prot.dll` | `gmsv_prot_win64.dll` |
| `i686-unknown-linux-gnu` | `libprot.so` | `gmsv_prot_linux.dll` |
| `x86_64-unknown-linux-gnu` | `libprot.so` | `gmsv_prot_linux64.dll` |

Готовые файлы лежат в `dist/`. На Linux GMod ищет файл с расширением `.dll`, внутри которого находится ELF `.so`. Разрядность выбирается по процессу сервера. Готовые Linux-сборки требуют glibc 2.34 или новее.

## Подключение

Для новой установки скачай `prot-server.zip` из раздела Releases и распакуй в корень сервера. Вручную достаточно положить подходящий модуль в `garrysmod/lua/bin/` и скопировать `addon/lua/autorun/000_prot.lua` в `garrysmod/lua/autorun/`.

При обновлении установленного аддона замени серверный бинарник и существующий `000_prot.lua` в его текущей папке. Останови сервер перед заменой, затем запусти его из каталога, в котором лежит папка `garrysmod`. Серверу нужна запись в `garrysmod/lua/prot/`. При запуске модуль создаёт или обновляет `embedded_router.lua`, выполняет встроенную копию на сервере и отправляет Lua клиентам через `AddCSLuaFile`. Для старых вызовов `include("prot/router.lua")` модуль при необходимости создаёт совместимый загрузчик.

Автоматический режим действует на каналы, зарегистрированные через Lua после раннего autorun. Служебные строки, которые регистрируют `player_manager.RegisterClass` и `drive.Register`, сохраняют исходные имена. Каналы, уже внесённые в таблицу к моменту загрузки роутера, тоже используют исходные имена. Бинарные модули, которые напрямую работают с таблицей движка, обходят Lua-обёртки. Автоматическая регистрация занимает один слот на канал и один дополнительный слот на маркер seed.

`ProtNet.WireName(name)` возвращает имя в сетевой таблице. `util.NetworkStringToID(name)` работает с логическим именем. При приёме пакета GMod ищет обработчик в `net.Receivers` по исходному имени, поэтому обычные `net.Receive` и прямой доступ к таблице обработчиков работают вместе.

Явный API `ProtNet.Register`, `ProtNet.Receive` и `ProtNet.Start` также доступен. У него собственные имена вида `prot_<32 hex>`, лимит 256 маршрутов и синхронизация через `prot_bootstrap_v1`. `ProtNet.Name(name)` показывает имя явного маршрута, а `ProtNet.Ready(ply)` на сервере и `ProtNet.Ready()` на клиенте сообщают о готовности явного роутера.

## Проверка в игре

Скопируй `examples/prot_auto_ping.lua` в `garrysmod/addons/prot/lua/autorun/`, запусти сервер, подключись и выполни `prot_auto_ping` в клиентской консоли. Ответ должен содержать `[prot] auto pong`, число `1234` и имя `prot_net_...`. После полного перезапуска сервера имя канала должно измениться. `examples/prot_ping.lua` проверяет явный API отдельно.

Чтобы проверить канал существующего аддона, выполни в консоли сервера `lua_run print(ProtNet.WireName("имя.канала"))`. Результат `prot_net_...` показывает автоматическое переименование.

Документация [Facepunch по модулям Rust](https://wiki.facepunch.com/gmod/Creating_Binary_Modules:_Rust), [C Lua API](https://wiki.facepunch.com/gmod/C_Lua:_Functions), [gmod-rs](https://docs.rs/gmod/17.0.1/gmod/).
