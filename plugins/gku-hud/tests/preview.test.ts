import { describe, expect, test } from 'claude-code/testing'

import { cutPreview } from '../src/preview'

const bytes = (text: string) => new TextEncoder().encode(text).length

describe('cutPreview', () => {
  test('text that fits is returned whole, the exact limit included', () => {
    expect(cutPreview('', 8)).toEqual({ text: '', isCut: false })
    expect(cutPreview('abcd', 8)).toEqual({ text: 'abcd', isCut: false })
    expect(cutPreview('abcdefgh', 8)).toEqual({ text: 'abcdefgh', isCut: false })
    expect(cutPreview('éééé', 8)).toEqual({ text: 'éééé', isCut: false })
  })

  test('ASCII over the limit is cut at the limit', () => {
    expect(cutPreview('abcdefghij', 8)).toEqual({ text: 'abcdefgh', isCut: true })
  })

  // Each width at every offset against the limit: the character that straddles it is left out whole.
  for (const [name, char] of [['2-byte é', 'é'], ['3-byte 字', '字'], ['4-byte 😀', '😀']] as const) {
    test(`a ${name} straddling the limit is left out whole, at every offset`, () => {
      const width = bytes(char)
      for (let lead = 0; lead < width; lead++) {
        const text = `${'a'.repeat(lead)}${char.repeat(10)}`
        const limit = lead + width * 3 + 1
        const { text: shown, isCut } = cutPreview(text, limit)
        expect(isCut).toBe(true)
        expect(shown).toBe(`${'a'.repeat(lead)}${char.repeat(3)}`)
        expect(bytes(shown)).toBeLessThan(limit + 1)
        expect(shown.includes('\uFFFD')).toBe(false)
      }
    })
  }

  test('a U+FFFD the file holds before the limit is kept', () => {
    expect(cutPreview('ab\uFFFDcdefgh', 6)).toEqual({ text: 'ab\uFFFDc', isCut: true })
  })

  test('a U+FFFD a ranged read put past the limit is cut with the rest', () => {
    // 4 bytes of é, then the stand-in a 2-byte read of the next é decodes to.
    expect(cutPreview('éé\uFFFD', 4)).toEqual({ text: 'éé', isCut: true })
  })

  test('a limit of zero or less shows nothing, and says it is cut', () => {
    expect(cutPreview('abc', 0)).toEqual({ text: '', isCut: true })
    expect(cutPreview('abc', -1)).toEqual({ text: '', isCut: true })
  })
})
