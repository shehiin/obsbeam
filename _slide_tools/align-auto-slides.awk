# Finalize slides generated from ordinary Obsidian notes.
#
# Pagination has already happened in prepare-obsidian.awk against a fixed
# full-frame budget. This pass therefore cannot reduce the capacity of a
# slide: it centers every completed auto frame only after the split decisions.
# It also lays out same-slide images. Images default to the right; `left`,
# `right`, `up`, and `down` select placement, while `new` was handled earlier.
# Corner controls stack two images on one side: `topright` + `bottomright`, or
# `topleft` + `bottomleft`.

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

function image_position(line, alt, spec, parts) {
  alt = image_alt(line)
  spec = tolower(alt)
  sub(/[ \t]*,.*/, "", spec)
  sub(/[ \t]*\|[ \t]*[0-9]+([xX][0-9]+)?[ \t]*$/, "", spec)
  if (spec ~ /^(left|right|up|down|topleft|topright|bottomleft|bottomright|grid)[ \t]+[0-9]+([.][0-9]+)?%$/) {
    split(spec, parts, /[ \t]+/)
    return parts[1]
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

function standard_caption(alt, spec, caption, separator) {
  alt = trim(alt)
  if (alt == "") return ""
  sub(/[ \t]*\|[ \t]*[0-9]+([xX][0-9]+)?[ \t]*$/, "", alt)

  separator = index(alt, ",")
  if (separator > 0) {
    spec = tolower(trim(substr(alt, 1, separator - 1)))
    sub(/[ \t]*\|[ \t]*[0-9]+([xX][0-9]+)?[ \t]*$/, "", spec)
    if (spec !~ /^(left|right|up|down|topleft|topright|bottomleft|bottomright|grid|new)[ \t]+[0-9]+([.][0-9]+)?%$/) return alt
    caption = substr(alt, separator + 1)
    caption = trim(caption)
    sub(/[ \t]*\|[ \t]*[0-9]+([xX][0-9]+)?[ \t]*$/, "", caption)
    return caption
  }

  spec = tolower(alt)
  if (spec ~ /^(left|right|up|down|topleft|topright|bottomleft|bottomright|grid|new)[ \t]+[0-9]+([.][0-9]+)?%$/) return ""
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
    if (caption != "") return prefix "![right 100%, " caption "](" suffix
    return prefix "![right 100%](" suffix
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
      if (tolower(token) !~ /^(same|inline|left|right|topleft|topright|bottomleft|bottomright|grid|up|down|new|figure|separate)$/ &&
          tolower(token) !~ /^([0-9]+([.][0-9]+)?(%|px|cm|mm|in|em)?|[0-9]+x[0-9]+|fit|full)$/ &&
          tolower(token) !~ /^(width|w|height|h)[ \t]*=/) {
        kept = kept "|" token
      }
    }
    return prefix "![[" target "|100%" kept "]]" suffix
  }

  return line
}

function stacked_column_image(line, result) {
  result = column_image(line)
  if (result ~ /\{[^}]*\}[ \t]*$/) {
    sub(/\}[ \t]*$/, " height=\"24%\"}", result)
  } else {
    result = result "{height=\"24%\"}"
  }
  return result
}

function grid_column_image(line, result) {
  result = column_image(line)
  if (result ~ /\{[^}]*\}[ \t]*$/) {
    sub(/\}[ \t]*$/, " height=\"34%\"}", result)
  } else {
    result = result "{height=\"34%\"}"
  }
  return result
}

function centered_heading(heading, frame_class) {
  gsub(/\.auto-note[ \t]*/, "", heading)
  gsub(/\.(c|t|s|m)([ \t}]|$)/, "", heading)
  gsub(/[ \t]+}/, "}", heading)

  if (heading ~ /\{[ \t]*\}[ \t]*$/) {
    sub(/\{[ \t]*\}/, "{." frame_class "}", heading)
  } else if (heading ~ /\{[^}]*\}[ \t]*$/) {
    sub(/\{/, "{." frame_class " ", heading)
  } else {
    heading = heading " {." frame_class "}"
  }
  return heading
}

function print_without_image(image_index, i) {
  for (i = 2; i <= frame_count; i++) {
    if (i != image_index) print frame[i]
  }
}

function print_without_images(first_image, second_image, i) {
  for (i = 2; i <= frame_count; i++) {
    if (i != first_image && i != second_image) print frame[i]
  }
}

