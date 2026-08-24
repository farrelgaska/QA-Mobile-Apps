-- Migration: add api_idempotency_keys for report create idempotency
-- Created: 2026-08-22

create table public.api_idempotency_keys (
  key          text not null,
  scope        text not null default 'create_report',
  request_hash text not null,
  resource_id  text not null,
  created_at   timestamptz not null default now(),
  primary key (key, scope)
);

comment on table public.api_idempotency_keys is
  'Tracks per-key idempotency state for create-report submissions. '
  'Retained alongside report history; no TTL worker required at this phase.';


comment on table public.api_idempotency_keys is
  'Tracks per-key idempotency state for create-report submissions. '
  'Retained alongside report history; no TTL worker required at this phase.';
