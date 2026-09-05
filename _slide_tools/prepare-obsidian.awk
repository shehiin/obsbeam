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

function trim(value) {
  gsub(/^[ \t]+|[ \t]+$/, "", value)
  return value
}

function expand_superscripts(value, output, i, character, next_index, digits) {
  output = ""
  for (i = 1; i <= length(value); i++) {
    character = substr(value, i, 1)
    if (character == "^" && substr(value, i + 1, 1) ~ /[0-9]/) {
      digits = ""
      next_index = i + 1
      while (substr(value, next_index, 1) ~ /[0-9]/) {
        digits = digits substr(value, next_index, 1)
        next_index++
      }
      output = output "^" digits "^"
      i = next_index - 1
    } else {
      output = output character
    }
  }
  return output
}

function emit_title_metadata() {
  print "---"
  print "title: >-"
  print "  " metadata_title
  if (metadata_text != "") {
    print "subtitle: >-"
    print "  " expand_superscripts(metadata_text)
  }
  if (metadata_name != "") {
    print "author: >-"
    print "  " expand_superscripts(metadata_name)
  }
  if (metadata_affiliation != "") {
    print "institute: >-"
    print "  " expand_superscripts(metadata_affiliation)
  }
  if (metadata_date != "") {
    print "obsbeam-date-text: >-"
    print "  " metadata_date
  }
  if (metadata_image != "") {
    print "obsbeam-title-image: >-"
    print "  " metadata_image
  }
  print "---"
  print ""
  simple_metadata = 0
}

function content_cost(line, plain, width, lines, overhead,
                      explicit_rows, row_scan, row_break) {
  plain = line
  gsub(/https?:\/\/[^ )]+/, "link", plain)
  gsub(/[*_`]/, "", plain)
  width = 82
  lines = int((length(plain) + width - 1) / width)
  if (lines < 1) lines = 1

  # Inline LaTeX matrices remain on one Markdown source line, but every `\\`
  # creates another rendered row and therefore consumes real vertical space.
  explicit_rows = 0
  row_scan = line
  while ((row_break = index(row_scan, "\\\\")) > 0) {
    explicit_rows++
    row_scan = substr(row_scan, row_break + 2)
  }
  lines += explicit_rows

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
  slide_cost = frame_margin_cost
}

function start_headingless_note() {
  current_title = metadata_title
  print "## " current_title " {.auto-note}"
  print ""
  section_has_content = 0
  after_figure = 0
  slide_cost = frame_margin_cost
}

BEGIN {
  default_title = ARGV[1]
  gsub(/\\/, "/", default_title)
  sub(/^.*\//, "", default_title)
  sub(/\.(md|qmd)$/, "", default_title)
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
  simple_metadata = !in_front_matter
  metadata_title = default_title
  metadata_text = ""
  metadata_name = "Shehin"
  metadata_affiliation = ""
  metadata_date = strftime("%b %Y")
  metadata_image = ""
  max_slide_cost = 18
  frame_margin_cost = 1
}

{
  # Ordinary notes get a title page named after the file. Optional simple
  # fields at the start override the title, author, affiliation, or logo.
  if (simple_metadata) {
    if (!nonblank($0)) next

    metadata_separator = index($0, ":")
    metadata_key = ""
    if (metadata_separator > 0) {
      metadata_key = tolower(trim(substr($0, 1, metadata_separator - 1)))
    }

    if (metadata_key == "title" || metadata_key == "text" ||
        metadata_key == "name" || metadata_key == "author" ||
        metadata_key == "affiliation" || metadata_key == "institution" ||
        metadata_key == "date" ||
        metadata_key == "image") {
      metadata_value = trim(substr($0, metadata_separator + 1))
      if (metadata_key == "title" && metadata_value != "") {
        metadata_title = metadata_value
      } else if (metadata_key == "text") {
        metadata_text = metadata_value
      } else if (metadata_key == "name" || metadata_key == "author") {
        metadata_name = metadata_value
      } else if (metadata_key == "affiliation" ||
                 metadata_key == "institution") {
        metadata_affiliation = metadata_value
      } else if (metadata_key == "date") {
        metadata_date = metadata_value
      } else if (metadata_key == "image") {
        metadata_image = metadata_value
      }
      next
    }

    emit_title_metadata()
  }

  # A headingless note would otherwise become one unbreakable Beamer frame.
  # Give it an automatic section named after the note so long content uses the
  # same threshold-based pagination as ordinary headed Obsidian notes.
  if (!in_front_matter && top_level == 0 && current_title == "" &&
      nonblank($0)) {
    start_headingless_note()
  }

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
      slide_cost = frame_margin_cost
    }
  }

  # One image-control grammar is supported:
  #   ![position 40%, optional caption](image.png)
  # An explicit position is authoritative and stays on the current slide.
  # Only `new` starts another slide.
  if ((top_level == 0 || top_level > 2) &&
      current_title != "" && level == 0) {
    image_start = match($0, /!\[[^]]*\]\([^)]*\)|!\[\[[^]]+\]\]/)
    if (image_start > 0) {
      before_image = substr($0, 1, RSTART - 1)
      image_markdown = substr($0, RSTART, RLENGTH)
      after_image_text = substr($0, RSTART + RLENGTH)
      standard_image_control = tolower(image_markdown)
      gsub(/[ \t]*\|[ \t]*[0-9]+(x[0-9]+)?[ \t]*\]\(/,
           "](", standard_image_control)
      new_frame = \
        (standard_image_control ~ /^!\[new[ \t]+[0-9]+([.][0-9]+)?%([ \t]*,[^]]*)?\]\(/)
      same_frame = !new_frame

      if (same_frame) {
        explicit_position = \
          (standard_image_control ~ /^!\[(left|right|up|down|topleft|topright|bottomleft|bottomright|grid)[ \t]+[0-9]+([.][0-9]+)?%([ \t]*,[^]]*)?\]\(/)
        # Same-slide images still obey the ordinary frame budget. Previously
        # this path added the image after pagination without checking the
        # existing text, allowing a tall mixed frame to enter the title area.
        corner_image = \
          (standard_image_control ~ /^!\[(topright|topleft|bottomright|bottomleft)[ \t]+[0-9]+([.][0-9]+)?%([ \t]*,[^]]*)?\]\(/)
        grid_image = \
          (standard_image_control ~ /^!\[grid[ \t]+[0-9]+([.][0-9]+)?%([ \t]*,[^]]*)?\]\(/)
        # Two corner images share one side column, so each consumes half of
        # the normal image budget. This keeps the pair together for layout.
        image_block_cost = grid_image ? 2.3 : (corner_image ? 3.5 : 7)
        if (nonblank(before_image)) {
          image_block_cost += content_cost(before_image)
        }
        if (nonblank(after_image_text) &&
            after_image_text !~ /^[ \t]*\{[^}]*\}[ \t]*$/) {
          image_block_cost += content_cost(after_image_text)
        }

        if (!explicit_position && section_has_content &&
            slide_cost + image_block_cost > max_slide_cost) {
          repeat_current_title()
        }

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
        slide_cost += image_block_cost
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
      slide_cost = 7 + frame_margin_cost
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
