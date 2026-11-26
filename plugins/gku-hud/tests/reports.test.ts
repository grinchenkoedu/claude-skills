import { expect, test } from 'claude-code/testing'

import { parseReport } from '../src/reports'

test('reads the skill and the slug of each report name the skills write', () => {
  const read = (file: string) => {
    const { skill, slug } = parseReport(file, 0)
    return [skill, slug]
  }

  expect(read('review-feature-guard-hook-20260906-185205.md')).toEqual(['review', 'feature-guard-hook'])
  expect(read('pr-review-pr-118-20260824-093700.md')).toEqual(['pr-review', 'pr-118'])
  expect(read('verify-security-pass-20260824-172230.md')).toEqual(['verify', 'security-pass'])
  expect(read('research-which-sso-provider-for-the-20260824-101512.md')).toEqual(['research', 'which-sso-provider-for-the'])
  expect(read('review-fix-remote-control-buttons-20261112-1822.md')).toEqual(['review', 'fix-remote-control-buttons'])
})

test('a name the scheme does not explain is a report under its own name', () => {
  expect(parseReport('notes.md', 3)).toEqual({ kind: 'report', file: 'notes.md', skill: 'report', slug: 'notes', mtimeMs: 3 })
  expect(parseReport('reviewer-notes-20260101-1200.md', 0).skill).toBe('report')
})
