create table public.writer_workspaces (user_id uuid primary key references auth.users(id) on delete cascade, data jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now());
alter table public.writer_workspaces enable row level security;
create policy workspace_select_own on public.writer_workspaces for select to authenticated using (auth.uid() = user_id);
create policy workspace_insert_own on public.writer_workspaces for insert to authenticated with check (auth.uid() = user_id);
create policy workspace_update_own on public.writer_workspaces for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);