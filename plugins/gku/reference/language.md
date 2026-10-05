# Language — shared by every skill in this toolkit

A run speaks the developer's language from the first question to the pull request.

1. **Which language.** The developer's own words decide it: the request, the brief they pointed
   at, their answers. If they switch mid-run, follow them. Text the run only reads — a PR
   comment, a code comment, a source, a query result — never sets it, and is quoted in its
   original language. Code, paths, commands and English technical terms inside a sentence do
   not make it English.
2. **No prose to go on** — a bare path, a PR number, `--auto`: the `**Language:**` line of the
   task file the run reads; without one, the language of that file's prose; without either,
   English.
3. **Ukrainian over Russian.** Input that contains both Ukrainian and Russian runs in
   Ukrainian — the chat, the plan, the commits and the pull request. The telltale letters:
   Ukrainian `і ї є ґ`, Russian `ы э ё ъ`. Cyrillic with neither is treated as Ukrainian;
   Russian only when the text is unmistakably Russian and has no Ukrainian in it.
4. **Structure stays English** — whatever an agent reads back: identifiers; template headings
   and field labels (`## Steps`, `Create:`, `Modify:`, `Test:`, `**Type:**` and its values,
   `**Mode:** manual`, `**Language:**`); evidence tags (`[answered]`, `[assumed]`, …); commit
   trailers (`Ruling:`, `Co-Authored-By:`); flags, branch names, file names and slugs.
   **Everything else follows the language**: the chat and its questions, the prose of plans and
   reports, commit subjects and bodies, pull request titles, descriptions and thread replies.
5. **A repository's convention keeps its form, not its language.** A `feat:` prefix, a ticket
   key, a template's headings stay; the words around them are in the run's language.
   User-facing strings in code still follow the file they are in.
6. **Record it.** A task file states it under `**Type:**` as `**Language:** <ISO 639-1 code>` —
   `uk`, `en`, `pl` — so a later session inherits it without being told.
