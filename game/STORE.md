# SkyJump: поля карточки Яндекс Игр

Языки игры: русский и английский. Русский — локальный язык по умолчанию; на платформе язык выбирается через SDK при запуске.

## Теги

Рекомендуемые по содержанию игры; выбрать соответствующие варианты из списка консоли:

3D, аркада, платформер, прыжки, на ловкость, казуальная, бесконечная, для одного игрока, мультяшная, космос, сбор монет, персонажи.

Не указывать онлайн-лидерборд, мультиплеер или облачные сохранения: они пока не подключены.

## Ключевые слова

Готовая строка, 96 символов, нижний регистр и запятые:

skyjump, дудл джамп, doodle jump, 3d, прыжки, платформер, аркада, космос, джетпак, монеты, скины

Поле общее, не требует отдельной английской строки. Doodle Jump указан как ориентир похожего геймплея, не как название или принадлежность нашей игры.

## Сохранение данных

«Игра использует облачные сохранения»: выключено. Монеты, покупки, рекорды, звук и таймер ×2 сохраняются локально. Web — `user://wallet.cfg` в IndexedDB и синхронное зеркало localStorage; native — файл. `Player.getData/setData/setStats` не используются. Прогресс между устройствами не синхронизируется.

## Источники и оставшаяся проверка

[Автоопределение языка, пункт 2.14](https://yandex.ru/dev/games/doc/ru/requirements/2/14), [резервный язык](https://yandex.ru/dev/games/doc/ru/concepts/languages-and-domains), [поля черновика](https://yandex.ru/dev/games/doc/ru/console/add-new-game/draft), [хранилище Player](https://yandex.ru/dev/games/doc/ru/sdk/sdk-player#sdk-player__ingame-data).

В консоли допускается до 20 тегов; ключевые слова — до 100 символов. После создания черновика нужно проверить оба языка через SDK mocks и I18N is used; локальные проверки не заменяют проверку настоящего SDK.

## Тексты карточки

Проверенные значения также сохранены в [store-listing.json](store-listing.json).

### Русский

**Название**

SkyJump

**Описание для SEO**

3D-аркада с прыжками по платформам: собирайте монеты, открывайте героев и летите с джетпаком от облаков к галактикам. Попробуйте подняться выше!

**Об игре**

SkyJump — 3D-аркада с автоматическими прыжками и путешествием от земли к далёкому космосу. Выберите героя и поднимайтесь по разноцветным платформам, собирая монеты и открывая новых персонажей.

На пути встретятся движущиеся платформы, пружины для высоких прыжков, хрупкий камень и опасные шипы. Редкий джетпак поднимет вас ещё выше и притянет монеты поблизости. Чем дальше вы заберётесь, тем быстрее станет игра.

Земля сменяется дождём и снегом, затем появляются облака, закат, звёздная ночь, Луна и галактики. Маршрут каждый раз новый, а цель проста: удержаться на платформах и побить свой рекорд.

**Короткое описание**

Прыжки по платформам, новые герои и путешествие к галактикам!

**Как играть**

Персонаж прыгает автоматически. Ваша задача — направлять его на платформы и подниматься как можно выше.

На компьютере используйте A/D или стрелки влево/вправо. На сенсорном экране коснитесь любого места и сдвигайте палец влево или вправо. Направление меняется сразу вслед за движением пальца, без возврата к центру. Отпустите палец, чтобы остановиться. При выходе за боковой край герой появляется с противоположной стороны.

Синие платформы движутся, розовые пружины усиливают прыжок, а каменные платформы ломаются после второго приземления. Избегайте красных платформ с шипами. Подбирайте монеты для покупки персонажей и джетпак для высокого полёта с притяжением монет.

Если герой упадёт за нижний край игрового экрана или коснётся шипов, забег закончится. Попробуйте снова и улучшите рекорд! Пауза — кнопка на экране или Esc, повтор после падения — кнопка «Ещё раз» или R.

### Английский

**Название**

SkyJump

**Описание для SEO**

3D platform-jumping arcade: collect coins, unlock characters and fly from the clouds to distant galaxies with a jetpack. See how high you can go!

**Об игре**

SkyJump is a 3D arcade game with automatic jumping and an endless journey from Earth to distant galaxies. Choose a character, climb colourful platforms, collect coins and unlock new heroes.

Look out for moving platforms, springs that boost your jumps, crumbling stone and dangerous spikes. A rare jetpack carries you higher and attracts nearby coins. The higher you climb, the faster the game becomes.

Travel through rain and snow, rise above the clouds, watch the sunset and reach a starry night, the Moon and distant galaxies. Every run brings a new route. Stay on the platforms and beat your personal best!

**Короткое описание**

Jump across platforms, unlock characters and reach the galaxies!

**Как играть**

Your character jumps automatically. Steer onto platforms and climb as high as you can.

On a computer, use A/D or the left and right arrow keys. On a touchscreen, touch anywhere and slide your finger left or right. Changing your finger movement immediately changes direction, with no need to return to the centre. Lift your finger to stop. Crossing a side edge brings you back on the opposite side.

Blue platforms move, pink springs boost your jumps, and stone platforms break after the second landing. Avoid red platforms with spikes. Collect coins to buy characters and pick up a jetpack for a high flight that attracts nearby coins.

The run ends if you fall below the bottom of the gameplay screen or touch spikes. Try again and beat your best! Pause with the on-screen button or Esc. After a fall, press «Try again» or R to restart.

## Медиа

Локальная папка build/promotion/: для ru/en подготовлены горизонтальный MP4 1280×720 и вертикальный MP4 720×1280, 23,5 секунды, H.264/AAC, менее 6 МБ каждый. По два реальных игровых PNG для каждой ориентации, RGB 24 бит. Иконка и обложка: assets/skyjump-icon-512.png и assets/skyjump-cover-800x470.png; общие для обоих языков. Материалы размещаются только в черновике, без модерации/публикации.
