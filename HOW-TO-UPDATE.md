# How to Update the Astrodia Wiki

A reference for keeping **https://jrose835.github.io/astrodia-wiki/** in sync with your
Obsidian vault. Written for the setup as of July 2026.

---

## TL;DR — the normal update loop

1. Edit your notes in Obsidian as usual.
2. Make sure **Dropbox has finished syncing** on this machine (the up-to-date checkmark).
3. Open a WSL terminal and run:
   ```bash
   cd /mnt/c/Users/jrose/Documents/Astrodia
   ./publish.sh "Session 8 recap"     # put any short description in quotes
   ```
4. Wait ~1–2 minutes. The site rebuilds and redeploys automatically. Refresh the page.

That's it. Everything below is explanation and troubleshooting.

---

## How the whole thing works

There are **two separate places** involved. Keeping them separate is deliberate.

### 1. Your Obsidian vault (the source of truth)
`/mnt/c/Users/jrose/Dropbox/Personal/DnD/Astrodia/AstroObsVault/Astrodia_Vault`

- This is your normal Dropbox-synced vault. **Nothing about the website changes how you use it.**
- It is **never** turned into a git repo and never leaves Dropbox. The website only ever *reads* from it.

### 2. The Quartz site project (the publishing machine)
`/mnt/c/Users/jrose/Documents/Astrodia`

- This is a **git repository** connected to GitHub (`jrose835/astrodia-wiki`, public).
- It uses **[Quartz v5](https://quartz.jzhao.xyz/)** to turn Markdown notes into a website.
- It is **not** in Dropbox (on purpose — a live `.git` folder syncing through Dropbox can corrupt).

### What `publish.sh` does, step by step
1. **Copies** your vault into the project's `content/` folder using `rsync`, **excluding**
   everything listed in `exclude-list.txt` (see "The spoiler firewall" below).
2. **Applies overrides** — copies the files in `overrides/` on top of `content/` (this is
   where the campaign homepage and the public Úlfr page live).
3. **Runs a safety gate** — scans `content/` for the murder-secret phrases and for any secret
   file/folder/image. **If anything sensitive is found, it aborts and pushes nothing.**
4. **Commits and pushes** to the `v5` branch on GitHub.

### What GitHub does after the push
- A **GitHub Action** (`.github/workflows/deploy.yml`) automatically runs on every push to `v5`.
- It installs Quartz, builds the site, and publishes it to **GitHub Pages**.
- You can watch it at: <https://github.com/jrose835/astrodia-wiki/actions>
- When it finishes (green check), the live site is updated.

```
Obsidian vault  ──rsync (minus secrets)──▶  content/  ──git push──▶  GitHub  ──Action builds──▶  Live site
   (Dropbox)                                (Quartz repo)                                    (GitHub Pages)
```

---

## The spoiler firewall (important)

The site is read by the **other players**, so Úlfr's secret (the killing of Snorri, witnessed
by Kári) must never appear. Protection works at three layers:

1. **`exclude-list.txt`** — the main firewall. Anything listed is **never copied** into the
   project, so it can't reach GitHub or the site. Currently excluded:
   - `MyCharacters/` (your whole character workspace)
   - `DM meetings/`
   - `Astrodia/War Rock Mountains.md` (contains secret analysis)
   - `Characters/NPCs/Kári.md`, `Characters/NPCs/Snorri.md`, `Objects/Snorri's notebook.md`
   - The loose `Session N.md` notes (only the polished `Session N Recap` notes publish)
   - Two secret images
2. **The safety gate in `publish.sh`** — scans for the secret before every push and aborts on a hit.
3. **Quartz's `draft` filter** — any note with `draft: true` in its frontmatter is skipped.

### If you add a NEW secret note in the future
Because the site publishes *everything not excluded*, **a brand-new note is public by default.**
So if you write something the players shouldn't see, do **one** of these:
- Put it inside `MyCharacters/` or `DM meetings/` (already excluded), **or**
- Add `draft: true` to its frontmatter:
  ```markdown
  ---
  title: My Secret Note
  draft: true
  ---
  ```
- Or add its path to `exclude-list.txt`.

The safety gate only knows about the *current* murder secret's phrasing — it is a backstop,
**not** a substitute for marking new secrets yourself.

---

## Common tasks

