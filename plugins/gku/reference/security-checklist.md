# Security checklist — shared by `/gku:review`, `/gku:verify` and `/gku:audit`

The well-known security flaws are well known because the same handful of mistakes keep
being made. This is that handful, written as a reviewer's checklist: the code
pattern that signals each one, what counts as proof, and the severity it carries. `/gku:review`
reads code against it; `/gku:verify` confirms the guards hold against a minimal probe;
`/gku:audit` reads a whole tree against it rather than a diff. The
per-family rules in `templates/` (`s()`, `require_capability()`, nonces, `|safe`…) say *how
this repository* is supposed to do each of these; this file says *what to check*.

## Scope and wording

This is a review of the developer's own code, in their own repository, run locally on test
data. Every framework's own security documentation asks exactly this of its reviewers, and a
review that skips it is incomplete in the same way a review that skips the tests is.

- **Do the whole pass, every time, and say what it covered.** A missing security section in a
  review reads as "looked, found nothing" — which is a claim. If a check could not be done,
  name it as skipped and say why; never let it fall silently out of the report.
- **Name the line and the input.** "Consider input validation" is not a finding. The finding is
  `path:line`, the value that reaches the wrong place, and what happens when it does. A reviewer
  who cannot say which line is wrong has not found anything yet.
- **One demonstrating input is proof. Nothing more is needed, and nothing more is review.** A
  single quote, `../`, a `<b>` tag, the id of a record belonging to another test account, a
  state-changing request with its token left out. If such an input reaches SQL, a shell, the
  filesystem, the page, or another user's data, the finding is made. Building anything that
  does more than demonstrate is outside the job.
- **Local only, own code only.** Never probe a host the developer does not control, never a
  production system, never with a real person's account or data. Verification uses the
  project's test accounts — two throwaway users, one with the permission and one without — and
  restores whatever it changed.

Severities follow `/gku:review`: **BLOCKER** when an input demonstrably reaches the wrong place
or a guard is demonstrably missing; **WARNING** when the weakness is real but needs a second
condition to matter; **NIT** for defence in depth.

## The checklist

### 1. Injection — input assembled into something that gets executed

| Where | The pattern | Proof | Severity |
|---|---|---|---|
| **SQL** | a request value interpolated or concatenated into a query string: `"... WHERE id = $id"`, `f"... {name}"`, `.raw()`, `.extra()`, `whereRaw()`, `$DB->get_records_sql()` with a variable inside the string, `LIKE '%$q%'` | a value containing a single quote changes the query or errors | BLOCKER |
| **SQL identifiers** | a column, table or sort direction taken from the request — placeholders cannot bind those | any name not in an allowlist reaches the query | BLOCKER |
| **Shell** | `exec`, `shell_exec`, `system`, `passthru`, `popen`, `proc_open`, backticks, `os.system`, `subprocess` with `shell=True` or a string built from input | a value containing `;` or a space is not passed as a single argument; the fix is an argument array or `escapeshellarg()` | BLOCKER |
| **Filesystem path** | a filename or path from the request used in `include`, `require`, `file_get_contents`, `fopen`, `open()`, `send_file`, `readfile`, `unlink`, an archive entry name on extraction | `../` or an absolute path reaches outside the intended directory; the fix is `basename()` plus a `realpath()` check against an allowlisted root | BLOCKER |
| **Code / templates** | `eval`, `create_function`, `assert` with a string, a template *source* built from input, `unserialize()` / `pickle.loads()` / `yaml.load()` without `SafeLoader` on data from a request, cookie or upload | the call exists on a request-derived value — no further demonstration needed | BLOCKER |
| **XML** | `simplexml_load_string`, `DOMDocument::loadXML` with `LIBXML_NOENT`, `xml.etree` / `lxml` on uploaded or posted XML without entity loading disabled (`defusedxml` in Python) | external entities resolve | WARNING |
| **Headers and redirects** | `Location:`, `redirect()`, `header()` with a request value; `?next=` / `?return=` honoured as-is | an absolute URL to another host is followed; the fix is relative paths or an allowlist of hosts | WARNING |
| **Spreadsheet / CSV** | a cell written straight from user data | a value starting `=`, `+`, `-`, `@` lands unprefixed (see the family template) | WARNING; BLOCKER for exports of other users' data |
| **Logs** | request values written raw to a log | a newline in the value forges a log line | NIT |

