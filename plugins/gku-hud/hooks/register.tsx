// gku-hud: a pane beside the chat for gku's working files. It lists the task
// files in .tasks/ and the reports in .gku/reports/, previews the one selected,
// and puts the next /gku command in the prompt box for the person to send.
//
// It reads only. It never writes a file, never submits a prompt, never calls a
// model and adds nothing to the context: evals/hud/never.sh holds it to that.
// Every hook passes its event on unchanged and closes with a .catch that does
// the same, so a failure here never stands in the session's way.
import { atom, read, update } from 'claude-code'
import type { EngineInterface, FsEntry, Register } from 'claude-code'

import { actionsFor, pathOf, type Action } from '../src/actions'
import { parseReport } from '../src/reports'
import { parseTask, unreadTask } from '../src/tasks'
import type { Item, Preview, Scan, TaskItem } from '../types'
import { drawPane, keyOf, PANE_ID, PANE_TITLE } from './pane'

/** The newest task files read per scan; older ones are counted, not read. */
export const READ_MAX = 30
/** The newest reports listed. */
export const REPORTS_MAX = 30
/** A task file larger than this is listed by name only. */
export const TASK_BYTES_MAX = 1024 * 1024
/** The most of a file the preview reads: well under the 100,000 characters an engine draws of one tree. */
export const PREVIEW_BYTES_MAX = 64 * 1024

// The values the pane keeps for the session, each declared in types/index.d.ts.
// They live in the file that reads and writes them, as the engine's scan asks.
const scan = atom({ plugin: 'gku-hud', key: 'scan' } as const, null)
const selected = atom({ plugin: 'gku-hud', key: 'selected' } as const, null)
const preview = atom({ plugin: 'gku-hud', key: 'preview' } as const, null)

function isMarkdownFile(entry: FsEntry): boolean {
  return entry.kind === 'file' && /\.md$/i.test(entry.name)
}

function newestFirst(a: FsEntry, b: FsEntry): number {
  return b.mtimeMs - a.mtimeMs || a.name.localeCompare(b.name)
}

/** The markdown files of a folder, newest first; none when it is missing or refused. */
async function listMarkdown($: EngineInterface, dir: string): Promise<FsEntry[]> {
  const entries = await $.fs.list(dir).catch(() => [] as FsEntry[])

  return entries.filter(isMarkdownFile).sort(newestFirst)
}

async function readTask($: EngineInterface, dir: string, entry: FsEntry): Promise<TaskItem> {
  if (entry.size > TASK_BYTES_MAX) return unreadTask(entry.name, entry.mtimeMs)
  const text = await $.fs.read(`${dir}/${entry.name}`).catch(() => undefined)

  return typeof text === 'string' ? parseTask(entry.name, text, entry.mtimeMs) : unreadTask(entry.name, entry.mtimeMs)
}

/** Reads the project's .tasks/ and .gku/reports/ as they stand now. */
async function scanProject($: EngineInterface): Promise<Scan> {
  const root = await $.session.root()
  const tasksDir = `${root}/.tasks`
  const taskFiles = await listMarkdown($, tasksDir)
  const reportFiles = await listMarkdown($, `${root}/.gku/reports`)
  const tasks = await Promise.all(taskFiles.slice(0, READ_MAX).map(entry => readTask($, tasksDir, entry)))

  return {
    tasks,
    reports: reportFiles.slice(0, REPORTS_MAX).map(entry => parseReport(entry.name, entry.mtimeMs)),
    moreTasks: Math.max(0, taskFiles.length - READ_MAX),
    at: await $.clock.now(),
  }
}

function findItem(found: Scan | null, key: string | null): Item | undefined {
  if (found === null || key === null) return undefined

  return [...found.tasks, ...found.reports].find(item => keyOf(item) === key)
}

