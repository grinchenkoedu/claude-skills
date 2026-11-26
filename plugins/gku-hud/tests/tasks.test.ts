import { describe, expect, test } from 'claude-code/testing'

import { clean, parseTask, unreadTask } from '../src/tasks'

// Shaped like /gku:plan step 6's template, two steps ticked the way /gku:implement ticks them.
const PLAN = [
  '# Export departments with no head',
  '',
  '**Type:** bug',
  '**Language:** en',
  '',
  '## Acceptance criteria',
  '- [x] The export no longer fails',
  '- [ ] A test covers it',
  '',
  'Test order: test-first — the type is bug',
  '',
  '## Steps',
  '1. [x] The failing test — `a1b2c3d`',
  '   - Create: `tests/ExportTest.php`',
  '   - Test: `vendor/bin/phpunit tests/ExportTest.php`',
  '2. [x] The guard in the exporter',
  '   - Modify: `classes/export/Exporter.php:88`',
  '3. The changelog line',
  '   - Modify: `CHANGELOG.md`',
  '',
  '## How to check it',
  '- [ ] not a step',
  '',
].join('\n')

describe('parseTask', () => {
  test('reads the title, the type and the ticked steps of a plan', () => {
    const task = parseTask('export-no-head.md', PLAN, 5)
    expect(task).toEqual({
      kind: 'task',
      file: 'export-no-head.md',
      title: 'Export departments with no head',
      type: 'bug',
      ticked: 2,
      total: 3,
      isManual: false,
      isUnread: false,
      mtimeMs: 5,
    })
  })

  test('counts bulleted steps ticked as `- [x]` too', () => {
    const task = parseTask('a.md', '# A\n## Steps\n- [x] one\n- [ ] two\n- three\n', 0)
    expect([task.ticked, task.total]).toEqual([1, 3])
  })

  test('a file with no Steps section has no steps, and checkboxes elsewhere do not count', () => {
    const task = parseTask('a.md', '# A\n## Acceptance criteria\n- [x] done\n- [ ] not\n', 0)
    expect([task.ticked, task.total]).toEqual([0, 0])
  })

  test('a file with no Type line has no type, and one with no heading takes its name', () => {
    const task = parseTask('session-link-followups.md', 'Some notes\n', 0)
    expect(task.type).toBeUndefined()
    expect(task.title).toBe('session-link-followups')
  })

  test('reads a plain `Type:` line, as older followups write it', () => {
    expect(parseTask('a.md', '# A\nType: cleanup\n', 0).type).toBe('cleanup')
  })

  test('skips headings and steps inside a fenced block', () => {
    const text = [
      '# The real title',
      '## Design',
      '```markdown',
      '# <Short title>',
      '## Steps',
      '1. [x] quoted, not a step',
      '```',
      '## Steps',
      '1. the only step',
    ].join('\n')
    const task = parseTask('a.md', text, 0)
    expect(task.title).toBe('The real title')
    expect([task.ticked, task.total]).toEqual([0, 1])
  })

  test('notices a manual plan', () => {
    expect(parseTask('a.md', '# A\n**Mode:** manual\n', 0).isManual).toBe(true)
    expect(parseTask('a.md', '# A\n**Mode:** auto\n', 0).isManual).toBe(false)
  })

  test('reads CRLF files the same', () => {
    const task = parseTask('a.md', PLAN.replace(/\n/g, '\r\n'), 0)
    expect([task.title, task.ticked, task.total]).toEqual(['Export departments with no head', 2, 3])
  })

  test('an empty file is listed by its name', () => {
    expect(parseTask('empty.md', '', 0)).toEqual({
      kind: 'task', file: 'empty.md', title: 'empty', ticked: 0, total: 0, isManual: false, isUnread: false, mtimeMs: 0,
    })
  })
})

describe('clean', () => {
  test('folds control and bidirectional characters into spaces, then trims', () => {
    expect(clean('a\tb\u001b[31mc\u202Ed')).toBe('a b [31mc d')
  })

  test('cuts long text with an ellipsis', () => {
    expect(clean('x'.repeat(10), 5)).toBe('xxxx…')
  })
})

test('unreadTask lists a file by name only', () => {
  expect(unreadTask('huge.md', 7)).toEqual({
    kind: 'task', file: 'huge.md', title: 'huge', ticked: 0, total: 0, isManual: false, isUnread: true, mtimeMs: 7,
  })
})
