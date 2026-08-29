# Family template — CMS (WordPress and similar)

For a site built on a CMS: a theme, a plugin, or site-specific code around a core you do not
own. The defining constraint is that **the core is not yours** — it updates underneath you, and
anything you change in it is lost and unsupported.

`/gku:init` copies the block below into `CLAUDE.md` between the markers.

---

<!-- toolkit:begin family-rules -->

## CMS conventions

### The core, and who owns it

**First work out which of these you are in** — check whether core is in `.gitignore`, whether a
package manager declares it, and whether anyone has written down how the site gets updated.

- **A. Core is installed and updated outside the repository** — only your themes, plugins and
  site code are committed. The common case, and the one to aim for. An edit to core is silently
  reverted by the next update, so the bug comes back at the worst moment and nobody remembers why.
- **B. Core is committed and still updated by dropping in releases.** Every update becomes a
  manual merge, and a patch quietly lost in one is a reintroduced bug nobody is looking for.
- **C. Core is committed and permanently forked.** You *can* edit anything, but **the update path
  is also the security path**: a public CMS is scanned continuously for known vulnerabilities in
  known versions, and whoever forked core took on patching every future CVE by hand, forever.

So in every case **prefer the hooks** — child theme, plugin, filters — for different reasons: in
A and B the edit will not survive; in C every line added to core makes returning to a supported
version harder, and returning is the goal. A forked core is a standing risk, not a settled
decision: record the version it diverged from, keep the diff against upstream small and
documented, know which advisories apply, and treat getting back onto a maintained core as real
work worth scheduling.

- **Never edit a third-party plugin or theme in place** — the same three cases apply. Fork it
  properly or override through the provided hooks.
- Keep core, themes and plugins **updated** wherever an update path exists — most compromises of
  a public CMS arrive through a known vulnerability in an out-of-date component, not bespoke
  code. A pending security update is urgent work.
- Remove what is unused. A deactivated-but-installed plugin is still code on disk and still a
  candidate for exploitation.

### Input, output, and the three checks

WordPress-style APIs are named below; the equivalents in another CMS follow the same shape.

- **Sanitise on input.** Never trust `$_GET`, `$_POST`, `$_REQUEST` or `$_COOKIE`. Run each
  through the narrowest sanitiser that fits — `sanitize_text_field()`, `absint()`,
  `sanitize_email()`, `esc_url_raw()`.
- **Escape on output, per context.** `esc_html()` in the body, `esc_attr()` inside an attribute,
  `esc_url()` for links, `wp_kses_post()` where limited markup is genuinely wanted. Escape at
  the point of output, not on the way in — the same value can be safe in one context and an
  injection in another.
- **Nonces on every state-changing action.** `wp_nonce_field()` in the form,
  `check_admin_referer()` or `wp_verify_nonce()` on the handler. A form without one is a
  cross-site request forgery hole.
- **Capabilities, not roles.** `current_user_can('edit_others_posts')` on the action itself.
  Hiding an admin menu entry is not access control; the endpoint remains reachable.
- **`$wpdb->prepare()` for every query with a variable**, including integers. Never concatenate
  into SQL.

Those four — sanitise, escape, nonce, capability — are the checks that get skipped under time
pressure, and each one skipped is a real hole rather than a style lapse.

### Files, uploads and secrets

- Uploads go through the CMS media API, validated by inspecting content rather than the
  supplied name or MIME header.
- Never place executable code in an uploads directory, and ensure that directory cannot execute.
- Credentials and salts live in the configuration file, which is **not committed**. Confirm the
  ignore rules cover it and that it sits outside the web root where the host allows.
- Disable file editing from the admin UI (`DISALLOW_FILE_EDIT`) — it turns any admin account
  compromise into arbitrary code execution.
- Turn display of errors off in production; log instead. A stack trace in a page reveals paths
  and versions.

### Design priorities

Prefer the design that is easier to read, then easier to change, then easier to extend, then
cheaper in memory and time — in that order. Efficiency is last, not absent: weigh it at the scale
the data actually has, and give an optimisation that costs readability a measured reason.

### Long-running work

Work the user need not wait for does not run on the path they wait on. On a site that path is the
request: an export, a bulk recalculation, a call to an outside service — anything that may outlast
a page load — goes to the CMS's scheduled-event API (`wp_schedule_single_event()` or Action
Scheduler in WordPress); the request returns at once, and the user is told when it is done. Reuse
that mechanism rather than adding another. Where the user genuinely cannot continue until the
work finishes — a CLI command, a resource that must not be used mid-change — a progress indicator
or a lock is the right tool.

### Style

- Follow the CMS's own coding standards rather than a general PHP guide — its linter and its
  reviewers assume them.
- Prefix every global function, class, option key and database table with the theme or plugin
  slug. The global namespace is shared with every other plugin on the site, and a collision is
  a hard-to-trace breakage.
- Enqueue scripts and styles properly (`wp_enqueue_script`/`_style`) with declared dependencies
  and a version string. Never hard-code a `<script>` tag into a template.
- Use the CMS's translation functions for user-facing text rather than inline literals.

<!-- toolkit:end family-rules -->
