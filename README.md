# OpenRouterChat

AI-чат клиент для OpenRouter с поддержкой iOS 26 и macOS 26. Универсальное приложение с богатым функционалом для работы с большими языковыми моделями.

## Возможности

- **Множественные чаты** — ведите несколько независимых диалогов
- **Стриминг ответов** — ответы появляются в реальном времени
- **Агенты** — создавайте специализированных AI-ассистентов с системными промптами
- **MCP серверы** — подключайте внешние инструменты через Model Context Protocol
- **Локальный Whisper** — распознавание речи на устройстве без отправки аудио в облако
- **SwiftData** — надёжное локальное хранилище всех данных
- **Markdown** — форматирование сообщений с поддержкой кода
- **Кроссплатформенность** — единая кодовая база для iOS и macOS

## Требования

- iOS 26.0+ / macOS 26.0+
- Xcode 26.0+
- Swift 6.0+

## Архитектура

```
OpenRouterChat/
├── OpenRouterChatApp.swift   # Точка входа, SwiftData container
├── ContentView.swift          # Главный экран с вкладками
├── ChatViewModel.swift        # Бизнес-логика, стриминг, MCP, Whisper
├── OpenRouterService.swift    # Сетевой слой OpenRouter API
├── Models.swift               # SwiftData модели
└── Assets.xcassets/           # Ресурсы
```

## GitHub Actions

Проект использует GitHub Actions для CI/CD:

- **Build iOS 26** — сборка и тесты на iPhone 17 Pro Simulator
- **Build macOS 26** — сборка для macOS ARM64
- **UI Tests macOS 26** — UI-тесты на macOS
- **SwiftLint** — статический анализ кода

Все задачи выполняются на `macos-26` runner с Xcode 26.0.

## Настройка

1. Получите API ключ на [openrouter.ai](https://openrouter.ai)
2. Введите ключ в настройках приложения
3. Выберите модель и начните диалог

## Лицензия

MIT