### 2. Output escaping — data rendered as markup

| The pattern | Proof | Severity |
|---|---|---|
| an unescaped `echo` / `print` / `{{ }}` in a layer that does not escape; `\|safe`, `mark_safe()`, `Markup()`, `{!! !!}`, `\|raw`; `innerHTML`, `.html()`, `v-html`, `dangerouslySetInnerHTML`; Moodle output without `s()` / `format_string()` / `format_text()`; WordPress output without `esc_*` | a value containing `<b>` renders bold instead of literal | BLOCKER for user-supplied values; WARNING for admin-only values |
| the right escaper in the wrong context — an HTML-escaped value inside `href`, `onclick`, a `<script>` block, a CSS value, a URL parameter | a value with `"` or `javascript:` breaks out; JSON inside `<script>` needs `JSON_HEX_TAG` or equivalent | BLOCKER |
| a sanitiser applied on *input* and trusted on *output* (`strip_tags`, `PARAM_TEXT`, `sanitize_text_field`) | stripping is not encoding; the value is still rendered raw somewhere | WARNING |
| a URL built by concatenation and placed in `href` / `src` | the value is not a URL | WARNING |

### 3. Authentication — who is this?

| The pattern | Proof | Severity |
|---|---|---|
| a reachable entry point with no login check — a page, route, AJAX handler, external function, web-service definition; Moodle without `require_login()`; Django / Flask without the decorator or middleware; a `cli/` or cron script with no `CLI_SCRIPT` / `sys.argv` guard that a web request can reach | requesting it with no session returns content or performs the action | BLOCKER |
| passwords compared in plain text, hashed with `md5` / `sha1` / a home-made scheme, or stored reversibly | the call is there; `password_hash()` / `password_verify()` / the framework's hasher is the fix | BLOCKER |
| a reset, invite, API or remember-me token made with `rand()`, `mt_rand()`, `uniqid()`, `time()`, `random.random()`; a token with no expiry; one that still works after use | the generator is there; `random_bytes()` / `secrets` is the fix | BLOCKER for reset and API tokens, WARNING otherwise |
| a token or hash compared with `==` / `===` / `!=` instead of `hash_equals()` / `hmac.compare_digest()` | the comparison is there | WARNING |
| session not regenerated on login or privilege change; cookies without `HttpOnly` / `Secure` / `SameSite`; logout that does not destroy the session | read the session setup | WARNING |
| login, reset, or code-entry endpoints with no rate limit or lockout | none in the handler, middleware or gateway | WARNING |

### 4. Authorisation — may this user do this?

| The pattern | Proof | Severity |
|---|---|---|
| the permission check is on the *menu* or the *button*, not on the action; Moodle `require_capability()` missing on the page or external function, or checked against the wrong context (system instead of course or module); WordPress `current_user_can()` missing on the handler; a Django view with `login_required` but no object-level check | a logged-in test user without the permission performs the action by requesting the URL directly | BLOCKER |
| **a record fetched by an id from the request with no ownership or scope check** — `userid` from the request never compared to the current user, `get_record('x', ['id' => $id])` then straight to output or update | a logged-in test user reads or changes a record belonging to another test account by changing the id | BLOCKER |
| **mass assignment** — a request array bound straight to a model or row: an object built from `$_POST` passed to `update_record()`, `fields = '__all__'`, `$request->all()` into `fill()` / `create()`, `**request.form` into a constructor | a field the form never showed (`role`, `is_admin`, `price`, `userid`) is accepted | BLOCKER |
| a role, price, owner, status or admin flag accepted from the request rather than set by the server | the value is read from the request | BLOCKER |
| an export, list or search that returns rows outside the user's scope | the query has no scope clause tied to the current user or their context | BLOCKER |

### 5. CSRF — did the user mean to do this?

| The pattern | Proof | Severity |
|---|---|---|
| a state change on a `GET` (a delete link, a toggle, an approve URL) | visiting the URL performs the action | BLOCKER |
| a state-changing `POST` with no token — Moodle without `require_sesskey()` / a form without `sesskey`, WordPress without `check_admin_referer()` / `wp_verify_nonce()`, Django `@csrf_exempt`, Flask without the extension's token, a JSON endpoint protected only by a cookie | sending the request with the token removed still performs the action | BLOCKER |
| the token is checked but not tied to the session, or is a constant | read where it is generated | BLOCKER |

