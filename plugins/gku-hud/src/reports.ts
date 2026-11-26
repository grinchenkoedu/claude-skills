// Reads a report's name the way reference/reports.md spells it:
// <skill>-<slug>-<YYYYMMDD>-<HHMM[SS]>.md. Pure.

import type { ReportItem } from '../types'
import { clean } from './tasks'

/** The skills that write reports, longest first so `pr-review` wins over `review`. */
export const REPORT_SKILLS = ['pr-review', 'research', 'review', 'verify', 'audit'] as const

const STAMPED = /^(.*?)-(\d{8}-\d{4,6})$/

/** The summary of one report, from its name and when it last changed. */
export function parseReport(file: string, mtimeMs: number): ReportItem {
  const base = file.replace(/\.md$/i, '')
  const stamped = STAMPED.exec(base)
  const rest = stamped?.[1] ?? base
  const skill = REPORT_SKILLS.find(name => rest === name || rest.startsWith(`${name}-`))
  const slug = skill === undefined ? rest : rest.slice(skill.length + 1)

  return { kind: 'report', file, skill: skill ?? 'report', slug: clean(slug, 80), mtimeMs }
}
