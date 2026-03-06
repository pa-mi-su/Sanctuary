# Sanctuary App Modernization Blueprint

## 1. Goals
- Rebuild Sanctuary with clean architecture and SOLID boundaries.
- Keep iOS delivery moving while enabling future Android/Java client reuse.
- Move canonical content and user progress to AWS-backed backend.
- Support incremental migration from local JSON to API without blocking UI work.

## 2. Guiding Principles
- Single Responsibility: UI, domain, data, and infrastructure layers stay isolated.
- Open/Closed: new providers (local, API, cache) added via interfaces, not screen rewrites.
- Liskov: each repository implementation must satisfy identical contracts.
- Interface Segregation: split read-only content APIs from mutable user progress APIs.
- Dependency Inversion: feature logic depends on protocols, not storage/network libraries.

## 3. Target High-Level Architecture
- Presentation layer: screens/view models.
- Application layer: use-cases (query/filter/sync/track progress).
- Domain layer: entities + value objects + policies.
- Data layer: repository interfaces and implementations.
- Infrastructure layer: REST API client, auth adapter, caching, persistence.

### App-side Repository Pattern
- `ContentRepository`: saints, novenas, prayers, liturgical calendar data.
- `UserProgressRepository`: favorites, novena commitments, reminders preferences.
- `SearchRepository`: full-text and faceted search abstraction.

Implementations:
- `LocalContentRepository` (bootstrap JSON fallback).
- `ApiContentRepository` (AWS API).
- `LocalUserProgressRepository` (temporary AsyncStorage equivalent for native app).
- `ApiUserProgressRepository` (authoritative user state).

## 4. Canonical Domain Model (Shared Across Clients)
- `Saint`
  - id, slug, name, feastDate, patronages, biography, imageUrl, tags, locales.
- `Novena`
  - id, slug, title, description, durationDays, startRules, prayerDays, tags, imageUrl, locales.
- `Prayer`
  - id, slug, title, body, category, tags, locales, attribution.
- `LiturgicalDay`
  - date, season, rank, observances, readingLink.
- `UserFavorite`
  - userId, itemType, itemId, createdAt.
- `UserNovenaCommitment`
  - userId, novenaId, startedAt, currentDay, completedDays, reminderConfig, status, updatedAt.

## 5. AWS Backend Recommendation
- API: Java Spring Boot (future Java app alignment) OR Node/NestJS if team speed is higher now.
- DB: AWS RDS PostgreSQL.
- Auth: AWS Cognito (email/password + Apple/Google optional).
- Media: AWS S3 + CloudFront (signed/public policy per asset class).
- Infra: ECS Fargate (or Elastic Beanstalk/Lambda if preferred) + Terraform later.

## 6. Initial PostgreSQL Schema (v1)
- `content_saints`
  - `id UUID PK`, `slug TEXT UNIQUE`, `feast_month INT`, `feast_day INT`, `image_url TEXT`, `metadata JSONB`, `created_at`, `updated_at`.
- `content_saint_translations`
  - `saint_id FK`, `locale TEXT`, `name TEXT`, `biography TEXT`, `PRIMARY KEY (saint_id, locale)`.
- `content_novenas`
  - `id UUID PK`, `slug TEXT UNIQUE`, `duration_days INT`, `image_url TEXT`, `start_rule JSONB`, `metadata JSONB`, timestamps.
- `content_novena_translations`
  - `novena_id FK`, `locale`, `title`, `description`, `PRIMARY KEY (novena_id, locale)`.
- `content_novena_days`
  - `novena_id FK`, `day_number INT`, `body JSONB`, `PRIMARY KEY (novena_id, day_number)`.
- `content_prayers`
  - `id UUID PK`, `slug TEXT UNIQUE`, `category TEXT`, `metadata JSONB`, timestamps.
- `content_prayer_translations`
  - `prayer_id FK`, `locale`, `title`, `body`, `PRIMARY KEY (prayer_id, locale)`.
- `liturgical_days`
  - `date DATE PK`, `season TEXT`, `rank TEXT`, `observances JSONB`, `reading_url TEXT`.
- `user_favorites`
  - `user_id UUID`, `item_type TEXT`, `item_id UUID`, `created_at`, `PRIMARY KEY (user_id, item_type, item_id)`.
- `user_novena_commitments`
  - `user_id UUID`, `novena_id UUID`, `started_at TIMESTAMPTZ`, `current_day INT`, `completed_days INT[]`, `status TEXT`, `reminder JSONB`, `updated_at`, `PRIMARY KEY (user_id, novena_id)`.

## 7. API Contract (v1)
Base: `/v1`

Public content:
- `GET /saints?month=&day=&q=&locale=`
- `GET /saints/{slug}?locale=`
- `GET /novenas?q=&tag=&locale=`
- `GET /novenas/{slug}?locale=`
- `GET /prayers?q=&category=&locale=`
- `GET /liturgical-days/{yyyy-mm-dd}`

Authenticated user:
- `GET /me/favorites`
- `PUT /me/favorites/{itemType}/{itemId}`
- `DELETE /me/favorites/{itemType}/{itemId}`
- `GET /me/novena-commitments`
- `PUT /me/novena-commitments/{novenaId}`
- `POST /me/novena-commitments/{novenaId}/complete-day`

Admin ingestion:
- `POST /admin/import/saints`
- `POST /admin/import/novenas`
- `POST /admin/import/prayers`

## 8. Migration Plan (Incremental)

### Phase A: Stabilize Client Architecture
- Introduce domain entities and repository interfaces in app.
- Keep current UI but route all reads through repository contracts.
- Add local adapter that reads current bundled JSON.

### Phase B: Data Pipeline to DB
- Build one-time import job from existing JSON manifests.
- Normalize slugs/IDs and locale fields.
- Validate record counts and key field parity.

### Phase C: Backend Read APIs
- Implement read-only endpoints for saints/novenas/prayers/liturgical days.
- Add pagination, locale fallback (`requested -> en`).
- Add ETag/Last-Modified caching support.

### Phase D: User State APIs
- Move favorites and novena commitment state from local storage to backend.
- Keep offline queue locally, sync when online.

### Phase E: Cutover
- Feature flag per repository (`local` vs `api`).
- Start with read APIs, then user state.
- Remove direct JSON coupling from screens.

## 9. Engineering Standards for Implementation
- Folder-by-feature + layer boundaries.
- Thin view controllers/screens; no business logic in UI files.
- Pure use-case functions with deterministic tests.
- DTO mappers isolate transport models from domain entities.
- Repository integration tests + API contract tests.
- Migrations versioned and repeatable.

## 10. Immediate Next Steps
1. Create app-side interfaces in current iOS repo (`Domain`, `UseCases`, `Repositories`).
2. Implement local repository adapters against existing bundled data.
3. Move one vertical slice first: `Novenas List + Novena Detail`.
4. Add backend scaffold (service, DB migrations, content import CLI).
5. Wire feature flag to switch Novenas slice from local to API.

