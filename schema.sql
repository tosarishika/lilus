-- Run once in the Supabase SQL editor of a new project.
create table public.couples (
 id uuid primary key default gen_random_uuid(),
 member_a uuid not null references auth.users(id),
 member_b uuid references auth.users(id),
 invite_code text not null unique default replace(gen_random_uuid()::text,'-',''),
 start_date date not null default current_date,
 check(member_a is distinct from member_b)
);
create table public.moments (
 id uuid primary key default gen_random_uuid(),
 couple_id uuid not null references public.couples(id) on delete cascade,
 author uuid not null references auth.users(id),
 kind text not null check(kind in ('mood','answer','preference','guess','game','message','memory','event','note','list','pet','drawing','place')),
 payload jsonb not null check(octet_length(payload::text)<3000000),
 created_at timestamptz not null default now()
);
create index moments_couple on public.moments(couple_id,created_at);
create unique index one_answer_per_person on public.moments(couple_id,author,kind,(payload->>'key')) where kind in ('answer','preference','guess','game','mood');
alter table public.couples enable row level security;
alter table public.moments enable row level security;
revoke all on public.couples,public.moments from anon,authenticated;
grant select on public.couples to authenticated;
grant update(start_date) on public.couples to authenticated;
grant select,insert,delete on public.moments to authenticated;
grant update(payload) on public.moments to authenticated;
create policy couple_read on public.couples for select to authenticated using(auth.uid() in(member_a,member_b));
create policy couple_anniversary on public.couples for update to authenticated using(auth.uid() in(member_a,member_b)) with check(auth.uid() in(member_a,member_b));
create function public.is_couple_member(cid uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.couples where id=cid and auth.uid() in(member_a,member_b));
$$;
-- Check reveal conditions without recursively invoking the moments SELECT policy.
create function public.can_reveal(cid uuid,k text,p jsonb) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.moments where couple_id=cid and author=auth.uid() and payload->>'key'=p->>'key' and kind=case when k='preference' then 'guess' else k end);
$$;
revoke all on function public.is_couple_member(uuid), public.can_reveal(uuid,text,jsonb) from public;
grant execute on function public.is_couple_member(uuid), public.can_reveal(uuid,text,jsonb) to authenticated;
create policy moment_read on public.moments for select to authenticated using(
 public.is_couple_member(couple_id) and (author=auth.uid() or kind not in('answer','preference','game','guess') or (kind<>'guess' and public.can_reveal(couple_id,kind,payload)))
);
create policy moment_insert on public.moments for insert to authenticated with check(public.is_couple_member(couple_id) and author=auth.uid());
create policy moment_update on public.moments for update to authenticated using(public.is_couple_member(couple_id) and (author=auth.uid() or kind='list')) with check(public.is_couple_member(couple_id) and (author=auth.uid() or kind='list'));
create policy moment_delete on public.moments for delete to authenticated using(public.is_couple_member(couple_id) and author=auth.uid());
create function public.create_couple(anniversary date) returns uuid language plpgsql security definer set search_path=public as $$
declare cid uuid;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 perform pg_advisory_xact_lock(824301);
 if exists(select 1 from public.couples where auth.uid() in(member_a,member_b)) then raise exception 'You already have a couple space'; end if;
 insert into public.couples(member_a,start_date) values(auth.uid(),anniversary) returning id into cid;
 return cid;
end; $$;
create function public.join_couple(code text) returns uuid language plpgsql security definer set search_path=public as $$
declare cid uuid;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 perform pg_advisory_xact_lock(824301);
 if exists(select 1 from public.couples where auth.uid() in(member_a,member_b)) then raise exception 'You already have a couple space'; end if;
 update public.couples set member_b=auth.uid() where invite_code=code and member_b is null and member_a<>auth.uid() returning id into cid;
 if cid is null then raise exception 'That invite is invalid or already used'; end if;
 return cid;
end; $$;
revoke all on function public.create_couple(date),public.join_couple(text) from public;
grant execute on function public.create_couple(date),public.join_couple(text) to authenticated;

