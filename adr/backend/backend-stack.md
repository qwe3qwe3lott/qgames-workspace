# Стек бэкенда

Область: backend · Диаграммы: [c4/3-backend](../c4/3-backend.md) · Код: `backend/gradle/libs.versions.toml`

## Контекст

Нужен стек, на котором один разработчик быстро пишет и отлаживает код, с долгой поддержкой и умеренным потреблением памяти.

## Решение

Kotlin 2.4, JDK 25+ (байткод Java 25), Gradle 9.6 (configuration cache), **Spring Boot 4.1 на Spring MVC + virtual threads**, Jackson 3, Spring Modulith 2.1, springdoc 3.1, Exposed 1.6, PostgreSQL 18, Liquibase, Testcontainers 2, springmockk 5. Версии лежат в `gradle/libs.versions.toml`, всё, чем управляет BOM Spring Boot, — без версий.

## Рассмотренные варианты

| Вариант | Почему нет |
|---|---|
| Spring Boot 3.5 | Предыдущая линейка, срок поддержки короче |
| WebFlux + корутины | Сложнее в разработке и отладке, нужен R2DBC |

## Последствия

- Блокирующий код на virtual threads: SSE-потоки не держат платформенные потоки.
- Сборка требует JDK ≥ 25 без toolchain.
