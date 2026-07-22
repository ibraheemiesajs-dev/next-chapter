# Next Chapter

A book finder for young readers. Search by age and interest, see what's actually
inside a book before handing it over, follow a series in the right order, and
keep a shelf for each child.

**Live:** https://next-chapter-rouge.vercel.app/

---

## Why it exists

Finding the next book for a child is harder than it should be. Search results
bury book one of a series under book nine. A book shelved as "juvenile" can
still be far too hard. And nothing tells a parent whether a character dies
halfway through, which matters a great deal to some families and not at all to
others.

Next Chapter tries to answer the question a parent is actually asking:
*is this the right book for my child, and where do I get it?*

## What it does

- **Search by age and interest.** Queries Open Library and Google Books
  together and merges the results, widening the search automatically if a
  narrow one comes back empty.
- **Content notes, not warnings.** Books carry descriptive tags — *Includes
  violence*, *Includes LGBTQIA characters* — stated neutrally so the reader
  decides. The same tag serves a family avoiding romance and a family looking
  for representation. Tags can be flagged (highlight) or hidden (filter out).
- **Series in order.** A search for dragons returns one Wings of Fire card
  pointing at book one, not nine scattered editions. Open a series for the full
  reading order, including side stories drawn as branches off the main sequence.
- **Reader profiles.** Each child has an age and their own content preferences,
  which persist between visits.
- **Shelves.** Want to read / Reading / Finished, per child, on their own page.
- **Reviews.** Star ratings and comments, saved per book.
- **Where to get it.** Libraries first — free borrowing from the Internet
  Archive where available, then WorldCat, then bookshops.
- **An AI librarian.** Three separate jobs, described below.

## How the AI is used

Three modes, all running server-side in a Supabase Edge Function so the API key
never reaches the browser.

| Mode | What it does | Risk |
|---|---|---|
| `rank` | Scores search results 1–5 for how well they suit the reader | Low — can only sort books that really exist |
| `recommend` | Suggests books from scratch | Higher — can invent titles, so every author is verified before display |
| `notes` | Guesses content notes for books not in the catalogue | Highest — a parent may act on it |

The guiding rule: **the hand-checked catalogue always wins.** AI output only
fills gaps, is always visually distinct from verified data, and is always
labelled as unverified.

Two decisions worth calling out:

- **"I don't know" returns nothing, not an empty list.** If the model isn't
  confident about a book's contents, the app says so explicitly — *that means
  unknown, not clear* — and links to Common Sense Media. An empty list from an
  uncertain model would read as false reassurance.
- **Guessed notes flag, they never hide.** Preference filtering only ever acts
  on hand-checked data. Hiding a book because a model guessed wrong is a worse
  failure than showing one the parent then rules out themselves.

## The catalogue

Series order and content notes are hand-entered in `index.html`, because no free
API provides either. Currently **25 series and 52 standalone titles**, around
287 individual books.

Long-running series are deliberately incomplete rather than invented. Those
carry a `todo` field that renders as a visible note in the app — an admitted gap
is better than a guess.

Adding a book means adding an entry to `SERIES` or `BOOKS`. Only notes that have
actually been verified go in. A wrong note is worse than no note, because a
parent will trust it.

## Built with

- Vanilla HTML, CSS, and JavaScript — one file, no build step, no framework
- [Open Library](https://openlibrary.org/developers/api) — catalogue, covers,
  borrowing status
- [Google Books API](https://developers.google.com/books) — descriptions,
  ratings, extra catalogue coverage
- [Supabase](https://supabase.com) — Postgres, auth, row-level security, Edge
  Functions
- [Anthropic API](https://docs.claude.com) — Claude Haiku, called server-side
- [Vercel](https://vercel.com) — hosting, deploys on push

Goodreads closed its public API in 2020 and Common Sense Media has never had
one, so neither can be read programmatically. Google Books is the closest
available substitute for ratings; Common Sense is linked to rather than scraped.

## Notes on the engineering

Things that took a while to get right, kept here because they're the parts worth
explaining:

- **All API text enters the DOM via `textContent`, never `innerHTML`.** Open
  Library is wiki-editable, so a book title is untrusted input and is never
  treated as markup.
- **Searches are versioned and abortable.** A slow earlier request can't
  overwrite the results of a newer one.
- **A book's identity doesn't depend on its source.** The key is normalised
  title + author, so the same book found via Google and via Open Library shares
  one set of reviews.
- **Google Books records are translated at the boundary.** One adapter function
  converts them to Open Library's shape; nothing downstream knows there are two
  sources. Adding a third means writing one more adapter.
- **Author names are normalised before matching.** "Tui T. Sutherland" and "Tui
  Sutherland" are the same person; without stripping middle initials, book 3 of
  a series escapes its own group.
- **Reviews save optimistically and roll back on failure.** A review that looks
  saved but isn't is the worst outcome.
- **One batched query per page, not one per book** — avoiding the N+1 problem.
- **Nothing blocks on the AI.** Results paint immediately; ranking arrives a
  moment later. If it fails, the list simply stays in its original order.
- **The anon key in the source is public by design.** Row-level security is what
  protects the data. The service role key and the Anthropic key are not in this
  repo and never reach the browser.

## Running it yourself

1. Create a Supabase project and run the SQL in `schema.sql`.
2. Paste your project's anon key into `SUPABASE_ANON_KEY` near the top of
   `index.html`.
3. For the AI features, deploy `supabase/functions/recommend/index.ts` as an
   Edge Function named `recommend`, and add your Anthropic key as a secret
   called `ANTHROPIC_API_KEY`. Set a low monthly spend cap — the function is
   publicly reachable.
4. Open `index.html`. There's no build step.

Everything except the AI works without an Anthropic key.

## Still to do

- Finish the long series marked `todo` in the catalogue
- Verify content notes against a second source before relying on them publicly
- A way for signed-in users to suggest corrections

## Accuracy

Reading orders and content notes are hand-entered and checked, not pulled from a
database. Mistakes are possible. Anything AI-generated is labelled as such in the
interface. For content guidance a family is relying on, check
[Common Sense Media](https://www.commonsensemedia.org/) too — the app links to it
on every book.
