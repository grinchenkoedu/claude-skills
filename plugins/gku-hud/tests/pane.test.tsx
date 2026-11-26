import { describe, expect, test } from 'claude-code/testing'
import type { FsEntry, On } from 'claude-code'
import type { Engine } from 'claude-code/testing'

import { PREVIEW_BYTES_MAX, READ_MAX, TASK_BYTES_MAX } from '../hooks/register'

// Each hook here stands for the engine: nothing sits beneath the plugin.
type Entry = FsEntry

const ROOT = '/repo'
const NOW = Date.parse('2026-11-26T10:00:00Z')
const HOUR = 3_600_000

const PLAN = '# Export departments\n\n**Type:** feature\n\n## Steps\n1. [x] one\n2. two\n3. three\n'
const REVIEW = '# Review\n\n- **High** `a.php:3` — something\n'

type World = {
  dirs: Record<string, Entry[]>
  files: Record<string, string>
  reads: { path: string; length?: number }[]
  draft: string
  filled: string[]
  /** What the module must never do: a file written, a prompt sent. */
  forbidden: string[]
  toasts: string[]
  opened: string[]
  isShown: boolean
}

let world: World

const file = (name: string, hoursAgo: number, size = 100): Entry => ({ name, kind: 'file', size, mtimeMs: NOW - hoursAgo * HOUR, isLink: false })

function engine(on: On): void {
  world = { dirs: {}, files: {}, reads: [], draft: '', filled: [], forbidden: [], toasts: [], opened: [], isShown: true }
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('session.root', () => ({ value: ROOT }))
  on('clock.now', () => ({ value: NOW }))
  on('fs.list', (_, e) => {
    const entries = world.dirs[e.path ?? '']
    if (entries === undefined) throw new Error('ENOENT')
    return { value: entries }
  })
  on('fs.read', (_, e) => {
    world.reads.push({ path: e.path, ...(e.length === undefined ? {} : { length: e.length }) })
    const text = world.files[e.path]
    if (text === undefined) throw new Error('ENOENT')
    return { value: text }
  })
  on('prompt.read', () => ({ value: { text: world.draft, cursor: world.draft.length } }))
  on('prompt.fill', (_, e) => {
    world.filled.push(e.text)
    return { isFilled: true }
  })
  on('fs.write', (_, e) => {
    world.forbidden.push(`fs.write ${e.path}`)
    return { value: undefined }
  })
  on('prompt.submit', (_, e) => {
    world.forbidden.push(`prompt.submit ${e.text}`)
    return { text: e.text }
  })
  on('ui.toast', (_, e) => {
    world.toasts.push(e.text)
    return { value: undefined }
  })
  on('ui.open', (_, e) => {
    world.opened.push(e.id)
    return { value: { isPlaced: true } }
  })
  on('ui.panes', () => ({ value: world.isShown ? [{ id: 'gku-tasks', title: 'gku tasks', isShown: true, isFocused: false, isPlaced: true }] : [] }))
  on('turn.complete', () => ({ text: '' }))
  // Below the plugin's hooks, what the engine does with a command nobody answered: the skill's text.
  on('command.run', () => ({ text: 'the skill ran' }))
}

function project(): void {
  world.dirs[`${ROOT}/.tasks`] = [file('older.md', 30), file('export.md', 2), file('notes.txt', 1), { ...file('archive', 1), kind: 'dir' }]
  world.dirs[`${ROOT}/.gku/reports`] = [file('review-my-branch-20261126-0800.md', 3), file('verify-x-20261120-1200.md', 140)]
  world.files[`${ROOT}/.tasks/export.md`] = PLAN
  world.files[`${ROOT}/.tasks/older.md`] = '# Older\n## Steps\n1. [x] a\n'
  world.files[`${ROOT}/.gku/reports/review-my-branch-20261126-0800.md`] = REVIEW
}

const RUN = { origin: { kind: 'sdk' }, presentation: { isFullscreen: true, columns: 160 } } as const

const PANE = (surface: 'terminal' | 'desktop' | 'vscode' | 'mobile' = 'terminal') => ({
  plugin: 'gku-hud',
  component: 'Pane',
  requestId: 'gku-tasks',
  surface,
  viewport: { columns: 62, rows: 40 },
  props: {
    id: 'gku-tasks',
    title: 'gku tasks',
    isFocused: false,
    bodyColumns: 60,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 40 },
    view: {},
  },
}) as const

async function opened($: Engine): Promise<void> {
  await $.session.start({ cwd: ROOT, surface: 'terminal', isInteractive: true })
  const { text } = await $.command.run({ command: 'gku-hud:tasks', args: '', ...RUN })
  expect(text).toBe('gku tasks pane opened.')
}