function image_side(position) {
  if (position == "left" || position == "topleft" ||
      position == "bottomleft") return "left"
  if (position == "right" || position == "topright" ||
      position == "bottomright") return "right"
  return ""
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

function print_stacked_side(first_image, second_image, side,
                            top_image, bottom_image, first_position,
                            second_position, image_width, candidate_width,
                            text_width) {
  first_position = image_position(frame[first_image])
  second_position = image_position(frame[second_image])
  top_image = first_image
  bottom_image = second_image
  if (first_position ~ /^bottom/ && second_position !~ /^bottom/) {
    top_image = second_image
    bottom_image = first_image
  }

  image_width = image_percent(frame[first_image])
  candidate_width = image_percent(frame[second_image])
  if (candidate_width > image_width) image_width = candidate_width
  if (image_width < 20) image_width = 20
  if (image_width > 62) image_width = 62
  text_width = 96 - image_width

  print ""
  print ":::: {.columns align=center .onlytextwidth}"
  if (side == "right") {
    print "::: {.column width=\"" text_width "%\"}"
    print_without_images(first_image, second_image)
    print ":::"
    print ""
  }

  print "::: {.column width=\"" image_width "%\"}"
  print stacked_column_image(frame[top_image])
  print ""
  print "\\vspace{0.18cm}"
  print ""
  print stacked_column_image(frame[bottom_image])
  print ":::"

  if (side == "left") {
    print ""
    print "::: {.column width=\"" text_width "%\"}"
    print_without_images(first_image, second_image)
    print ":::"
  }
  print "::::"
}

function print_three_grid(first_image, second_image, third_image, indexes, i) {
  indexes[1] = first_image
  indexes[2] = second_image
  indexes[3] = third_image
  print ""
  print ":::: {.columns align=top .onlytextwidth}"
  for (i = 1; i <= 3; i++) {
    print "::: {.column width=\"31%\"}"
    print grid_column_image(frame[indexes[i]])
    print ":::"
    if (i < 3) print ""
  }
  print "::::"
  delete indexes
}

function clear_buffer(i) {
  for (i = 1; i <= frame_count; i++) delete frame[i]
  frame_count = 0
  auto_frame = 0
}

function flush_frame(heading, frame_class, i, image_index, second_image_index,
                     third_image_index,
                     image_count, has_text, position, second_position,
                     side, second_side) {
  if (frame_count == 0) return

  if (!auto_frame) {
    for (i = 1; i <= frame_count; i++) print frame[i]
    clear_buffer()
    return
  }

  image_index = 0
  image_count = 0
  has_text = 0
  for (i = 2; i <= frame_count; i++) {
    if (is_image(frame[i])) {
      image_count++
      if (!image_index) image_index = i
      else if (!second_image_index) second_image_index = i
      else if (!third_image_index) third_image_index = i
    } else if (nonblank(frame[i])) {
      has_text = 1
    }
  }

  frame_class = (image_count > 0) ? "m" : "s"
  heading = centered_heading(frame[1], frame_class)
  print heading

  # Pandoc figure/column boxes contain invisible vertical glue. Compensate
  # only media frames so their visible pixels, rather than the hidden box,
  # receive the same optical centering as ordinary text frames.
  if (image_count > 0) {
    print ""
    if (has_text && image_count > 1) print "\\vspace*{0.45cm}"
    else if (has_text) print "\\vspace*{1.20cm}"
    else print "\\vspace*{0.60cm}"
  }

  if (image_count == 1 && has_text) {
    position = image_position(frame[image_index])
    side = image_side(position)
    if (side != "") {
      print_horizontal(image_index, side)
    } else if (position == "up") {
      print ""
      print frame[image_index]
      print_without_image(image_index)
    } else {
      print_without_image(image_index)
      print ""
      print frame[image_index]
    }
  } else if (image_count == 3 && !has_text &&
             image_position(frame[image_index]) == "grid" &&
             image_position(frame[second_image_index]) == "grid" &&
             image_position(frame[third_image_index]) == "grid") {
    print_three_grid(image_index, second_image_index, third_image_index)
  } else if (image_count == 2 && has_text) {
    position = image_position(frame[image_index])
    second_position = image_position(frame[second_image_index])
    side = image_side(position)
    second_side = image_side(second_position)
    if (side != "" && side == second_side &&
        (position ~ /^(top|bottom)/ || second_position ~ /^(top|bottom)/)) {
      print_stacked_side(image_index, second_image_index, side)
    } else {
      for (i = 2; i <= frame_count; i++) print frame[i]
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
