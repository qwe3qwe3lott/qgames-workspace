# Контракт API

Область: backend, frontend · Диаграммы: [c4/2-containers](../c4/2-containers.md) · Код: `backend/<m>/<m>-api` (`@HttpExchange`), `backend/app/.../OpenApiConfig`, `backend/libs/common-web`

## Контекст

Фронт генерирует клиент по OpenAPI, поэтому документ должен быть точным (`required`, nullable, union) и стабильным. У портала и админки разные пользователи и ручки, а приложение одно. UI должен различать ошибки без разбора текстов.

## Решение

- **REST/JSON**, контракт — интерфейсы и DTO `<m>-api`, опубликованные **двумя группами OpenAPI**: `portal` (`/api/**` кроме `/api/admin/**`) и `admin` (`/api/admin/**`). Swagger один, с выбором группы.
- **Ошибки — `ProblemDetail` с машиночитаемым `code`**, коды — часть контракта. UI ветвится только по `code`.
- Swagger на русском: у каждой ручки `@Operation`, `@ApiResponses` со всеми статусами и кодами ошибок, теги латиницей (по ним Orval раскладывает файлы).
- `required` выводится из nullability Kotlin (`KotlinRequiredPropertiesConverter`). Полиморфные DTO — `oneOf` + `discriminator` без `allOf` (`DiscriminatedUnionCustomizer`). Ключи документа отсортированы.
- Токенов в контракте нет: они живут в куках ([session-tokens](../security/session-tokens.md)).
- Форму контракта проверяют `PortalOpenApiContractScenariosTest` и `AdminOpenApiContractScenariosTest`.

## Рассмотренные варианты

| Вариант | Почему нет |
|---|---|
| `@Schema(requiredMode = REQUIRED)` на каждом поле DTO | Легко забыть на новом поле, много шума |

## Последствия

- Изменение контракта видно в диффе сгенерированного клиента фронта ([api-client-generation](api-client-generation.md)).
- Ограничения генерации (регулярки `\p{…}` без флага `u`, `nullish` в Zod) фронт обходит с комментариями (см. `frontend/CLAUDE.md` §5).
- Правила оформления ручек — `backend/CLAUDE.md` §3.
