// The pane's layout: draws the values register.tsx reads and passes in, with
// the surface's own elements. It reads no state and calls nothing on `$` but
// `$.ui.resolve`.
import type { EngineInterface, RenderInput } from 'claude-code'

import type { Action } from '../src/actions'
import { age } from '../src/age'
import { stepsBar } from '../src/bar'
import type { Item, Preview, ReportItem, Scan, TaskItem } from '../types'

export const PANE_ID = 'gku-tasks'
export const PANE_TITLE = 'gku tasks'

/** The key a row's Button and the selection share. */
export function keyOf(item: Item): string {
  return `${item.kind}:${item.file}`
}

export type PaneView = {
  scan: Scan | null
  selected: Item | undefined
  preview: Preview | null
  actions: Action[]
  now: number
}

export type PaneHandlers = {
  onRefresh: () => void
  onSelect: (key: string) => void
  onBack: () => void
  onAction: (action: Action) => void
  onPath: (item: Item) => void
}

function taskMeta(task: TaskItem, now: number): string {
  const parts = [
    task.isUnread ? 'not read' : task.total === 0 ? 'no steps' : `${task.ticked}/${task.total}`,
    ...(task.type === undefined ? [] : [task.type]),
    ...(task.isManual ? ['manual'] : []),
    age(now, task.mtimeMs),
  ]

  return parts.join(' · ')
}

function reportMeta(report: ReportItem, now: number): string {
  return age(now, report.mtimeMs)
}

/**
 * The pane's tree: the list, or the one item that is open. Titles, types and
 * slugs are drawn as plain text; only an open file's text is Markdown.
 */
export function drawPane($: EngineInterface, e: RenderInput<'Pane'>, view: PaneView, on: PaneHandlers) {
  return view.selected === undefined ? drawList($, e, view, on) : drawDetail($, e, view, view.selected, on)
}

/** Every task and report as a row; pressing one opens it. */
function drawList($: EngineInterface, e: RenderInput<'Pane'>, view: PaneView, on: PaneHandlers) {
  const { Box, Text, Button } = $.ui.resolve(e)
  const { scan, now } = view

  return (
    <Box flexDirection="column">
      <Box flexDirection="row" justifyContent="space-between">
        <Text bold>TASKS</Text>
        <Button key="refresh" label="Refresh" hotkey="r" plain dimColor onPress={on.onRefresh} />
      </Box>
      {scan === null ? <Text dimColor>Not read yet.</Text> : null}
      {scan !== null && scan.tasks.length === 0 ? <Text dimColor>No task files in .tasks/</Text> : null}
      {(scan?.tasks ?? []).map(task => (
        <Button key={keyOf(task)} plain onPress={() => on.onSelect(keyOf(task))}>
          {task.title} <Text dimColor>{taskMeta(task, now)}</Text>
        </Button>
      ))}
      {scan !== null && scan.moreTasks > 0 ? <Text dimColor>{`and ${scan.moreTasks} older, not read`}</Text> : null}

      <Box marginTop={1}><Text bold>REPORTS</Text></Box>
      {scan !== null && scan.reports.length === 0 ? <Text dimColor>No reports in .gku/reports/</Text> : null}
      {(scan?.reports ?? []).map(report => (
        <Button key={keyOf(report)} plain onPress={() => on.onSelect(keyOf(report))}>
          {report.skill} <Text dimColor>{`${report.slug} · ${reportMeta(report, now)}`}</Text>
        </Button>
      ))}
    </Box>
  )
}

/** One item alone: Back to the list, its title, what it offers, and its text. */
function drawDetail($: EngineInterface, e: RenderInput<'Pane'>, view: PaneView, item: Item, on: PaneHandlers) {
  const { Box, Text, Button, Markdown } = $.ui.resolve(e)
  const { preview, actions, now } = view
  const title = item.kind === 'task' ? item.title : item.skill
  const meta = item.kind === 'task' ? taskMeta(item, now) : `${item.slug} · ${reportMeta(item, now)}`

  return (
    <Box flexDirection="column">
      <Box flexDirection="row" justifyContent="space-between">
        <Button key="back" label="Back" hotkey="b" plain onPress={on.onBack} />
        <Button key="refresh" label="Refresh" hotkey="r" plain dimColor onPress={on.onRefresh} />
      </Box>
      <Box marginTop={1}><Text bold wrap="wrap">{title}</Text></Box>
      <Text dimColor wrap="wrap">{meta}</Text>
      {item.kind === 'task' && item.total > 0 ? <Text>{stepsBar(item.ticked, item.total)}</Text> : null}
      <Box flexDirection="row" flexWrap="wrap" gap={1} marginTop={1}>
        {actions.map((action, index) => (
          <Button key={`do-${action.key}`} label={action.label} variant={index === 0 ? 'primary' : undefined} onPress={() => on.onAction(action)} />
        ))}
        <Button key="path" label="Path" dimColor onPress={() => on.onPath(item)} />
      </Box>
      {actions.length === 0 ? null : <Text dimColor wrap="wrap">A button puts its command in the prompt; you send it.</Text>}
      {actions.length === 0 && item.kind === 'task' && item.isManual
        ? <Text dimColor wrap="wrap">A manual plan: you build it by hand, and /gku:implement stops on it.</Text>
        : null}
      {preview === null || preview.key !== keyOf(item)
        ? <Text dimColor>Could not read the file.</Text>
        : <Box marginTop={1}><Markdown key="preview" text={preview.text} onLinkPress={() => undefined} /></Box>}
    </Box>
  )
}
