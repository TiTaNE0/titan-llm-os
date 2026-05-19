---
account: "[[accounts/titan_proxy/account]]"
persona: "[[personas/ru_devops]]"
variant_key: a
design: "[[design/cyber_overdrive]]"
voice: "[[voice/terminal_ru]]"
type: landing
status: active
source_of_truth: src/data/copy.ts (COPY_A, FAQ_A, STATUS_BADGE_A)
url_target: https://titanproxy.tech/
last_synced: 2026-05-19
---

# Landing — RU DevOps (Variant A)

## STATUS BADGE
`SYS_OK · TRAFFIC_NORMALIZATION · BBR_ACTIVE`

## HEADER
- **brand:** `TITAN_PROXY`

## HERO
- **preheader:** `[TITAN] // ОПТИМИЗАЦИЯ СЕТЕВОГО СТЕКА`
- **headlineLine1:** `ТЕЛЕГРАМ:`
- **headlineLine2:** `ОПТИМИЗИРОВАН.` (rendered with `--accent` cyan)
- **subhead:** `Магистральные узлы в Европе. Алгоритм TCP BBR. Оплата в XTR. Без фоновых процессов.`

## DIAG — `// АНАЛИЗ_СЕТИ`
3 cards:

| tag | title | desc |
|-----|-------|------|
| `[01]` | Устранение потери пакетов | Восстановление медиа-потоков при деградации пакетов на стороне провайдера. |
| `[02]` | Стабилизация джиттера | Выравнивание задержки (RTT) для мгновенной загрузки кружочков и HD-файлов. |
| `[03]` | Устойчивые сессии | Предотвращение принудительных разрывов соединений в часы пик. |

## OPERABILITY
- **works.label:** `[ШТАТНЫЙ_РЕЖИМ]`
- **works.list:**
  - Каналы и чаты
  - Фотографии
  - Голосовые сообщения
  - Видеосообщения (кружочки)
  - Тяжёлые файлы
- **notWorks.label:** `[ОГРАНИЧЕНО]`
- **notWorks.list:**
  - Аудиозвонки
  - Видеозвонки
- **footer of notWorks block:** `HARD_LIMITATION.long` from `src/data/tariffs.ts`

## CAPS — `// ТЕХНИЧЕСКИЙ_СТЕК`
4 cards:

| tag | title | body |
|-----|-------|------|
| `PROTOCOL` | Нормализация Handshake | Трафик инкапсулируется в соответствии со стандартами корпоративного шифрования (HTTPS). |
| `EDGE` | Узлы с поддержкой BBR | Высокопроизводительные серверы, эффективно работающие на шейпящихся каналах. |
| `ISOLATION` | Изолированные ключи сессий | Уникальные криптографические подписи для каждой сессии в тарифе Premium. |
| `BILLING` | Native XTR Routing | Атомарный биллинг внутри экосистемы Telegram. Без участия внешних шлюзов. |

## ARCH — `// АРХИТЕКТУРА_МАРШРУТИЗАЦИИ`
3 steps:

| tag | title | desc |
|-----|-------|------|
| `[STEP_01]` | Управление перегрузками | Оптимизация маршрутов в реальном времени через магистральные оптоволоконные каналы. |
| `[STEP_02]` | Маскировка полезной нагрузки | Устранение энтропии протокола для соответствия паттернам стандартного HTTPS. |
| `[STEP_03]` | Минимальное число хопов | Прямой пиринг с ключевыми дата-центрами сокращает общую задержку. |

## TIERS — `// ТАРИФНЫЕ_ПЛАНЫ`
- **recommended:** `[РЕКОМЕНДУЕТСЯ]`
- **footer:** `Активация в @TitanTGProxy_bot · 30 дней`
- **warning:** `⚠ МАРШРУТИЗАЦИЯ ЗВОНКОВ ОТКЛЮЧЕНА НА ВСЕХ ТАРИФАХ.`
- **tier data:** from `src/data/tariffs.ts` (Basic / Family / Premium) — NEVER duplicated here

## FAQ — `// БАЗА_ЗНАНИЙ`

| id | q | a |
|----|---|---|
| `a.faq.1` | Почему в 2026 году медиа в Telegram грузится медленно? | Стандартные сетевые узлы часто перегружены или подвергаются фильтрации. Titan использует BBR-узлы для приоритизации доставки контента. |
| `a.faq.2` | Влияет ли это на производительность мобильного устройства? | Нет. Поскольку оптимизация происходит на уровне сетевого стека приложения, нагрузка на процессор и аккумулятор отсутствует. |
| `a.faq.3` | Насколько безопасна оплата через Stars? | Оплата производится нативно через платформу Telegram, что исключает передачу ваших платежных данных третьим лицам. |

## FOOTER
- **bot:** `// @TitanTGProxy_bot`
- **nodes:** `// ПРЕМИУМ-НОДЫ В ЕВРОПЕ`

## CTA
- One button. Component: `<CTA variant="a" />`.
- Behavior: routes to `tg://proxy?...` for real users (server-injected hourly), or `t.me/TitanTGProxy_bot` for SEO bots.
