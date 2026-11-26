// The selected task's steps as a bar of text. Pure. Drawn as text rather than
// a Progress element, which Claude Code 2.1.316 — the oldest the pane runs
// on — does not have.

/** `Steps ████░░░░ 2/4`: `width` cells of bar, filled in proportion. */
export function stepsBar(ticked: number, total: number, width = 12): string {
  const cells = Math.max(1, width)
  const share = total <= 0 ? 0 : Math.min(1, Math.max(0, ticked / total))
  const filled = Math.round(share * cells)

  return `Steps ${'█'.repeat(filled)}${'░'.repeat(cells - filled)} ${ticked}/${total}`
}
