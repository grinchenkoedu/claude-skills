// Reads a task file the way /gku:plan writes it and /gku:implement ticks it.
// Pure: the text in, the summary out. Nothing here reaches `$`.

import type { TaskItem } from '../types'

const FENCE = /^\s*(```|~~~)/
const HEADING = /^#\s+(.+?)\s*$/
const SECTION = /^##\s+(.+?)\s*$/
const TYPE = /^\*{0,2}Type:\*{0,2}\s*(.*?)\s*$/
const MODE_MANUAL = /^\*{0,2}Mode:\*{0,2}\s*manual\b/i
// A step is a top-level list item, numbered or bulleted; its sub-bullets are indented.
const ITEM = /^(?:\d+[.)]|[-*+])\s+(.*)$/
const TICKED = /^\[[xX]\]/

/** The longest a title or a type is kept: they are drawn on one row of a narrow pane. */
export const TEXT_MAX = 120

/** Cuts text to what one row may show, and drops what a terminal would act on. */
export function clean(text: string, max = TEXT_MAX): string {
  const plain = text.replace(/[\u0000-\u001f\u007f-\u009f‎‏‪-‮⁦-⁩]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()

  return plain.length > max ? `${plain.slice(0, max - 1)}…` : plain
}

/** Lines outside fenced code: a plan may quote a template that has headings of its own. */
function proseLines(text: string): string[] {
  const kept: string[] = []
  let isFenced = false

  for (const line of text.split(/\r?\n/)) {
    if (FENCE.test(line)) {
      isFenced = !isFenced
      continue
    }
    if (!isFenced) kept.push(line)
  }

  return kept
}

/** The summary of one task file, from its name, its text and when it last changed. */
export function parseTask(file: string, text: string, mtimeMs: number): TaskItem {
  let title: string | undefined
  let type: string | undefined
  let isManual = false
  let isInSteps = false
  let ticked = 0
  let total = 0

  for (const line of proseLines(text)) {
    const heading = HEADING.exec(line)
    if (title === undefined && heading?.[1] !== undefined) title = heading[1]

    const typed = TYPE.exec(line)
    if (type === undefined && typed?.[1] !== undefined && typed[1] !== '') type = typed[1]

    if (MODE_MANUAL.test(line)) isManual = true

    const section = SECTION.exec(line)
    if (section?.[1] !== undefined) {
      isInSteps = /^steps\b/i.test(section[1])
      continue
    }

    const item = isInSteps ? ITEM.exec(line) : null
    if (item?.[1] !== undefined) {
      total += 1
      if (TICKED.test(item[1])) ticked += 1
    }
  }

  const named = clean(title ?? file.replace(/\.md$/i, ''))

  return {
    kind: 'task',
    file,
    title: named === '' ? file : named,
    ...(type === undefined ? {} : { type: clean(type, 40) }),
    ticked,
    total,
    isManual,
    isUnread: false,
    mtimeMs,
  }
}

/** A task file the pane lists by name only: over the read limit, or refused. */
export function unreadTask(file: string, mtimeMs: number): TaskItem {
  return {
    kind: 'task',
    file,
    title: clean(file.replace(/\.md$/i, '')),
    ticked: 0,
    total: 0,
    isManual: false,
    isUnread: true,
    mtimeMs,
  }
}
