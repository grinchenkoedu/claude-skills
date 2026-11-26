import { expect, test } from 'claude-code/testing'

import { age } from '../src/age'

test('age reads minutes, hours, days, then weeks, and never goes negative', () => {
  const at = (ms: number) => age(1_000_000_000_000 + ms, 1_000_000_000_000)
  const MINUTE = 60_000
  expect(at(-5 * MINUTE)).toBe('now')
  expect(at(59_999)).toBe('now')
  expect(at(MINUTE)).toBe('1m')
  expect(at(59 * MINUTE)).toBe('59m')
  expect(at(60 * MINUTE)).toBe('1h')
  expect(at(24 * 60 * MINUTE)).toBe('1d')
  expect(at(13 * 24 * 60 * MINUTE)).toBe('13d')
  expect(at(14 * 24 * 60 * MINUTE)).toBe('2w')
})
