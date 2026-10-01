extends RefCounted
## Local translations; Russian source messages remain the offline default.
const EN = {
	"ПРЫЖОК В ОБЛАКА": "JUMP INTO THE CLOUDS",
	"ВЫШЕ ОБЛАКОВ": "ABOVE THE CLOUDS",
	"‹ В меню": "‹ Menu",
	"Выберите, кто сегодня прыгнет выше": "Choose who will jump higher today",
	"От земли до далёких галактик": "From Earth to distant galaxies",
	"Нажмите, чтобы выбрать героя": "Tap to choose a character",
	"Прыгать!": "Jump!",
	"Рекорды": "Records",
	"0 м": "0 m",
	"%d м": "%d m",
	"Пауза": "Pause",
	"Джетпак": "Jetpack",
	"Стрелки или A / D       ·       Esc — пауза": "Arrows or A / D       ·       Esc to pause",
	"Продолжить": "Resume",
	"Ещё раз": "Try again",
	"Главное меню": "Main menu",
	"Подождите…": "Please wait…",
	"Сдвигайте палец влево или вправо\nПрыжки — автоматически": "Slide your finger left or right\nJumping is automatic",
	"A / D или стрелки — движение\nПрыжки — автоматически": "A / D or arrows to move\nJumping is automatic",
	"Не удалось открыть модель. Проверьте папку assets/models.": "Could not load the character. Check assets/models.",
	"Персонаж: %s": "Character: %s",
	"Звук: вкл.": "Sound: on",
	"Звук: выкл.": "Sound: off",
	" · доступен": " · available",
	" · куплен": " · owned",
	"%s\n%d монет%s": "%s\n%d coins%s",
	"В меню": "Menu",
	"Выбрать": "Select",
	"Не хватает %d монет": "Need %d more coins",
	"Купить за %d монет": "Buy for %d coins",
	"Персонажи": "Characters",
	"Готово": "Done",
	"Рекорд за всё время": "All-time best",
	"Список лучших": "Leaderboard",
	"Вы": "You",
	"Рекорд: %d м": "Best: %d m",
	"Просмотр рекламы…": "Ad in progress…",
	"Пауза\nВернитесь в игру": "Paused\nReturn to the game",
	"×2 на 10 минут\nЗа рекламу": "×2 for 10 minutes\nWatch an ad",
	"Монеты ×2\nНедоступно": "Coins ×2\nUnavailable",
	"Продолжить за рекламу": "Watch an ad to continue",
	"Продолжить за рекламу\nНедоступно": "Continue with an ad\nUnavailable",
	"Ожидаем просмотр…": "Waiting for ad…",
	"Награда не получена. Попробуйте ещё.": "No reward received. Try again.",
	"Высота: %d м\nНаграда не получена.\nПопробуйте ещё.": "Height: %d m\nNo reward received.\nTry again.",
	"Передохнём?": "Take a break?",
	"Высота: %d м": "Height: %d m",
	"Ещё один прыжок?": "One more jump?",
	"Высота: %d м\nРекорд: %d м\nСобрано монет: %d": "Height: %d m\nBest: %d m\nCoins collected: %d",
	"Как играть": "How to play",
	"Сдвигайте палец влево или вправо\nБез возврата к центру": "Slide your finger left or right\nNo need to return to the centre",
	"Палец влево\nГерой влево": "Slide left\nMove left",
	"Палец вправо\nГерой вправо": "Slide right\nMove right",
	"Отпустите палец, чтобы остановиться\nПрыжки — автоматически\nКлавиатура: A / D или стрелки": "Lift your finger to stop\nJumping is automatic\nKeyboard: A / D or arrow keys",
	"Понятно, играем!": "Got it, let's play!",
	"Монеты: %d%s": "Coins: %d%s",
	" (временно)": " (temporary)",
	"Пикачу": "Pikachu",
	"Яблочко": "Apple",
	"Пингвин": "Penguin",
	"Миньон": "Minion",
	"Зайчик": "Bunny",
	"Клубнич Джунгариков": "Klubnich Dzhungarikov",
	"Манье": "Manye",
	"Кирби": "Kirby",
	"Синнаморол": "Cinnamoroll",
}

static func install() -> void:
	for locale in ["ru", "en"]:
		var translation := Translation.new()
		translation.locale = locale
		for message in EN: translation.add_message(message, EN[message] if locale == "en" else message)
		TranslationServer.add_translation(translation)
	TranslationServer.set_locale("ru")

static func locale_for(language: String) -> String:
	var code := language.to_lower().replace("_", "-").get_slice("-", 0)
	# Yandex recommends Russian for these neighbours, English for other locales.
	return "ru" if code in ["", "ru", "be", "kk", "uk", "uz"] else "en"

static func apply(language: String) -> void:
	TranslationServer.set_locale(locale_for(language))
