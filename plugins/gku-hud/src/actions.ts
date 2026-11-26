// What a selected item offers: each action is a command the pane puts in the
// prompt box for the person to send. Pure. evals/hud/commands.sh holds every
// command and flag here to the skill's own Arguments section.

import type { Item } from '../types'

export type Action = {
  /** The Button's key: stable across redraws. */
  key: string
  label: string
  /** What goes in the prompt box. */
  command: string
}

/** A path as a skill argument: quoted when it holds a space, as the skills strip quotes. */
export function argument(path: string): string {
  return /\s/.test(path) ? `"${path}"` : path
}

/** Whether a file name is safe to put in a command: one line, no quote, no control character. */
export function isSafeName(file: string): boolean {
  return file !== '' && !/["'`\\\u0000-\u001f\u007f]/.test(file) && !file.startsWith('-')
}

/** The project-relative path of an item, as the commands name it. */
export function pathOf(item: Item): string {
  return item.kind === 'task' ? `.tasks/${item.file}` : `.gku/reports/${item.file}`
}

/** The actions an item offers, in the order they are drawn. */
export function actionsFor(item: Item): Action[] {
  if (!isSafeName(item.file)) return []
  const path = argument(pathOf(item))

  if (item.kind === 'report') {
    return item.skill === 'review'
      ? [{ key: 'fix', label: 'Fix what it found', command: `/gku:fix ${path}` }]
      : []
  }

  if (item.isUnread) return []

  if (item.total === 0) {
    return [
      { key: 'plan', label: 'Plan it', command: `/gku:plan ${path}` },
      { key: 'implement', label: 'Build it', command: `/gku:implement ${path}` },
    ]
  }

  if (item.ticked >= item.total) {
    return [
      item.isManual
        ? { key: 'review', label: 'Review', command: '/gku:review --manual' }
        : { key: 'review', label: 'Review', command: '/gku:review' },
      { key: 'verify', label: 'Verify', command: '/gku:verify' },
    ]
  }

  // A manual plan is built by hand: /gku:implement stops on it, so none is offered.
  if (item.isManual) return []

  if (item.ticked > 0) {
    return [{ key: 'continue', label: 'Resume', command: `/gku:implement ${path} --continue` }]
  }

  return [
    { key: 'implement', label: 'Build it', command: `/gku:implement ${path}` },
    { key: 'auto', label: 'Build it unattended', command: `/gku:implement --auto ${path}` },
    { key: 'plan-review', label: 'Judge the plan', command: `/gku:plan --review ${path}` },
  ]
}
