_obsbeam_complete() {
  local current=${COMP_WORDS[COMP_CWORD]}
  local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/obsbeam/vault"
  local vault=${OBSBEAM_VAULT:-}
  local note basename candidate lowered_current
  local -A seen=()

  COMPREPLY=()
  (( COMP_CWORD == 1 )) || return 0

  if [[ -z "$vault" && -f "$config_file" ]]; then
    IFS= read -r vault < "$config_file"
  fi
  [[ -d "$vault" ]] || return 0

  if [[ $current != obs/* ]]; then
    if [[ obs/ == "$current"* ]]; then
      COMPREPLY=("obs/")
      compopt -o nospace
    fi
    return 0
  fi

  lowered_current=${current,,}
  while IFS= read -r -d '' note; do
    basename=${note##*/}
    candidate="obs/$basename"
    [[ ${candidate,,} == "$lowered_current"* ]] || continue
    [[ ${seen[$candidate]+present} ]] && continue
    seen[$candidate]=1
    COMPREPLY+=("$candidate")
  done < <(
    find "$vault" -type f \( -name '*.md' -o -name '*.qmd' \) \
      -not -path "$vault/.obsidian/*" \
      -not -path "$vault/.trash/*" \
      -not -path "$vault/_slides/*" -print0
  )

  compopt -o filenames
}

complete -F _obsbeam_complete slide
