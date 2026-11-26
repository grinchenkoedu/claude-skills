import { expect, test } from 'claude-code/testing'

import { stepsBar } from '../src/bar'

test('the bar fills in proportion, and holds at its ends', () => {
  expect(stepsBar(0, 4, 4)).toBe('Steps ░░░░ 0/4')
  expect(stepsBar(2, 4, 4)).toBe('Steps ██░░ 2/4')
  expect(stepsBar(4, 4, 4)).toBe('Steps ████ 4/4')
  expect(stepsBar(5, 4, 4)).toBe('Steps ████ 5/4')
  expect(stepsBar(1, 0, 4)).toBe('Steps ░░░░ 1/0')
  expect(stepsBar(1, 3, 0)).toBe('Steps ░ 1/3')
})
