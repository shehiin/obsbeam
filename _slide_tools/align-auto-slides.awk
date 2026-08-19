# Finalize slides generated from ordinary Obsidian notes.
#
# Pagination has already happened in prepare-obsidian.awk against a fixed
# full-frame budget. This pass therefore cannot reduce the capacity of a
# slide: it centers every completed auto frame only after the split decisions.
# It also lays out same-slide images. Images default to the right; `left`,
# `right`, `up`, and `down` select placement, while `new` was handled earlier.

function trim(value) {
  gsub(/^[ \t]+|[ \t]+$/, "", value)
  return value
}

function nonblank(value, copy) {
  copy = value
  gsub(/[ \t]/, "", copy)
  return copy != ""
}

function is_image(line) {
  return line ~ /!\[[^]]*\]\([^)]*\)|!\[\[[^]]+\]\]/
}

function image_alt(line, start, rest, close_pos) {
  start = index(line, "![")
  if (!start) return ""
  rest = substr(line, start + 2)
  close_pos = index(rest, "](")
  if (!close_pos) return ""
  return substr(rest, 1, close_pos - 1)
}

function image_position(line, lower, alt, inner, count, parts, i, token) {
  lower = tolower(line)
  alt = image_alt(line)
  if (alt != "") {
    split(tolower(alt), parts, /[ \t:|=]+/)
    for (i in parts) {
      token = parts[i]
      if (token == "left" || token == "right" ||
          token == "up" || token == "down") return token
      if (token == "same" || token == "inline") return "right"
    }
  }

  if (match(lower, /!\[\[[^]]+\]\]/)) {
    inner = substr(lower, RSTART + 3, RLENGTH - 5)
    count = split(inner, parts, "|")
    for (i = 2; i <= count; i++) {
      token = trim(parts[i])
      if (token == "left" || token == "right" ||
          token == "up" || token == "down") return token
      if (token == "same" || token == "inline") return "right"
    }
  }

  return "right"
}

function image_percent(line, value) {
  if (match(line, /[0-9]+([.][0-9]+)?%/)) {
    value = substr(line, RSTART, RLENGTH)
    sub(/%$/, "", value)
    return value + 0
  }
  # Horizontal layouts reserve 4% for column separation. By default the
  # image gets 44% and the text gets the remaining 52%.
  return 44
}

