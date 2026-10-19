-- Status history for the construction timeline (kolodets va quvurlar).
-- status = null means the object was deleted at changed_at.
create table public.status_events (
  id          bigint generated always as identity primary key,
  object_type text not null check (object_type in ('manhole', 'pipe')),
  object_id   uuid not null,
  status      public.work_status,
  changed_at  timestamptz not null default now(),
  changed_by  uuid default auth.uid()
);
create index status_events_changed_at_idx on public.status_events (changed_at);
create index status_events_object_idx on public.status_events (object_id);

create function public.log_status_event() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    insert into status_events (object_type, object_id, status)
    values (tg_argv[0], old.id, null);
    return old;
  end if;
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into status_events (object_type, object_id, status)
    values (tg_argv[0], new.id, new.status);
  end if;
  return new;
end $$;

create trigger trg_manholes_status_event
  after insert or update of status or delete on public.manholes
  for each row execute function public.log_status_event('manhole');
create trigger trg_pipes_status_event
  after insert or update of status or delete on public.pipes
  for each row execute function public.log_status_event('pipe');

-- Backfill: current state of existing objects at their creation time.
insert into public.status_events (object_type, object_id, status, changed_at, changed_by)
select 'manhole', id, status, created_at, created_by from public.manholes;
insert into public.status_events (object_type, object_id, status, changed_at, changed_by)
select 'pipe', id, status, created_at, created_by from public.pipes;

alter table public.status_events enable row level security;
create policy status_events_select on public.status_events
  for select to authenticated using (public.is_active_user());
revoke all on public.status_events from anon;
revoke insert, update, delete on public.status_events from authenticated;
revoke execute on function public.log_status_event() from public, anon, authenticated;

alter publication supabase_realtime add table public.status_events;
