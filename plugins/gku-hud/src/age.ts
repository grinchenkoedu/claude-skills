// How long ago a file changed, in the fewest characters a row can spare. Pure.

const MINUTE = 60_000
const HOUR = 60 * MINUTE
const DAY = 24 * HOUR

/** `now`, `5m`, `3h`, `2d`, `6w`: from the file's mtime to the clock's now. */
export function age(now: number, then: number): string {
  const gone = Math.max(0, now - then)
  if (gone < MINUTE) return 'now'
  if (gone < HOUR) return `${Math.floor(gone / MINUTE)}m`
  if (gone < DAY) return `${Math.floor(gone / HOUR)}h`
  if (gone < 14 * DAY) return `${Math.floor(gone / DAY)}d`

  return `${Math.floor(gone / (7 * DAY))}w`
}
