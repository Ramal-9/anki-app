# Anki Flow

Карточки для запоминания слов в стиле Anki на **Flutter Web**: интервальные повторения (SM-2), тёмный интерфейс, **AI Practice** для тренировки произношения и **подсказки устойчивых фраз** при добавлении нового слова.

## Возможности

| Экран | Что есть |
|---|---|
| **Queue** | Градиентная карточка «In your queue» (сколько карточек готово, ~минут, new/review, прогресс дневной цели), кнопка *Study cards*, колоды, очередь с сортировкой (Due Date / Deck / Recently Added) |
| **Library** | Decks / Folders (умные папки: все, на сегодня, новые, трудные, за неделю), счётчики new/learning/review, создание колоды, кнопка ✨ для AI Practice любой фразы |
| **Колода** | Статистика, список карточек со статусом и сроком («in 2 weeks»), меню: Add Card, Import, Review, Quiz, Settings; кнопка *Study N cards* |
| **Изучение** | Quit, «0 of 29», вопрос → *Show answer* 👀 → Again / Hard / Good / Easy с интервалами, кнопка ᴀA (размер текста), озвучка, AI Practice прямо с карточки. Горячие клавиши: Space, 1–4 |
| **New Card** | Front (язык) / Back, картинка по URL, диктовка голосом, ✨ подсказки фраз, AI Practice, 👀 «создать обратную карточку» |
| **Insights** | Retention trend (7D/30D/90D/All, цель 90 %, линия 70 %), тепловая карта активности, прогноз повторений, итоги |
| **Account** | Email, Sync (экспорт/импорт JSON), настройки SM-2, дневная цель, уведомления, акцент и скорость голоса, тёмная/светлая тема и т. д. |

### AI Practice (проверка произношения)
1. Слово или предложение читает «носитель» — голос браузера (Web Speech API, `speechSynthesis`), акцент UK / US / AU, режим 🐢 медленно.
2. Нажимаете микрофон и повторяете.
3. Браузер распознаёт речь (`SpeechRecognition`), приложение выравнивает услышанное с эталоном по словам (взвешенное расстояние Левенштейна) и ставит оценку 0–100. Слова подсвечиваются: зелёный — верно, оранжевый — близко, красный — неверно/пропущено. Нажмите на слово, чтобы послушать его отдельно.

Работает в **Chrome, Edge, Safari (iOS 14.5+)**. Firefox не умеет распознавать речь. Нужен HTTPS (GitHub Pages подходит) и разрешение на микрофон.

### Подсказки устойчивых фраз
При вводе слова на лицевой стороне карточки появляется блок **Useful phrases & collocations**:
- встроенный офлайн-словарь (~120 слов, 4–8 частых сочетаний с переводом на русский) — `lib/data/collocations.dart`, легко расширять;
- если в словаре мало вариантов, подтягиваются частые сочетания из бесплатного API [Datamuse](https://www.datamuse.com/api/) (без ключа; отключается в Account → Online phrase suggestions);
- нажатие на фразу добавляет её в ответ как пример, ➕ создаёт отдельную карточку.

Чтобы подключить другой источник (например, LLM), реализуйте `OnlineSuggestionProvider` в `lib/services/suggestions.dart`.

## Запуск локально

```bash
flutter pub get
flutter run -d chrome
```

Тесты логики (SM-2, оценка произношения, подсказки):

```bash
flutter test
```

Все данные хранятся в `localStorage` браузера. При первом запуске загружаются демо-колоды *English* и *Olympiad* с историей повторений; сбросить или стереть их можно в Account → ··· .

## Публикация на GitHub Pages

1. Создайте репозиторий на GitHub и загрузите в него эту папку:
   ```bash
   git init
   git add .
   git commit -m "Anki Flow"
   git branch -M main
   git remote add origin https://github.com/<ваш-логин>/<репозиторий>.git
   git push -u origin main
   ```
2. В репозитории: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. Workflow `.github/workflows/deploy.yml` сам соберёт приложение и опубликует его по адресу
   `https://<ваш-логин>.github.io/<репозиторий>/` после каждого push в `main` (вкладка **Actions** показывает ход сборки).

Собрать вручную:

```bash
flutter build web --release --base-href /<репозиторий>/
# содержимое build/web можно выложить на любой статический хостинг
```

## Структура

```
lib/
  main.dart                    приложение, нижняя навигация
  theme.dart                   цвета, градиенты, название (AppConfig.appName)
  models.dart, srs.dart        модель карточек и планировщик SM-2
  store.dart                   состояние + сохранение в localStorage, демо-данные
  data/collocations.dart       офлайн-словарь фраз
  services/speech.dart         Web Speech API (озвучка и распознавание)
  services/pronunciation.dart  оценка произношения
  services/suggestions.dart    подсказки фраз (офлайн + Datamuse)
  screens/                     queue, library, deck, study (+quiz), card_editor, ai_practice, insights, profile, search
test/logic_test.dart
```

Название и автор меняются в `lib/theme.dart` (`AppConfig`).