function visual_cost(line, plain, lines) {
  if (!nonblank(line) || is_image(line)) return 0
  plain = line
  gsub(/https?:\/\/[^ )]+/, "link", plain)
  gsub(/[*_`$]/, "", plain)
  lines = int((length(plain) + 81) / 82)
  if (lines < 1) lines = 1
  return lines
}

function print_full_page_center(image_count, has_text, cost, has_lead, shift) {
  # The title is an overlay and consumes no frame height. These small offsets
  # compensate only for invisible TeX list/figure glue so the visible body's
  # midpoint lands on the literal paper midpoint.
  if (!has_text) {
    if (image_count == 0) return
    shift = 0.60
  } else if (image_count > 0) {
    if (cost <= 4) shift = 1.60
    else if (cost <= 6) shift = 1.20
    else shift = 0.58
  } else {
    if (cost <= 3) shift = 1.40
    else if (cost <= 4) shift = 1.25
    else if (cost <= 6) shift = 1.20
    else if (cost <= 8) shift = (has_lead && cost >= 8) ? 0.95 : 1.10
    else shift = 0.65
  }

  print ""
  printf "\\vspace*{%.2fcm}\n", shift
}

function standard_caption(alt, spec, caption, separator) {
  alt = trim(alt)
  if (alt == "") return ""

  separator = index(alt, "|")
  if (!separator) separator = index(alt, ",")
  if (separator > 0) {
    caption = substr(alt, separator + 1)
    caption = trim(caption)
    if (tolower(caption) ~ /^([0-9]+([.][0-9]+)?(%|px|cm|mm|in|em)?|fit|full)$/ ||
        tolower(caption) ~ /^(width|w|height|h)[ \t]*=/) return ""
    return caption
  }

  spec = tolower(alt)
  if (spec ~ /^(same|inline|left|right|up|down|new|figure|separate)([ \t:=]|$)/ ||
      spec ~ /^([0-9]+([.][0-9]+)?(%|px|cm|mm|in|em)?|[0-9]+x[0-9]+|fit|full)$/ ||
      spec ~ /^(width|w|height|h)[ \t]*=/) return ""
  return alt
}

function column_image(line, alt, caption, start, rest, close_pos, prefix, suffix,
                      match_text, inner, count, parts, i, token, target, kept) {
  alt = image_alt(line)
  if (alt != "" || line ~ /!\[\]\(/) {
    caption = standard_caption(alt)
    start = index(line, "![")
    rest = substr(line, start + 2)
    close_pos = index(rest, "](")
    prefix = substr(line, 1, start - 1)
    suffix = substr(rest, close_pos + 2)
    if (caption != "") return prefix "![100%, " caption "](" suffix
    return prefix "![100%](" suffix
  }

  if (match(line, /!\[\[[^]]+\]\]/)) {
    prefix = substr(line, 1, RSTART - 1)
    suffix = substr(line, RSTART + RLENGTH)
    match_text = substr(line, RSTART, RLENGTH)
    inner = substr(match_text, 4, length(match_text) - 5)
    count = split(inner, parts, "|")
    target = parts[1]
    kept = ""
    for (i = 2; i <= count; i++) {
      token = trim(parts[i])
      if (tolower(token) !~ /^(same|inline|left|right|up|down|new|figure|separate)$/ &&
          tolower(token) !~ /^([0-9]+([.][0-9]+)?(%|px|cm|mm|in|em)?|[0-9]+x[0-9]+|fit|full)$/ &&
          tolower(token) !~ /^(width|w|height|h)[ \t]*=/) {
        kept = kept "|" token
      }
    }
    return prefix "![[" target "|100%" kept "]]" suffix
  }

  return line
}

function centered_heading(heading) {
  gsub(/\.auto-note[ \t]*/, "", heading)
  gsub(/\.(c|t)([ \t}]|$)/, "", heading)
  gsub(/[ \t]+}/, "}", heading)

  if (heading ~ /\{[ \t]*\}[ \t]*$/) {
    sub(/\{[ \t]*\}/, "{.c}", heading)
  } else if (heading ~ /\{[^}]*\}[ \t]*$/) {
    sub(/\{/, "{.c ", heading)
  } else {
    heading = heading " {.c}"
  }
  return heading
}

function print_without_image(image_index, i) {
  for (i = 2; i <= frame_count; i++) {
    if (i != image_index) print frame[i]
  }
}

function print_horizontal(image_index, position, image_width, text_width,
                          image_line) {
  image_width = image_percent(frame[image_index])
  if (image_width < 12) image_width = 12
  if (image_width > 72) image_width = 72
  text_width = 96 - image_width
  image_line = column_image(frame[image_index])

  print ""
  # onlytextwidth prevents Beamer's default column overhang, keeping the first
  # column exactly aligned with the frame title and ordinary body text.
  print ":::: {.columns align=center .onlytextwidth}"
  if (position == "left") {
    print "::: {.column width=\"" image_width "%\"}"
    print image_line
    print ":::"
    print ""
    print "::: {.column width=\"" text_width "%\"}"
    print_without_image(image_index)
    print ":::"
  } else {
    print "::: {.column width=\"" text_width "%\"}"
    print_without_image(image_index)
    print ":::"
    print ""
    print "::: {.column width=\"" image_width "%\"}"
    print image_line
    print ":::"
  }
  print "::::"
}

function clear_buffer(i) {
  for (i = 1; i <= frame_count; i++) delete frame[i]
  frame_count = 0
  auto_frame = 0
}

function flush_frame(heading, i, image_index, image_count, has_text, position,
                     body_cost, has_lead) {
  if (frame_count == 0) return

  if (!auto_frame) {
    for (i = 1; i <= frame_count; i++) print frame[i]
    clear_buffer()
    return
  }

  heading = centered_heading(frame[1])
  print heading

  image_index = 0
  image_count = 0
  has_text = 0
  body_cost = 0
  has_lead = 0
  for (i = 2; i <= frame_count; i++) {
    if (is_image(frame[i])) {
      image_count++
      if (!image_index) image_index = i
    } else if (nonblank(frame[i])) {
      has_text = 1
      body_cost += visual_cost(frame[i])
      if (frame[i] ~ /^\[[^]]+\]\([^)]*\)[ \t]*$/) has_lead = 1
    }
  }

  print_full_page_center(image_count, has_text, body_cost, has_lead)

  if (image_count == 1 && has_text) {
    position = image_position(frame[image_index])
    if (position == "left" || position == "right") {
      print_horizontal(image_index, position)
    } else if (position == "up") {
      print ""
      print frame[image_index]
      print_without_image(image_index)
    } else {
      print_without_image(image_index)
      print ""
      print frame[image_index]
    }
  } else {
    for (i = 2; i <= frame_count; i++) print frame[i]
  }

  # A blank line is required after an image paragraph; otherwise Pandoc can
  # interpret the following `##` as literal caption text instead of a frame.
  print ""
  clear_buffer()
}

{
  if ($0 ~ /^(```+|~~~+)/) in_fence = !in_fence

  if (!in_fence && $0 ~ /^##[ \t]+/) {
    flush_frame()
    frame_count = 1
    frame[1] = $0
    auto_frame = ($0 ~ /\.auto-note([ \t}]|$)/)
    next
  }

  if (frame_count == 0) {
    print
    next
  }

  frame[++frame_count] = $0
}

END {
  flush_frame()
}