-- Existing projects: run this once after the original schema.sql.
-- New projects: schema.sql already includes this migration.
begin;
drop policy if exists moment_insert on public.moments;
create policy moment_insert on public.moments for insert to authenticated
 with check(public.is_couple_member(couple_id) and author=auth.uid() and kind<>'pet');
drop policy if exists moment_update on public.moments;
create policy moment_update on public.moments for update to authenticated
 using(public.is_couple_member(couple_id) and kind<>'pet' and (author=auth.uid() or kind='list'))
 with check(public.is_couple_member(couple_id) and kind<>'pet' and (author=auth.uid() or kind='list'));
drop policy if exists moment_delete on public.moments;
create policy moment_delete on public.moments for delete to authenticated
 using(public.is_couple_member(couple_id) and author=auth.uid() and kind<>'pet');

-- Append-only care events. Locking the couple serializes simultaneous purchases
-- and adoption; clients cannot invent coins or rewrite care history.
create or replace function public.pet_action(cid uuid, action jsonb) returns uuid
language plpgsql security definer set search_path=public as $$
declare
 act text:=action->>'action'; item text:=action->>'item';
 pet_name text:=btrim(action->>'name'); species text:=action->>'type';
 adopted boolean; balance integer; cost integer; spent integer; owned boolean;
 asleep boolean; last_time timestamptz; event_id uuid; payload_out jsonb;
 outdoors boolean; walk_started timestamptz; walk_progress integer; step_number integer;
 px numeric; py numeric;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 perform 1 from public.couples where id=cid and auth.uid() in(member_a,member_b) for update;
 if not found then raise exception 'This is not your couple space'; end if;
 select exists(select 1 from public.moments where couple_id=cid and kind='pet' and payload->>'action'='adopt') into adopted;
 select payload->>'action'='walk_begin',created_at into outdoors,walk_started from public.moments where couple_id=cid and kind='pet' and payload->>'action' in('walk_begin','walk_finish','walk_return') order by created_at desc limit 1;
 select payload->>'action'='sleep' into asleep from public.moments where couple_id=cid and kind='pet' and payload->>'action' in('sleep','wake') order by created_at desc limit 1;
 if act='adopt' then
  if adopted then raise exception 'You already have a little companion'; end if;
  if species is null or species not in('cat','dog','bunny','dragon') or pet_name is null or char_length(pet_name) not between 1 and 30 then raise exception 'Choose a pet and a name of up to 30 letters'; end if;
  payload_out=jsonb_build_object('action',act,'type',species,'name',pet_name);
 elsif not adopted then raise exception 'Choose your pet first';
 elsif act='rename' then
  if pet_name is null or char_length(pet_name) not between 1 and 30 then raise exception 'Choose a name of up to 30 letters'; end if;
  payload_out=jsonb_build_object('action',act,'name',pet_name);
 elsif act in('move','decorate') then
  if coalesce(outdoors,false) then raise exception 'Head home before rearranging your room'; end if;
  if jsonb_typeof(action->'position'->'x') is distinct from 'number' or jsonb_typeof(action->'position'->'y') is distinct from 'number' then raise exception 'Invalid room position'; end if;
  px=(action->'position'->>'x')::numeric; py=(action->'position'->>'y')::numeric;
  if px not between 8 and 92 or py not between 25 and 85 then raise exception 'Keep it inside the room'; end if;
  if act='move' and coalesce(asleep,false) then raise exception 'Wake your little one before moving them'; end if;
  if act='decorate' then
   if item is null or item not in('bed','bath','plant','toy','lamp','rug') then raise exception 'Unknown furniture'; end if;
   if item not in('bed','bath') and not exists(select 1 from public.moments where couple_id=cid and kind='pet' and payload->>'action'='buy' and payload->>'item'=item) then raise exception 'Choose something from your collection'; end if;
  end if;
  payload_out=jsonb_build_object('action',act,'position',jsonb_build_object('x',px,'y',py));
  if act='decorate' then payload_out=payload_out||jsonb_build_object('item',item); end if;
 elsif act='walk_step' then
  if not coalesce(outdoors,false) then raise exception 'Start a little walk first'; end if;
  if jsonb_typeof(action->'step') is distinct from 'number' or action->>'step' not in('1','2','3') then raise exception 'Invalid trail marker'; end if;
  step_number=(action->>'step')::integer;
  select coalesce(max((payload->>'step')::integer),0) into walk_progress from public.moments where couple_id=cid and kind='pet' and payload->>'action'='walk_step' and created_at>walk_started;
  if step_number<>walk_progress+1 then raise exception 'Follow the next glowing marker'; end if;
  payload_out=jsonb_build_object('action',act,'step',step_number);
 elsif act='walk_return' then
  if not coalesce(outdoors,false) then raise exception 'Already home'; end if;
  payload_out=jsonb_build_object('action',act);
 elsif act in('buy','equip') then
  cost=case item when 'bow' then 35 when 'hat' then 60 when 'crown' then 100 when 'moon' then 45 when 'forest' then 45 when 'sunset' then 45 when 'bed' then 40 when 'plant' then 25 when 'toy' then 30 when 'lamp' then 30 when 'rug' then 35 else null end;
  if cost is null then raise exception 'Unknown shop item'; end if;
  select exists(select 1 from public.moments where couple_id=cid and kind='pet' and payload->>'action'='buy' and payload->>'item'=item) into owned;
  if act='equip' and not owned then raise exception 'Buy this item first'; end if;
  if act='buy' then
   if owned then raise exception 'You already own this item'; end if;
   select 30+coalesce(sum(least(n,12)*8 + case when humans>=2 then 25 else 0 end),0) into balance from (
    select (created_at at time zone 'UTC')::date, count(*) n, count(distinct author) humans from public.moments
    where couple_id=cid and kind='pet' and payload->>'action' in('feed','treat','water','play','clean','sleep','cuddle','game','walk_begin','walk_finish') group by 1
   ) days;
   select coalesce(sum(case payload->>'item' when 'bow' then 35 when 'hat' then 60 when 'crown' then 100 when 'moon' then 45 when 'forest' then 45 when 'sunset' then 45 when 'bed' then 40 when 'plant' then 25 when 'toy' then 30 when 'lamp' then 30 when 'rug' then 35 else 0 end),0) into spent from public.moments where couple_id=cid and kind='pet' and payload->>'action'='buy';
   if balance-spent<cost then raise exception 'A few more care moments will earn those coins'; end if;
  end if;
  payload_out=jsonb_build_object('action',act,'item',item);
 elsif act in('feed','treat','water','play','clean','sleep','wake','cuddle','game','walk_begin','walk_finish') then
  if coalesce(outdoors,false) and act not in('cuddle','walk_finish') then raise exception 'Head home for meals, baths, and bedtime'; end if;
  if act='walk_finish' then
   select coalesce(max((payload->>'step')::integer),0) into walk_progress from public.moments where couple_id=cid and kind='pet' and payload->>'action'='walk_step' and created_at>walk_started;
   if not coalesce(outdoors,false) or walk_progress<>3 then raise exception 'Visit all three trail markers first'; end if;
  end if;
  if coalesce(asleep,false) and act not in('wake','cuddle') then raise exception 'Your little one is asleep'; end if;
  if act='wake' and not coalesce(asleep,false) then raise exception 'Already wide awake'; end if;
  select max(created_at) into last_time from public.moments where couple_id=cid and kind='pet' and payload->>'action'=act;
  if last_time>clock_timestamp()-interval '30 seconds' then raise exception 'Give them a moment. Try again in a few seconds'; end if;
  payload_out=jsonb_build_object('action',act);
 else raise exception 'Unknown pet action';
 end if;
 insert into public.moments(couple_id,author,kind,payload,created_at) values(cid,auth.uid(),'pet',payload_out,clock_timestamp()) returning id into event_id;
 return event_id;
end; $$;
revoke all on function public.pet_action(uuid,jsonb) from public;
grant execute on function public.pet_action(uuid,jsonb) to authenticated;
create index if not exists moments_pet_events on public.moments(couple_id,kind,created_at);
-- Enable immediate shared updates when Realtime is available in this project.
do $realtime$
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='moments') then
  alter publication supabase_realtime add table public.moments;
 end if;
end;
$realtime$;
commit;
