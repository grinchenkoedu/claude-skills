// The pane's own types, and the values it keeps for the session in $.state.

/** One task file in .tasks/, as far as the pane reads it. */
export type TaskItem = {
  kind: 'task'
  /** The file's name in .tasks/, e.g. `gku-hud-sidebar.md`. */
  file: string
  /** Its `# ` heading, else the file name without `.md`. */
  title: string
  /** Its `**Type:**` line; absent when the file has none. */
  type?: string
  /** Top-level items of its `## Steps` section that are ticked `[x]`. */
  ticked: number
  /** Top-level items of its `## Steps` section; 0 when it has none. */
  total: number
  /** `**Mode:** manual`: written for a person to build by hand. */
  isManual: boolean
  /** Over the read limit, or refused: listed by name only. */
  isUnread: boolean
  mtimeMs: number
}

/** One report in .gku/reports/, as its name spells it. */
export type ReportItem = {
  kind: 'report'
  /** The file's name in .gku/reports/. */
  file: string
  /** What wrote it: `review`, `pr-review`, `verify`, `research`, … or `report` when the name says nothing. */
  skill: string
  /** The rest of the name, between the skill and the timestamp. */
  slug: string
  mtimeMs: number
}

export type Item = TaskItem | ReportItem

/** What the last scan of the project found. */
export type Scan = {
  tasks: TaskItem[]
  reports: ReportItem[]
  /** Task files beyond the read limit: listed by count only. */
  moreTasks: number
  at: number
}

/** The file shown in the preview: its key (`task:<file>` or `report:<file>`) and text. */
export type Preview = { key: string; text: string }

declare module 'claude-code' {
  interface PluginState {
    'gku-hud': {
      /** The last scan; null before the first. */
      scan: Scan | null
      /** The selected item's key, `task:<file>` or `report:<file>`; null when none is. */
      selected: string | null
      /** The selected file's text; null when none is selected or it could not be read. */
      preview: Preview | null
    }
  }
}
