# Prepare ordinary Obsidian Markdown before Quarto parses YAML.
# Preserve genuine leading YAML, remove later section-divider rules, and
# promote the note's shallowest section heading to Beamer slide level 2.

function heading_level(line, prefix) {
  if (match(line, /^#{1,6}[ \t]+/)) {
    prefix = substr(line, 1, RLENGTH)
    sub(/[ \t]+$/, "", prefix)
    return length(prefix)
  }
  return 0
}

function without_heading_markup(line, title) {
  title = line
  sub(/^#{1,6}[ \t]+/, "", title)
  sub(/[ \t]+\{[^}]*\}[ \t]*$/, "", title)
  return title
}

function nonblank(value, copy) {
  copy = value
  gsub(/[ \t]/, "", copy)
  return copy != ""
}

function content_cost(line, plain, width, lines, overhead) {
  plain = line
  gsub(/https?:\/\/[^ )]+/, "link", plain)
  gsub(/[*_`]/, "", plain)
  width = 82
  lines = int((length(plain) + width - 1) / width)
  if (lines < 1) lines = 1

  overhead = 0
  if (line ~ /^[-+*][ \t]+/ || line ~ /^[0-9]+[.)][ \t]+/) {
    overhead = 0.55
  } else if (line ~ /^[ \t]+[-+*][ \t]+/ ||
             line ~ /^[ \t]+[0-9]+[.)][ \t]+/) {
    overhead = 0.35
  }
  return lines + overhead
}

function safe_text_boundary(line) {
  # Never detach a nested list item from its parent. It can travel with the
  # parent until the next top-level item provides a safe split point.
  return line !~ /^[ \t]+[-+*][ \t]+/ &&
         line !~ /^[ \t]+[0-9]+[.)][ \t]+/
}

function repeat_current_title() {
  print ""
  print "## " current_title " {.auto-note}"
  print ""
  section_has_content = 0
  after_figure = 0
  slide_cost = 0
}

FNR == NR {
  if ($0 ~ /^(```+|~~~+)/) {
    scan_fence = !scan_fence
    next
  }

  if (!scan_fence) {
    level = heading_level($0)
    if (level >= 2 && (top_level == 0 || level < top_level)) {
      top_level = level
    }
  }
  next
}

FNR == 1 {
  in_front_matter = ($0 ~ /^---[ \t]*$/)
  max_slide_cost = 10.5
}

{
  if ($0 ~ /^(```+|~~~+)/) {
    print
    emit_fence = !emit_fence
    next
  }

  if (emit_fence) {
    print
    next
  }

  if (in_front_matter) {
    print
    if (FNR > 1 && $0 ~ /^---[ \t]*$/) {
      in_front_matter = 0
    }
    next
  }

  if ($0 ~ /^---[ \t]*$/) {
    # Obsidian notes commonly put `---` between headed sections. The heading
    # already starts a new frame, while the rule can become YAML or an empty
    # Beamer frame, so retain only safe paragraph separation.
    print ""
    print ""
    next
  }

  level = heading_level($0)
  if (top_level > 2 && level >= top_level) {
    new_level = level - top_level + 2
    prefix = ""
    for (i = 1; i <= new_level; i++) {
      prefix = prefix "#"
    }
    sub(/^#{1,6}/, prefix)

    if (level == top_level) {
      current_title = without_heading_markup($0)
      if ($0 ~ /\{[^}]*\}[ \t]*$/) {
        sub(/\{/, "{.auto-note ")
      } else {
        $0 = $0 " {.auto-note}"
      }
      section_has_content = 0
      after_figure = 0
      slide_cost = 0
    }
  }

  # Images stay with the current auto-promoted slide by default. Only an
  # explicit `new`/`figure`/`separate` control starts an image slide. The
  # following alignment pass arranges same-slide images at left/right/up/down.
  if (top_level > 2 && current_title != "" && level == 0) {
    image_start = match($0, /!\[[^]]*\]\([^)]*\)|!\[\[[^]]+\]\]/)
    if (image_start > 0) {
      before_image = substr($0, 1, RSTART - 1)
      image_markdown = substr($0, RSTART, RLENGTH)
      after_image_text = substr($0, RSTART + RLENGTH)
      standard_image_control = tolower(image_markdown)
      new_frame = \
        (tolower(image_markdown) ~ /\|(new|figure|separate)(\||\]\])/) || \
        (standard_image_control ~ /^!\[(new|figure|separate)([ :=|][^]]*)?\]\(/) || \
        ($0 ~ /\{[^}]*\.(new-slide|figure-slide|separate-slide)[^}]*\}/)
      same_frame = !new_frame

      if (same_frame) {
        if (after_figure) {
          repeat_current_title()
        }

        if (nonblank(before_image)) print before_image
        print ""
        if (after_image_text ~ /^[ \t]*\{[^}]*\}[ \t]*$/) {
          print image_markdown after_image_text
          after_image_text = ""
        } else {
          print image_markdown
        }
        print ""
        if (nonblank(after_image_text)) print after_image_text
        section_has_content = 1
        slide_cost += 7
        next
      }

      if (nonblank(before_image)) {
        if (after_figure) {
          repeat_current_title()
        }

        line_cost = content_cost(before_image)
        if (section_has_content && safe_text_boundary(before_image) &&
            slide_cost + line_cost > max_slide_cost) {
          repeat_current_title()
        }
        print before_image
        section_has_content = 1
        slide_cost += line_cost
      }

      if (section_has_content) {
        repeat_current_title()
      }
      print image_markdown
      if (nonblank(after_image_text)) print after_image_text
      section_has_content = 1
      slide_cost = 7
      after_figure = 1
      next
    }

    if (after_figure && nonblank($0)) {
      repeat_current_title()
    }

    if (nonblank($0)) {
      line_cost = content_cost($0)
      if (section_has_content && safe_text_boundary($0) &&
          slide_cost + line_cost > max_slide_cost) {
        repeat_current_title()
      }
      section_has_content = 1
      slide_cost += line_cost
    }
  }

  print
}
