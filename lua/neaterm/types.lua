---@meta

---@class NeatermConfig
---@field shell string
---@field float_width number
---@field float_height number
---@field move_amount number
---@field resize_amount number
---@field border string
---@field keymap_control KeymapControl
---@field highlights HighlightConfig
---@field min_width number
---@field min_height number
---@field default_type string
---@field auto_insert boolean
---@field auto_close boolean
---@field clear_env boolean
---@field persist_size boolean
---@field persist_mode boolean
---@field set_title boolean
---@field show_number boolean
---@field keymaps KeymapConfig
---@field repl ReplConfig
---@field repl_configs table<string, ReplLangConfig>
---@field integrations IntegrationConfig

---@class KeymapControl
---@field disable_keymaps boolean
---@field enable_commands boolean

---@class HighlightConfig
---@field normal string
---@field border string
---@field title string
---@field active string
---@field repl string

---@class KeymapConfig
---@field toggle string
---@field new_vertical string
---@field new_horizontal string
---@field new_float string
---@field close string
---@field next string
---@field prev string
---@field move_up string
---@field move_down string
---@field move_left string
---@field move_right string
---@field resize_up string
---@field resize_down string
---@field resize_left string
---@field resize_right string
---@field focus_bar string
---@field repl_toggle string
---@field repl_send_line string
---@field repl_send_selection string
---@field repl_send_buffer string
---@field repl_clear string
---@field repl_history string
---@field repl_variables string
---@field repl_restart string

---@class ReplConfig
---@field float_width number
---@field float_height number
---@field save_history boolean
---@field history_file string
---@field max_history number
---@field update_interval number
---@field auto_complete boolean
---@field show_line_numbers boolean
---@field show_diagnostics boolean
---@field indent_lines boolean

---@class ReplLangConfig
---@field name string
---@field cmd string
---@field paste_cmd? string
---@field startup_cmds? string[]
---@field get_variables_cmd? string
---@field inspect_variable_cmd? string
---@field delete_variable_cmd? string
---@field exit_cmd string
---@field file_patterns string[]
---@field diagnostics? DiagnosticConfig

---@class DiagnosticConfig
---@field enable boolean
---@field patterns table<string, string>

---@class IntegrationConfig
---@field which_key boolean
---@field telescope boolean
---@field nvim_cmp boolean
---@field treesitter boolean
---@field dap boolean

---@class Terminal
---@field job_id number
---@field win number
---@field type string
---@field cmd string

---@class Repl
---@field buf number
---@field filetype string
---@field config ReplLangConfig
---@field type string

---@class TerminalState
---@field size { width: number, height: number }
---@field mode string

---@class Neaterm
---@field opts NeatermConfig
---@field terminals table<number, Terminal>
---@field current_terminal number|nil
---@field current_repl Repl|nil
---@field history table<string, string[]>
---@field variables table<string, any>
---@field terminal_states table<number, TerminalState>
---@field bar_win number|nil
---@field bar_buf number|nil

return {} 