// Cuts the preview to a size in bytes, on a character boundary. Pure.
//
// The engines read a file differently: 2.1.332 honours the read's `length` and
// hands back that many bytes, a split character as U+FFFD; 2.1.316 ignores it and
// hands back the whole file. Cutting by bytes here makes the two show the same
// text, and makes "cut at 64 KiB" true of what is shown.

export type Cut = { text: string; isCut: boolean }

/** `text` whole while it fits in `maxBytes`; else its longest prefix of whole characters that does. */
export function cutPreview(text: string, maxBytes: number): Cut {
  const bytes = new TextEncoder().encode(text)
  if (bytes.length <= maxBytes) return { text, isCut: false }

  // bytes[end] is the first byte left out: while it continues a character, that
  // character straddles the limit, so step back to leave it out whole.
  let end = Math.max(0, maxBytes)
  while (end > 0 && ((bytes[end] ?? 0) & 0xc0) === 0x80) end -= 1

  return { text: new TextDecoder().decode(bytes.subarray(0, end)), isCut: true }
}