/** The selected file's text, cut at the preview's limit; null when it cannot be read. */
async function readPreview($: EngineInterface, item: Item): Promise<Preview | null> {
  const root = await $.session.root()
  // One byte past the limit tells a file of exactly the limit from a longer one.
  const text = await $.fs.read(`${root}/${pathOf(item)}`, { length: PREVIEW_BYTES_MAX + 1 }).catch(() => undefined)
  if (typeof text !== 'string') return null
  // An engine that ignores `length` (2.1.316) hands the whole file over, so the text
  // is cut here as well, by characters; a character the byte limit split is dropped.
  const isCut = text.length > PREVIEW_BYTES_MAX || new TextEncoder().encode(text).length > PREVIEW_BYTES_MAX
  const shown = isCut ? text.slice(0, PREVIEW_BYTES_MAX).replace(/\uFFFD+$/, '') : text

  return { key: keyOf(item), text: isCut ? `${shown}\n\n*… cut at ${PREVIEW_BYTES_MAX / 1024} KiB*` : shown }
}

/** Rescans, keeps the selection if its file is still there, and rereads its preview. */
async function refresh($: EngineInterface): Promise<void> {
  const found = await scanProject($)
  await update($, scan, () => found)
  const item = findItem(found, await read($, selected))
  if (item === undefined) {
    await update($, selected, () => null)
    await update($, preview, () => null)
    return
  }
  const text = await readPreview($, item)
  await update($, preview, () => text)
}

async function select($: EngineInterface, key: string): Promise<void> {
  if ((await read($, selected)) === key) {
    await update($, selected, () => null)
    await update($, preview, () => null)
    return
  }
  await update($, selected, () => key)
  const item = findItem(await read($, scan), key)
  const text = item === undefined ? null : await readPreview($, item)
  await update($, preview, () => text)
}

/** Puts the command in the prompt box, never over a draft, and never sends it. */
async function fill($: EngineInterface, action: Action): Promise<void> {
  const box = await $.prompt.read()
  if (box.text.trim() !== '') {
    $.ui.toast('The prompt holds a draft: send or clear it, then press again.')
    return
  }
  const filled = await $.prompt.fill({ text: action.command, mode: 'replace' })
  if (!filled.isFilled) $.ui.toast('The prompt box could not take the command here.')
}

async function openPane($: EngineInterface): Promise<void> {
  await $.ui.open({ id: PANE_ID, title: PANE_TITLE })
  await refresh($)
}

async function isPaneShown($: EngineInterface): Promise<boolean> {
  const panes = await $.ui.panes()

  return panes.some(pane => pane.id === PANE_ID && pane.isPlaced)
}

export const register: Register = (on, options) => {
  const isOpenAtStart = options.open === 'on'

  on('session.start', async ($, e, next) => {
    // Unasked, the engine places the pane only from 144 columns; below that it waits.
    if (isOpenAtStart) await openPane($)

    return next(e)
  }).catch(($, e, next) => next(e))

  // skills/tasks/SKILL.md gives the command its name; this answers it before any model turn.
  on('command.run', { command: 'gku-hud:tasks' }, async $ => {
    await openPane($)

    return { text: 'gku tasks pane opened.' }
  }).catch(($, e, next) => next(e))

  // A skill writes and ticks a task file during a turn: the turn's end picks it up.
  on('turn.complete', async ($, e, next) => {
    const completed = await next(e)
    if (e.agentId === undefined && (await isPaneShown($))) await refresh($)

    return completed
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'Pane', requestId: PANE_ID }, async ($, e) => {
    const found = await read($, scan)
    const item = findItem(found, await read($, selected))

    return drawPane($, e, {
      scan: found,
      selected: item,
      preview: await read($, preview),
      actions: item === undefined ? [] : actionsFor(item),
      now: await $.clock.now(),
    }, {
      onRefresh: () => void refresh($).catch(() => undefined),
      onSelect: key => void select($, key).catch(() => undefined),
      onAction: action => void fill($, action).catch(() => undefined),
      onPath: picked => $.ui.toast(pathOf(picked)),
    })
  }).catch(($, e, next) => next(e))
}
