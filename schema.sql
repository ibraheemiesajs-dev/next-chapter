-- Next Chapter — database schema.
-- Run this in Supabase → SQL Editor on a fresh project.
--
-- Row Level Security is the whole security model here. The anon key is public
-- by design and ships in index.html; these policies are what stop one person
-- reading or changing another person's data.

-- ============================================================ reviews
create table if not exists reviews (
  id          uuid primary key default gen_random_uuid(),
  book_key    text not null,                 -- normalised "title|author"
  book_title  text,
  rating      int check (rating between 1 and 5),
  body        text,
  user_id     uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now()
);

create index if not exists reviews_book_key_idx on reviews (book_key);

alter table reviews enable row level security;

-- Reviews are public to read: the point is that other families see them.
create policy "reviews are readable by everyone"
  on reviews for select using (true);

-- But you can only write your own. auth.uid() is the signed-in user, taken
-- from the JWT — the client cannot forge it.
create policy "users insert their own reviews"
  on reviews for insert with check (auth.uid() = user_id);

create policy "users update their own reviews"
  on reviews for update using (auth.uid() = user_id);

create policy "users delete their own reviews"
  on reviews for delete using (auth.uid() = user_id);


-- ============================================================ children
create table if not exists children (
  id          uuid primary key default gen_random_uuid(),
  parent_id   uuid not null references auth.users (id) on delete cascade,
  name        text not null,
  age         int  not null check (age between 2 and 18),
  prefs       jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);

create index if not exists children_parent_idx on children (parent_id);

alter table children enable row level security;

-- Unlike reviews, these are private. Nobody sees another family's children.
create policy "parents manage their own children"
  on children for all
  using (auth.uid() = parent_id)
  with check (auth.uid() = parent_id);


-- ============================================================ saved_books
create table if not exists saved_books (
  id          uuid primary key default gen_random_uuid(),
  child_id    uuid not null references children (id) on delete cascade,
  book_key    text not null,
  book_title  text,
  book_author text,
  cover_id    bigint,                        -- Open Library cover id
  cover_url   text,                          -- Google Books thumbnail
  status      text not null check (status in ('want','reading','finished')),
  created_at  timestamptz not null default now(),
  unique (child_id, book_key)                -- makes upsert-on-conflict work
);

create index if not exists saved_books_child_idx on saved_books (child_id);

alter table saved_books enable row level security;

-- saved_books has no user_id of its own, so the policy reaches through to
-- children to find the owner. A row is yours if its child is yours.
create policy "parents manage their children's shelves"
  on saved_books for all
  using (exists (
    select 1 from children c
    where c.id = saved_books.child_id and c.parent_id = auth.uid()
  ))
  with check (exists (
    select 1 from children c
    where c.id = saved_books.child_id and c.parent_id = auth.uid()
  ));