### 6. Secrets and configuration

| The pattern | Proof | Severity |
|---|---|---|
| a credential, API key, private key, token or connection string with an embedded password in the diff, a config file, a fixture, a test, a comment, or a `.env` that is tracked | the literal is there. Rotating it is part of the fix; deleting the line is not enough because history keeps it | BLOCKER |
| debug on in a deployable configuration — `DEBUG = True`, `display_errors = On`, `$CFG->debugdisplay`, `WP_DEBUG_DISPLAY`, `APP_DEBUG=true` | the setting is there | WARNING; BLOCKER if it is the production file |
| an error path that returns the exception message, SQL, a stack trace or a filesystem path to the user | the handler echoes `$e->getMessage()` or re-raises to a debug page | WARNING |
| CORS `*` together with credentials; an `Access-Control-Allow-Origin` reflected from the request | read the header | WARNING |
| a default password or a well-known account in seed data that can reach a deployed environment | the fixture is there | WARNING |

### 7. Files — uploads and downloads

| The pattern | Proof | Severity |
|---|---|---|
| an upload whose type is decided by the extension or the client-sent MIME type only; stored under the web root with its original name; no size limit; HTML or SVG stored and served inline; a Moodle plugin writing files past the File API | a file renamed `.php` / `.phtml` / `.html` is accepted and stored where the web server would run or render it | BLOCKER |
| a download path from the request (see path traversal above); `Content-Disposition` carrying an unsanitised user filename | `../` or a quote in the name | BLOCKER / WARNING |
| an archive extracted without checking entry names | an entry named `../x` lands outside the target | BLOCKER |

### 8. Server-side requests — the server fetching a URL the user chose

| The pattern | Proof | Severity |
|---|---|---|
| `file_get_contents($url)`, `curl`, `requests.get(url)`, `urllib`, an image-fetch-by-URL, a webhook URL stored from a form, a PDF renderer given a URL | the URL is request-derived and the code does not restrict scheme to `http(s)`, does not allowlist hosts, or does not refuse private and loopback ranges after resolution | BLOCKER when the fetched content is returned to the user or stored; WARNING otherwise |

### 9. Cryptography and randomness

| The pattern | Proof | Severity |
|---|---|---|
| `md5` / `sha1` for anything that has to be hard to reverse or forge; home-made encryption; a hard-coded key or IV; ECB mode; `mcrypt` | the call is there | WARNING; BLOCKER if it protects passwords or tokens |
| a security-relevant random value from a non-cryptographic generator (section 3 lists them) | the generator is there | see section 3 |
| certificate verification disabled — `CURLOPT_SSL_VERIFYPEER => false`, `verify=False` | the option is there | WARNING; BLOCKER for anything carrying credentials |

### 10. Data exposure

| The pattern | Proof | Severity |
|---|---|---|
| an API or template given a whole record — `json_encode($user)`, a serializer with every field — rather than an allowlist of fields | a password hash, email, token or internal id is in the response | BLOCKER for hashes and tokens, WARNING for the rest |
| passwords, tokens, card numbers or session ids written to logs, exceptions or error reports | the log call is there | WARNING |
| a response that depends on who is logged in, served with cache headers that let a shared cache keep it | read the headers | WARNING |
| real names, emails or records in fixtures (see `/gku:review` edge cases) | the fixture is there | BLOCKER |

### 11. Resource limits — what a single request can make the server do

| The pattern | Proof | Severity |
|---|---|---|
| a page size, limit, depth or count taken from the request with no ceiling; a query with no `LIMIT` over a user-chosen range | `limit=100000000` is honoured | WARNING |
| a regular expression applied to user input with nested quantifiers (`(a+)+`, `(.*)*`) | the pattern is there | WARNING |
| decompression, image processing or PDF rendering of an upload with no size or dimension cap | the cap is absent | WARNING |

### 12. Dependencies

| The pattern | Proof | Severity |
|---|---|---|
| a lock file pinning a version with a published advisory | `composer audit`, `npm audit --omit=dev`, `pip-audit`, `bundle audit` — whichever exists — reports it | WARNING; BLOCKER if the advisory matches how the project uses the package |
| an end-of-life runtime (see the family templates) | the declared version | WARNING, standing |