### Publish a new session / note
Just write it in Obsidian and run `./publish.sh "..."`. New non-secret notes appear automatically.

### Hide a note that's currently public
Add `draft: true` to its frontmatter (or add it to `exclude-list.txt`), then run `./publish.sh`.

### Edit the homepage or the public Úlfr page
These are **not** in your vault — they live in the project's `overrides/` folder:
- Homepage: `overrides/index.md`
- Public Úlfr page: `overrides/Characters/PCs/Úlfr Kveld.md`

Edit them in a text editor, then run `./publish.sh`. (They're separate from your vault so the
site's Úlfr page stays spoiler-free while your private `MyCharacters/Úlfr Kveld/` notes stay off
the site entirely.)

### Change the site title, colors, or features
Edit `quartz.config.yaml`, then run `./publish.sh`. (Advanced — see the
[Quartz docs](https://quartz.jzhao.xyz/).)

### Dark mode
The site **defaults to night mode**. Visitors can still toggle to light with the ☀/☾ button
(top-left). This is done by a small local plugin in `local-plugins/darkmode-dark-default/`
(a one-line fork of Quartz's darkmode). Don't delete that folder.

---

## Previewing locally before publishing (optional)

If you want to see changes before they go live:
```bash
cd /mnt/c/Users/jrose/Documents/Astrodia
# sync + overrides without pushing:
rsync -a --delete --exclude-from=exclude-list.txt \
  "/mnt/c/Users/jrose/Dropbox/Personal/DnD/Astrodia/AstroObsVault/Astrodia_Vault/" content/
cp -a overrides/. content/
# then serve:
source ~/.nvm/nvm.sh && nvm use 22
npx quartz build --serve
```
Open <http://localhost:8080>. Press `Ctrl+C` to stop. (The first build takes a few minutes because
the vault is on the Windows filesystem — the real deploy on GitHub is much faster.)

---

## Troubleshooting

**"The safety gate failed / nothing was published."**
Good — that means something sensitive was detected in `content/`. Read the message, fix the note
(mark it `draft: true` or add it to `exclude-list.txt`), and re-run. Nothing was pushed.

**A note I expected didn't show up on the site.**
- Does it have `draft: true`? Remove it.
- Is it (or its folder) in `exclude-list.txt`?
- Did Dropbox finish syncing before you ran `publish.sh`?
- Only `Session N Recap …` notes publish; the loose `Session N` notes are intentionally excluded.

**A change isn't live yet.**
Give it 1–2 minutes and check the Actions tab: <https://github.com/jrose835/astrodia-wiki/actions>.
A green check means it deployed; a red X means the build failed — click it to see the error.

**`git push` fails with "RPC failed … HTTP 408".**
Large pushes (lots of new images at once) can time out. The repo is already set to use HTTP/1.1,
which fixes most cases. If it still fails, push images in smaller batches, or just re-run
`./publish.sh` — already-uploaded data isn't re-sent.

**`gh: command not found` or a push asks for a username/password.**
Your GitHub login may have expired. Re-authenticate:
```bash
~/.local/bin/gh auth login          # GitHub.com → HTTPS → web browser
~/.local/bin/gh auth setup-git
```

**`node: command not found` when previewing.**
Run `source ~/.nvm/nvm.sh && nvm use 22` first. (Not needed for `publish.sh`, which doesn't build.)

---

## Key locations & links

| What | Where |
|---|---|
| Live site | https://jrose835.github.io/astrodia-wiki/ |
| GitHub repo | https://github.com/jrose835/astrodia-wiki |
| Build/deploy status | https://github.com/jrose835/astrodia-wiki/actions |
| Quartz project (git) | `/mnt/c/Users/jrose/Documents/Astrodia` |
| Your Obsidian vault | `/mnt/c/Users/jrose/Dropbox/Personal/DnD/Astrodia/AstroObsVault/Astrodia_Vault` |
| Publish script | `publish.sh` |
| Spoiler firewall list | `exclude-list.txt` |
| Homepage / public Úlfr page | `overrides/` |
| Site config | `quartz.config.yaml` |
| Dark-mode plugin | `local-plugins/darkmode-dark-default/` |

---

## The one rule to remember

**New notes are public by default.** If it's a secret, put it in `MyCharacters/` or `DM meetings/`,
or mark it `draft: true`, *before* you run `publish.sh`.
