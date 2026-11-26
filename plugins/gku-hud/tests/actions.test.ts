import { describe, expect, test } from 'claude-code/testing'

import { actionsFor, argument, isSafeName } from '../src/actions'
import { parseReport } from '../src/reports'
import type { TaskItem } from '../types'

const task = (over: Partial<TaskItem>): TaskItem => ({
  kind: 'task', file: 'export.md', title: 'Export', ticked: 0, total: 3, isManual: false, isUnread: false, mtimeMs: 0, ...over,
})
const commands = (item: Parameters<typeof actionsFor>[0]) => actionsFor(item).map(a => a.command)

describe('a task', () => {
  test('not started: build, build unattended, or judge the plan', () => {
    expect(commands(task({}))).toEqual([
      '/gku:implement .tasks/export.md',
      '/gku:implement --auto .tasks/export.md',
      '/gku:plan --review .tasks/export.md',
    ])
  })

  test('partly built: resume', () => {
    expect(commands(task({ ticked: 1 }))).toEqual(['/gku:implement .tasks/export.md --continue'])
  })

  test('every step ticked: review and verify', () => {
    expect(commands(task({ ticked: 3 }))).toEqual(['/gku:review', '/gku:verify'])
  })

  test('a brief with no steps: plan it or build it', () => {
    expect(commands(task({ total: 0 }))).toEqual(['/gku:plan .tasks/export.md', '/gku:implement .tasks/export.md'])
  })

  test('a manual plan offers no build, and its review says manual', () => {
    expect(commands(task({ isManual: true }))).toEqual([])
    expect(commands(task({ isManual: true, ticked: 1 }))).toEqual([])
    expect(commands(task({ isManual: true, ticked: 3 }))).toEqual(['/gku:review --manual', '/gku:verify'])
  })

  test('a file it could not read offers nothing', () => {
    expect(commands(task({ isUnread: true }))).toEqual([])
  })

  test('a name with a space is quoted; a name with a quote or a leading dash offers nothing', () => {
    expect(commands(task({ file: 'my plan.md', ticked: 1 }))).toEqual(['/gku:implement ".tasks/my plan.md" --continue'])
    expect(commands(task({ file: 'a"b.md' }))).toEqual([])
    expect(commands(task({ file: '-x.md' }))).toEqual([])
  })

  test('each action has its own key', () => {
    for (const item of [task({}), task({ ticked: 1 }), task({ ticked: 3 }), task({ total: 0 })]) {
      const keys = actionsFor(item).map(a => a.key)
      expect(new Set(keys).size).toBe(keys.length)
    }
  })
})

describe('a report', () => {
  test('a review offers its fix; other reports offer nothing', () => {
    expect(commands(parseReport('review-my-branch-20260824-143201.md', 0))).toEqual(['/gku:fix .gku/reports/review-my-branch-20260824-143201.md'])
    expect(commands(parseReport('pr-review-pr-3-20260831-173336.md', 0))).toEqual([])
    expect(commands(parseReport('verify-x-20260824-172230.md', 0))).toEqual([])
  })
})

test('argument and isSafeName', () => {
  expect(argument('.tasks/a.md')).toBe('.tasks/a.md')
  expect(argument('.tasks/a b.md')).toBe('".tasks/a b.md"')
  expect(isSafeName('a.md')).toBe(true)
  expect(isSafeName('')).toBe(false)
  expect(isSafeName('a\nb.md')).toBe(false)
  expect(isSafeName("a'b.md")).toBe(false)
})