## A mechanical sweep to start from

Grep the diff before reading it. A hit is a lead, not a finding — read the line, then decide.
Misses are not clearance either; the list above is what you are reading for.

```bash
base=<base>
# Working tree against the merge base — covers committed, staged and unstaged alike.
# (`"$base"...HEAD` would see committed work only, and step 1 puts uncommitted work in scope.)
added() { git diff -U0 "$(git merge-base "$base" HEAD)" -- . ':!vendor' ':!node_modules' | grep -E '^\+[^+]'; }

# request input — where it comes in
added | grep -E '\$_(GET|POST|REQUEST|COOKIE|SERVER)|optional_param|required_param|request\.(args|form|json|GET|POST|files)|\$request->'
# execution sinks
added | grep -E '(exec|shell_exec|system|passthru|popen|proc_open|eval|unserialize|create_function)\s*\(|os\.system|subprocess|shell=True|pickle\.load|yaml\.load\('
# SQL assembled from variables
added | grep -E 'get_records_sql|get_record_sql|execute\s*\(|\.raw\(|\.extra\(|whereRaw|f"[^"]*(SELECT|INSERT|UPDATE|DELETE)|(SELECT|INSERT|UPDATE|DELETE|WHERE|ORDER BY|LIMIT)[^;]*\$[a-zA-Z_]'
# output that may skip escaping
added | grep -E '\|\s*safe|mark_safe|Markup\(|\{!!|\|\s*raw|innerHTML|\.html\(|v-html|dangerouslySetInnerHTML|echo\s+\$|print\s+\$'
# filesystem, outbound requests, redirects
added | grep -E '(file_get_contents|fopen|readfile|include|require|include_once|require_once|unlink|send_file|open)\s*\(\s*\$|curl_init|requests\.(get|post)|urlopen|Location:|redirect\s*\('
# weak primitives and disabled guards
added | grep -E 'md5\(|sha1\(|mt_rand|\brand\(|uniqid|random\.random|VERIFYPEER|verify\s*=\s*False|csrf_exempt|PARAM_RAW|__all__'
# literals that look like credentials
added | grep -iE '(password|passwd|secret|api[_-]?key|token|private[_-]?key)\s*[=:>]+\s*.{8,}'
# provenance markers — a licence or source the repository's own file headers do not carry
# (not `copyright` or `@author`: those are the project's own boilerplate in most PHP codebases)
added | grep -iE 'spdx-license|licen[cs]ed? under|permission is hereby granted|redistribution and use|(taken|adapted|copied|ported) from|stack ?overflow|github\.com/|https?://[^ ]+\.(js|php|py|ts)\b'
```

The hits are diff lines; open the file at each one before deciding anything. The last group is
not a security lead: a hit means a block may have come from elsewhere, and
`reference/code-provenance.md` says what decides it — a declared source and licence in the
commit or pull request body settles it, and an idiom everyone writes is nothing.

### The same sweep over a whole tree

`/gku:audit` has no diff. Define the source over every tracked file instead and run the same
groups; a hit then carries `path:line` directly, so there is nothing to map back:

```bash
tracked() { git ls-files -z -- . ':!vendor' ':!node_modules' | xargs -0 grep -nHE -e "$1"; }
tracked '\$_(GET|POST|REQUEST|COOKIE|SERVER)|optional_param|required_param|request\.(args|form|json|GET|POST|files)|\$request->'
```

Two checks only a tree shows: a tracked file that should never be — `git ls-files '.env' '*.pem'
'id_rsa*'` — and a private-key block anywhere, `tracked '-----BEGIN .*PRIVATE KEY'`. A hit in
either is a BLOCKER in section 6's terms; report the path and the key name, never the value.

Then, for every changed **entry point** — page, route, controller action, AJAX handler,
external function, CLI script — answer four questions by reading, not guessing:

1. Where is the login check?
2. Where is the permission check, and is it against the right context or object?
3. If it changes state, where is the token check, and is the method `POST`?
4. Every value it reads from the request — where does each one end up, and is it escaped or
   bound at that point?

An entry point for which any answer is "nowhere" is a finding at the severity the tables give.
