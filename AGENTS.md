# Project Rules

## Stack
- Frontend: React (or Next.js)
- Backend: Supabase (Postgres, Auth, RLS)
- Hosting: Cloudflare

## Structure
- All database changes MUST go through migrations
- Never manually edit database in production
- Use supabase/migrations for schema changes

## Naming
- Tables: snake_case
- Columns: snake_case
- IDs: uuid

## Auth
- Use Supabase Auth
- Always enforce RLS policies
- Never expose sensitive data without policies

## UI
- Match existing design exactly
- Do not change styling unless specified

## Features
- Build modular pages (invitations, clients, properties)
- Each feature must have:
  - UI
  - API logic
  - DB schema

## Rules
- No fake data
- No hardcoded IDs
- Everything must connect to real backend