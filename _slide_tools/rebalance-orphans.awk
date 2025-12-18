# Rebalance auto-generated continuation frames after pagination.
#
# If a continuation would contain exactly one top-level bullet, pull the last
# complete bullet block from the preceding frame. Nested bullets and paragraph
# continuations travel with their parent. Manual level-2 slides, images, and
# fenced code are never moved.

function nonblank(value, copy) {
  copy = value
  gsub(/[ \t]/, "", copy)
  return copy != ""
}

function is_top_bullet(line) {
  return line ~ /^[-+*][ \t]+/ || line ~ /^[0-9]+[.)][ \t]+/
}

function is_image(line) {
  return line ~ /!\[[^]]*\]\([^)]*\)|!\[\[[^]]+\]\]/
}

function frame_title(frame_number, title) {
  title = heading[frame_number]
  sub(/[ \t]+\{[^}]*\}[ \t]*$/, "", title)
  return title
}

function bullet_count(frame_number, count, i) {
  count = 0
  for (i = 1; i <= line_count[frame_number]; i++) {
    if (is_top_bullet(body[frame_number, i])) count++
  }
  return count
}

function first_bullet(frame_number, i) {
  for (i = 1; i <= line_count[frame_number]; i++) {
    if (is_top_bullet(body[frame_number, i])) return i
  }
  return 0
}

function last_bullet(frame_number, i) {
  for (i = line_count[frame_number]; i >= 1; i--) {
    if (is_top_bullet(body[frame_number, i])) return i
  }
  return 0
}

function has_lead_content(frame_number, first, i) {
  first = first_bullet(frame_number)
  if (!first) return 0
  for (i = 1; i < first; i++) {
    if (nonblank(body[frame_number, i])) return 1
  }
  return 0
}

function safe_singleton_frame(frame_number, first, i) {
  first = first_bullet(frame_number)
  if (!first) return 0

  # A continuation eligible for rebalancing contains only blank space before
  # its bullet and no figure/code block anywhere in the frame.
  for (i = 1; i < first; i++) {
    if (nonblank(body[frame_number, i])) return 0
  }
  for (i = 1; i <= line_count[frame_number]; i++) {
    if (is_image(body[frame_number, i]) ||
        body[frame_number, i] ~ /^(```+|~~~+)/) return 0
  }
  return 1
}

function move_last_bullet(previous, current, start, finish, i, old_count,
                          first_current, new_count) {
  start = last_bullet(previous)
  finish = line_count[previous]
  while (finish >= start && !nonblank(body[previous, finish])) finish--
  if (!start || finish < start) return 0

  for (i = start; i <= finish; i++) {
    if (is_image(body[previous, i]) ||
        body[previous, i] ~ /^(```+|~~~+)/) return 0
  }

  old_count = line_count[current]
  for (i = 1; i <= old_count; i++) scratch[i] = body[current, i]
  for (i = 1; i <= old_count; i++) delete body[current, i]

  first_current = 1
  while (first_current <= old_count && !nonblank(scratch[first_current])) {
    first_current++
  }

  new_count = 0
  body[current, ++new_count] = ""
  for (i = start; i <= finish; i++) {
    body[current, ++new_count] = body[previous, i]
  }
  body[current, ++new_count] = ""
  for (i = first_current; i <= old_count; i++) {
    body[current, ++new_count] = scratch[i]
  }
  line_count[current] = new_count

  for (i = start; i <= line_count[previous]; i++) delete body[previous, i]
  line_count[previous] = start - 1
  while (line_count[previous] > 0 &&
         !nonblank(body[previous, line_count[previous]])) {
    delete body[previous, line_count[previous]]
    line_count[previous]--
  }

  for (i = 1; i <= old_count; i++) delete scratch[i]
  return 1
}

{
  if ($0 ~ /^(```+|~~~+)/) in_fence = !in_fence

  if (!in_fence && $0 ~ /^##[ \t]+/) {
    frame_count++
    heading[frame_count] = $0
    auto_frame[frame_count] = ($0 ~ /\.auto-note([ \t}]|$)/)
    next
  }

  if (frame_count == 0) {
    prefix[++prefix_count] = $0
  } else {
    body[frame_count, ++line_count[frame_count]] = $0
  }
}

END {
  for (frame = 2; frame <= frame_count; frame++) {
    previous = frame - 1
    if (auto_frame[previous] && auto_frame[frame] &&
        frame_title(previous) == frame_title(frame) &&
        bullet_count(frame) == 1 && safe_singleton_frame(frame) &&
        bullet_count(previous) >= 2 &&
        (bullet_count(previous) >= 3 || has_lead_content(previous))) {
      move_last_bullet(previous, frame)
    }
  }

  for (i = 1; i <= prefix_count; i++) print prefix[i]
  for (frame = 1; frame <= frame_count; frame++) {
    print heading[frame]
    for (i = 1; i <= line_count[frame]; i++) print body[frame, i]
    print ""
  }
}