describe('the list', () => {
  test('lists task files newest first, with steps, type and age, and reports below', async ($, on) => {
    engine(on)
    project()
    await opened($)
    expect(world.opened).toEqual(['gku-tasks'])

    for (const surface of ['terminal', 'desktop', 'vscode', 'mobile'] as const) {
      const ui = await $.ui.mount(PANE(surface))
      const rows = await ui.findAll({ type: 'Button' })
      const keys = rows.map(row => row.key)
      expect(keys.slice(0, 5)).toEqual(['refresh', 'task:export.md', 'task:older.md', 'report:review-my-branch-20261126-0800.md', 'report:verify-x-20261120-1200.md'])
      expect((await ui.find({ type: 'Text', text: /1\/3 · feature · 2h/ }))?.text).toBe('1/3 · feature · 2h')
      expect((await ui.find({ type: 'Text', text: /my-branch · 3h/ }))?.text).toBe('my-branch · 3h')
      await ui.unmount()
    }
  })

  test('an empty project says so, and never fails', async ($, on) => {
    engine(on)
    await opened($)
    const ui = await $.ui.mount(PANE())
    expect(await ui.find({ type: 'Text', text: /No task files in \.tasks\// })).toBeTruthy()
    expect(await ui.find({ type: 'Text', text: /No reports in \.gku\/reports\// })).toBeTruthy()
    await ui.unmount()
  })

  test('before the first scan it says it has not read', async ($, on) => {
    engine(on)
    const ui = await $.ui.mount(PANE())
    expect(await ui.find({ type: 'Text', text: /Not read yet/ })).toBeTruthy()
    await ui.unmount()
  })

  test(`reads at most ${READ_MAX} task files, and counts the rest`, async ($, on) => {
    engine(on)
    world.dirs[`${ROOT}/.tasks`] = Array.from({ length: READ_MAX + 4 }, (_, i) => file(`t${i}.md`, i))
    for (let i = 0; i < READ_MAX + 4; i++) world.files[`${ROOT}/.tasks/t${i}.md`] = `# T${i}\n`
    await opened($)
    expect(world.reads).toHaveLength(READ_MAX)
    const ui = await $.ui.mount(PANE())
    expect(await ui.find({ type: 'Text', text: /and 4 older, not read/ })).toBeTruthy()
    await ui.unmount()
  })

  test('a task file over the limit is listed by name and never read', async ($, on) => {
    engine(on)
    world.dirs[`${ROOT}/.tasks`] = [file('huge.md', 1, TASK_BYTES_MAX + 1)]
    await opened($)
    expect(world.reads).toEqual([])
    const ui = await $.ui.mount(PANE())
    expect(await ui.find({ type: 'Text', text: /not read · 1h/ })).toBeTruthy()
    await ui.unmount()
  })
})

describe('the selection', () => {
  test('pressing a task previews it, shows its steps, and offers what comes next', async ($, on) => {
    engine(on)
    project()
    await opened($)
    const ui = await $.ui.mount(PANE())
    await ui.press({ key: 'task:export.md' })
    expect(world.reads.at(-1)?.path).toBe(`${ROOT}/.tasks/export.md`)
    expect((await ui.find({ type: 'Markdown' }))?.text).toContain('Export departments')
    expect((await ui.find({ type: 'Text', text: /^Steps / }))?.text).toBe('Steps ████░░░░░░░░ 1/3')
    expect(await ui.find({ type: 'Button', key: 'do-continue' })).toBeTruthy()
    await ui.press({ key: 'task:export.md' })
    expect(await ui.find({ type: 'Markdown' })).toBeFalsy()
    await ui.unmount()
  })

  test('an action fills the empty prompt with its command, and never sends it', async ($, on) => {
    engine(on)
    project()
    await opened($)
    const ui = await $.ui.mount(PANE())
    await ui.press({ key: 'task:export.md' })
    await ui.press({ key: 'do-continue' })
    expect(world.filled).toEqual(['/gku:implement .tasks/export.md --continue'])
    await ui.press({ key: 'report:review-my-branch-20261126-0800.md' })
    await ui.press({ key: 'do-fix' })
    expect(world.filled.at(-1)).toBe('/gku:fix .gku/reports/review-my-branch-20261126-0800.md')
    await ui.press({ key: 'refresh' })
    await $.turn.complete({ turnId: 't1', answer: '', durationMs: 1, isAborted: false, reason: 'answer' })
    expect(world.forbidden).toEqual([])
    await ui.unmount()
  })

  test('a draft in the prompt is never replaced: the pane says so instead', async ($, on) => {
    engine(on)
    project()
    await opened($)
    world.draft = 'half a thought'
    const ui = await $.ui.mount(PANE())
    await ui.press({ key: 'task:export.md' })
    await ui.press({ key: 'do-continue' })
    expect(world.filled).toEqual([])
    expect(world.toasts).toEqual(['The prompt holds a draft: send or clear it, then press again.'])
    await ui.unmount()
  })

  test('a preview stops at the limit and says so, however much the read hands over', async ($, on) => {
    engine(on)
    project()
    world.files[`${ROOT}/.tasks/older.md`] = `# Older\n${'x'.repeat(PREVIEW_BYTES_MAX + 10)}`
    await opened($)
    const ui = await $.ui.mount(PANE())
    await ui.press({ key: 'task:older.md' })
    const shown = (await ui.find({ type: 'Markdown' }))?.text ?? ''
    expect(shown.endsWith(`*… cut at ${PREVIEW_BYTES_MAX / 1024} KiB*`)).toBe(true)
    expect(shown.length).toBeLessThan(PREVIEW_BYTES_MAX + 40)
    await ui.unmount()
  })

  test('a manual plan not yet finished says why it offers no build', async ($, on) => {
    engine(on)
    project()
    world.files[`${ROOT}/.tasks/export.md`] = PLAN.replace('**Type:** feature', '**Type:** feature\n**Mode:** manual')
    await opened($)
    const ui = await $.ui.mount(PANE())
    await ui.press({ key: 'task:export.md' })
    expect(await ui.find({ type: 'Button', key: 'do-continue' })).toBeFalsy()
    expect(await ui.find({ type: 'Text', text: /A manual plan: you build it by hand/ })).toBeTruthy()
    await ui.press({ key: 'task:older.md' })
    expect(await ui.find({ type: 'Text', text: /A manual plan/ })).toBeFalsy()
    await ui.unmount()
  })

  test('a file of exactly the limit is shown whole, with no cut note', async ($, on) => {
    engine(on)
    project()
    const exact = `# Older\n${'x'.repeat(PREVIEW_BYTES_MAX - 8)}`
    world.files[`${ROOT}/.tasks/older.md`] = exact
    await opened($)
    const ui = await $.ui.mount(PANE())
    await ui.press({ key: 'task:older.md' })
    expect((await ui.find({ type: 'Markdown' }))?.text).toBe(exact)
    await ui.unmount()
  })

  test('Path shows the project-relative path', async ($, on) => {
    engine(on)
    project()
    await opened($)
    const ui = await $.ui.mount(PANE())
    await ui.press({ key: 'task:older.md' })
    await ui.press({ key: 'path' })
    expect(world.toasts).toEqual(['.tasks/older.md'])
    await ui.unmount()
  })

  test('a file that cannot be read previews as unreadable', async ($, on) => {
    engine(on)
    project()
    await opened($)
    delete world.files[`${ROOT}/.tasks/older.md`]
    const ui = await $.ui.mount(PANE())
    await ui.press({ key: 'task:older.md' })
    expect(await ui.find({ type: 'Text', text: /Could not read the file/ })).toBeTruthy()
    await ui.unmount()
  })
})

describe('keeping up', () => {
  const done = { turnId: 't1', answer: '', durationMs: 1, isAborted: false, reason: 'answer' } as const

  test('a main turn ending rescans while the pane is shown, and keeps the selection', async ($, on) => {
    engine(on)
    project()
    await opened($)
    const ui = await $.ui.mount(PANE())
    await ui.press({ key: 'task:export.md' })
    world.files[`${ROOT}/.tasks/export.md`] = PLAN.replace('2. two', '2. [x] two')
    await $.turn.complete(done)
    expect((await ui.find({ type: 'Text', text: /2\/3 · feature/ }))?.text).toBe('2/3 · feature · 2h')
    expect((await ui.find({ type: 'Markdown' }))?.text).toContain('2. [x] two')
    await ui.unmount()
  })

  test('a subagent turn, or a hidden pane, reads nothing', async ($, on) => {
    engine(on)
    project()
    await opened($)
    const before = world.reads.length
    await $.turn.complete({ ...done, agentId: 'a1' })
    world.isShown = false
    await $.turn.complete(done)
    expect(world.reads).toHaveLength(before)
  })

  test('a file gone at the rescan drops the selection', async ($, on) => {
    engine(on)
    project()
    await opened($)
    const ui = await $.ui.mount(PANE())
    await ui.press({ key: 'task:older.md' })
    world.dirs[`${ROOT}/.tasks`] = [file('export.md', 2)]
    await ui.press({ key: 'refresh' })
    expect(await ui.find({ type: 'Markdown' })).toBeFalsy()
    expect(await ui.find({ type: 'Button', key: 'task:older.md' })).toBeFalsy()
    await ui.unmount()
  })
})

describe('the start', () => {
  test('left at its default, a session start opens nothing and reads nothing', async ($, on) => {
    engine(on)
    project()
    await $.session.start({ cwd: ROOT, surface: 'terminal', isInteractive: true })
    expect(world.opened).toEqual([])
    expect(world.reads).toEqual([])
  })

  test('with open = on, a session start opens the pane and reads', { options: { open: 'on' } }, async ($, on) => {
    engine(on)
    project()
    await $.session.start({ cwd: ROOT, surface: 'terminal', isInteractive: true })
    expect(world.opened).toEqual(['gku-tasks'])
    expect(world.reads.length).toBeGreaterThan(0)
  })
})
