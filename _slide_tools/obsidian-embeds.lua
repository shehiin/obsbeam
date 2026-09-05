-- Convert Obsidian image/media embeds, resolve their paths, and emit native
-- RichMedia annotations for recent Firefox/PDF.js releases.
-- Supported examples:
--   ![[image.png]]
--   ![[attachments/image.png|full]]
--   ![[image.png|75%]]
--   ![[image.png|width=60%]]
--   ![[image.png|height=70%]]
--   ![[image.png|fit]]
--   ![[image.png|800x450]]

local image_extensions = {
  png = true, jpg = true, jpeg = true, pdf = true, svg = true,
  eps = true, tif = true, tiff = true, webp = true
}

local media_extensions = {
  mp4 = { subtype = "Video", mime = "video/mp4", ratio = { 9, 16 } },
  m4v = { subtype = "Video", mime = "video/x-m4v", ratio = { 9, 16 } },
  webm = { subtype = "Video", mime = "video/webm", ratio = { 9, 16 } },
  ogv = { subtype = "Video", mime = "video/ogg", ratio = { 9, 16 } },
  mov = { subtype = "Video", mime = "video/quicktime", ratio = { 9, 16 } },
  mp3 = { subtype = "Sound", mime = "audio/mpeg", ratio = { 1, 5 } },
  m4a = { subtype = "Sound", mime = "audio/mp4", ratio = { 1, 5 } },
  wav = { subtype = "Sound", mime = "audio/wav", ratio = { 1, 5 } },
  oga = { subtype = "Sound", mime = "audio/ogg", ratio = { 1, 5 } },
  ogg = { subtype = "Sound", mime = "audio/ogg", ratio = { 1, 5 } }
}

local vault_root = nil
local source_dir = nil
local attachment_dirs = { "attachments" }

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize(path)
  path = path:gsub("\\", "/")
  path = path:gsub("/+", "/")
  path = path:gsub("/%./", "/")
  return path
end

local function is_absolute(path)
  return path:match("^/") ~= nil or path:match("^%a:[/\\]") ~= nil
end

local function join(left, right)
  if not left or left == "" then return normalize(right) end
  if not right or right == "" then return normalize(left) end
  return normalize(left:gsub("/$", "") .. "/" .. right:gsub("^/", ""))
end

local function dirname(path)
  local normalized = normalize(path)
  return normalized:match("^(.*)/[^/]*$") or "."
end

local function basename(path)
  return normalize(path):match("([^/]+)$") or path
end

local function exists(path)
  local handle = io.open(path, "rb")
  if handle then
    handle:close()
    return true
  end
  return false
end

local function is_remote(path)
  return path:match("^https?://") ~= nil or path:match("^data:") ~= nil
end

local function is_image_path(path)
  local clean = path:gsub("[?#].*$", "")
  local extension = clean:match("%.([^./]+)$")
  return extension and image_extensions[extension:lower()] or false
end

local function media_type(path)
  local clean = path:gsub("[?#].*$", "")
  local extension = clean:match("%.([^./]+)$")
  return extension and media_extensions[extension:lower()] or nil
end

local function is_media_path(path)
  return media_type(path) ~= nil
end

local function metadata_strings(value)
  local result = {}
  if not value then return result end
  if type(value) == "table" and #value > 0 then
    for _, item in ipairs(value) do
      table.insert(result, pandoc.utils.stringify(item))
    end
  else
    table.insert(result, pandoc.utils.stringify(value))
  end
  return result
end

local function resolve_asset(path)
  path = trim(path)
  if is_remote(path) then return path end

  local candidates = {}
  local seen = {}
  local function add(candidate)
    if candidate and candidate ~= "" then
      candidate = normalize(candidate)
      if not seen[candidate] then
        seen[candidate] = true
        table.insert(candidates, candidate)
      end
    end
  end

  if is_absolute(path) then
    add(path)
  else
    add(join(source_dir, path))
    add(join(vault_root, path))
    for _, directory in ipairs(attachment_dirs) do
      add(join(join(source_dir, directory), path))
      add(join(join(vault_root, directory), path))
      add(join(join(vault_root, directory), basename(path)))
    end
  end

  for _, candidate in ipairs(candidates) do
    if exists(candidate) then return candidate end
  end

  error(
    "Obsidian asset not found: " .. path ..
    "\nSearched:\n  " .. table.concat(candidates, "\n  ") ..
    "\nMove the file into attachments/ or use an explicit vault-relative path."
  )
end

local function resolve_image(path)
  return resolve_asset(path)
end

local function normalize_pdflatex_unicode(document)
  return document:walk({
    Str = function(inline)
      inline.text = inline.text:gsub("​", "")
      return inline
    end,
    Math = function(math)
      local value = math.text:gsub("​", "")
      value = value:gsub("π", "\\pi ")
      value = value:gsub("θ", "\\theta ")
      value = value:gsub("λ", "\\lambda ")
      value = value:gsub("σ", "\\sigma ")
      value = value:gsub("τ", "\\tau ")
      value = value:gsub("ℓ", "\\ell ")
      value = value:gsub("∣", "\\mid ")
      value = value:gsub("−", "-")
      value = value:gsub("…", "\\ldots ")
      value = value:gsub("≤", "\\leq ")
      value = value:gsub("≥", "\\geq ")
      value = value:gsub("→", "\\rightarrow ")
      math.text = value
      return math
    end
  })
end

local function is_size_hint(value)
  local lower = value:lower()
  return lower:match("^%d+$") ~= nil or
         lower:match("^%d+%.?%d*%%$") ~= nil or
         lower:match("^%d+[xX]%d*$") ~= nil
end

local function parse_size(option)
  local attributes = {}
  local alt = ""
  local size_option = nil
  local caption_option = nil
  -- Wiki embeds remain supported for pasted Obsidian images and Obsidian's
  -- numeric resize metadata. Layout controls use standard Markdown only.
  if option and option ~= "" then
    for token in option:gmatch("[^|]+") do
      local cleaned = trim(token)
      if is_size_hint(cleaned) then
        if not size_option then size_option = cleaned end
      elseif not caption_option then
        caption_option = cleaned
      end
    end
  end

  option = size_option
  alt = caption_option or ""

  if not option or option == "" then
    attributes.width = "92%"
    return attributes, alt
  end

  option = trim(option)
  local lower = option:lower()

  if lower == "full" then
    attributes.width = "100%"
  elseif lower == "fit" then
    attributes.width = "100%"
    attributes.height = "82%"
  elseif lower:match("^%d+$") then
    attributes.width = lower .. "px"
  elseif lower:match("^%d+%.?%d*%%$") then
    attributes.width = lower
  elseif lower:match("^%d+%.?%d*px$") or
         lower:match("^%d+%.?%d*cm$") or
         lower:match("^%d+%.?%d*mm$") or
         lower:match("^%d+%.?%d*in$") or
         lower:match("^%d+%.?%d*em$") then
    attributes.width = lower
  elseif lower:match("^%d+x%d+$") then
    local width, height = lower:match("^(%d+)x(%d+)$")
    attributes.width = width .. "px"
    attributes.height = height .. "px"
  elseif lower:match("^width%s*=") or lower:match("^w%s*=") then
    local value = trim(lower:match("=%s*(.+)$"))
    if value:match("^%d+$") then value = value .. "px" end
    attributes.width = value
  elseif lower:match("^height%s*=") or lower:match("^h%s*=") then
    local value = trim(lower:match("=%s*(.+)$"))
    if value:match("^%d+$") then value = value .. "px" end
    attributes.height = value
  else
    attributes.width = "92%"
  end

  if not attributes.height then attributes.height = "68%" end

  return attributes, alt
end

local function parse_standard_alt(option)
  option = trim(option or "")
  if option == "" then return nil end

  local caption = ""
  local spec = option
  local before_comma, after_comma = option:match("^(.-)%s*,%s*(.*)$")
  if before_comma then
    spec = trim(before_comma)
    caption = trim(after_comma)
  end

  -- Obsidian may append its visual width after the layout specification:
  -- `right 40% |370`. It is editor metadata, not part of the public syntax.
  spec = trim(spec:gsub("%s*|%s*%d+[xX]%d+%s*$", "")
                  :gsub("%s*|%s*%d+%s*$", ""))

  -- Obsidian may append its visual image width to the alt text, for example
  -- `Figure: Setup|429`. Keep that metadata in the note, but never print it
  -- as part of the PDF caption.
  caption = trim(caption:gsub("%s*|%s*%d+[xX]%d+%s*$", "")
                        :gsub("%s*|%s*%d+%s*$", ""))

  -- One public layout grammar only:
  --   ![position 40%, optional caption](image.png)
  local placement, size = spec:match("^([%a]+)%s+(%d+%.?%d*%%)$")
  placement = placement and placement:lower() or nil
  local valid = {
    left = true, right = true, up = true, down = true,
    topleft = true, topright = true,
    bottomleft = true, bottomright = true,
    grid = true, new = true
  }
  if not placement or not valid[placement] then return nil end

  local attributes = parse_size(size)
  return attributes, caption, placement
end

local function bytes_to_hex(value)
  return (value:gsub(".", function(character)
    return string.format("%02X", string.byte(character))
  end))
end

local function tex_dimension(value, axis, fallback)
  value = trim(value or "")
  if value == "" then return fallback end

  local percent = value:match("^(%d+%.?%d*)%%$")
  if percent then
    local fraction = tonumber(percent) / 100
    local base = axis == "width" and "\\linewidth" or "\\textheight"
    local formatted = string.format("%.4f", fraction)
      :gsub("0+$", "")
      :gsub("%.$", "")
    return formatted .. base
  end

  local pixels = value:match("^(%d+%.?%d*)px$")
  if pixels then
    return string.format("%.3fbp", tonumber(pixels) * 0.75)
  end

  if value:match("^%d+%.?%d*(cm|mm|in|em|pt|bp)$") then return value end
  return fallback
end

local function build_media(image, is_wikilink)
  if is_remote(image.src) then
    error("Remote media cannot be embedded in the PDF: " .. image.src ..
      "\nDownload it into the vault and embed the local file instead.")
  end

  local attributes = {}
  local caption = ""
  local option = trim(pandoc.utils.stringify(image.caption))

  if is_wikilink then
    if option == image.src or option == basename(image.src) then option = nil end
    attributes, caption = parse_size(option)
  else
    local control_attributes, control_caption = parse_standard_alt(option)
    if control_attributes then
      attributes = control_attributes
      caption = control_caption
    else
      attributes = parse_size(nil)
      caption = option
    end
  end

  for key, value in pairs(image.attributes) do attributes[key] = value end

  local kind = media_type(image.src)
  local path = resolve_asset(image.src)
  if path:find("[{}]") then
    error("Media paths containing braces are not supported: " .. path)
  end

  local width = tex_dimension(attributes.width, "width", "0.92\\linewidth")
  local height_fallback = kind.subtype == "Sound" and "1.40cm" or
    "0.68\\textheight"
  local height = tex_dimension(attributes.height, "height", height_fallback)
  local filename = basename(path)
  local latex = string.format(
    "\\obsbeammedia{\\detokenize{%s}}{%s}{%s}{%s}{%s}{%d}{%d}{%s}",
    path,
    bytes_to_hex(filename),
    kind.subtype,
    width,
    height,
    kind.ratio[1],
    kind.ratio[2],
    kind.mime
  )

  return pandoc.Span(
    { pandoc.RawInline("latex", latex) },
    pandoc.Attr("", { "obsbeam-media" }, {
      { "data-caption", caption }
    })
  )
end

local function build_image(inner)
  local target, option = inner:match("^([^|]+)|(.+)$")
  if not target then target = inner end
  target = trim(target)

  if not is_image_path(target) then return nil end

  local attributes, alt = parse_size(option)
  local key_values = {}
  for key, value in pairs(attributes) do
    table.insert(key_values, { key, value })
  end

  return pandoc.Image(
    alt == "" and {} or { pandoc.Str(alt) },
    resolve_image(target),
    "",
    pandoc.Attr("", { "obsidian-embed" }, key_values)
  )
end

local function replace_embeds(inlines)
  local output = pandoc.Inlines({})
  local index = 1

  while index <= #inlines do
    local current = inlines[index]
    if current.t == "Str" and current.text:match("^%[%[") then
      local original = pandoc.Inlines({ current })
      local combined = current.text
      local cursor = index + 1

      while not combined:match("%]%]") and cursor <= #inlines do
        local next_inline = inlines[cursor]
        original:insert(next_inline)
        if next_inline.t == "Str" then
          combined = combined .. next_inline.text
        elseif next_inline.t == "Space" then
          combined = combined .. " "
        else
          break
        end
        cursor = cursor + 1
      end

      local inner, suffix = combined:match("^%[%[(.-)%]%](.*)$")
      local image = inner and build_image(inner) or nil
      if image then
        output:insert(image)
        if suffix and suffix ~= "" then output:insert(pandoc.Str(suffix)) end
        index = cursor
      else
        output:extend(original)
        index = cursor
      end
    else
      output:insert(current)
      index = index + 1
    end
  end

  return output
end

local function configure(meta)
  vault_root = os.getenv("OBSIDIAN_VAULT_ROOT")
  if not vault_root or vault_root == "" then
    vault_root = pandoc.system.get_working_directory()
  end

  source_dir = os.getenv("OBSIDIAN_SOURCE_DIR")
  if not source_dir or source_dir == "" then
    local input = PANDOC_STATE.input_files[1]
    source_dir = input and dirname(input) or vault_root
  end

  local configured = metadata_strings(meta["obsidian-attachments"])
  if #configured > 0 then attachment_dirs = configured end

  vault_root = normalize(vault_root)
  source_dir = normalize(source_dir)
end

local function configure_title_image(document)
  local configured = document.meta["obsbeam-title-image"]
  if not configured then return end

  local path = trim(pandoc.utils.stringify(configured))
  local wiki_target = path:match("^!%[%[(.-)%]%]$")
  if wiki_target then
    path = trim(wiki_target:match("^([^|]+)") or wiki_target)
  end
  if path == "" then return end

  document.meta.titlegraphic = pandoc.MetaList({
    pandoc.MetaString(resolve_image(path))
  })
  document.meta.titlegraphicoptions = pandoc.MetaList({
    pandoc.MetaString("width=1.94cm"),
    pandoc.MetaString("height=1.33cm"),
    pandoc.MetaString("keepaspectratio")
  })
  document.meta["obsbeam-title-image"] = nil
end

local function superscript_metadata(value)
  if not value then return value end

  local source = pandoc.utils.stringify(value)
  if not source:match("%^(%d+)") then return value end

  source = source:gsub("%^(%d+)", "^%1^")
  local parsed = pandoc.read(source, "markdown+superscript")
  for _, block in ipairs(parsed.blocks) do
    if block.t == "Para" or block.t == "Plain" then
      return pandoc.MetaInlines(block.content)
    end
  end
  return value
end

local function configure_title_superscripts(document)
  document.meta.author = superscript_metadata(document.meta.author)
  document.meta.institute = superscript_metadata(document.meta.institute)
  document.meta.subtitle = superscript_metadata(document.meta.subtitle)
end

local function configure_title_date(document)
  local configured = document.meta["obsbeam-date-text"]
  if not configured then return end

  local value = trim(pandoc.utils.stringify(configured))
  document.meta["obsbeam-date-text"] = nil
  if value == "" then
    document.meta.date = nil
    return
  end

  document.meta.date = pandoc.MetaInlines({
    pandoc.RawInline("latex", value)
  })
end

local function compile_tikz_block(block)
  local is_tikz = false
  for _, class in ipairs(block.classes or {}) do
    if class:lower() == "tikz" then
      is_tikz = true
      break
    end
  end
  if not is_tikz then return nil end

  local kept = {}
  for line in (block.text .. "\n"):gmatch("(.-)\n") do
    local stripped = trim(line)
    -- Obsidian TikZ plugins commonly expect a complete standalone document.
    -- Beamer already loads TikZ, so document-level wrapper commands must not
    -- be emitted inside a frame.
    if not stripped:match("^\\documentclass") and
       not stripped:match("^\\usepackage%s*[%[{]") and
       stripped ~= "\\begin{document}" and
       stripped ~= "\\end{document}" then
      table.insert(kept, line)
    end
  end

  local tikz = trim(table.concat(kept, "\n"))
  if tikz == "" then return {} end
  return pandoc.RawBlock("latex",
    "\\begin{center}\n" .. tikz .. "\n\\end{center}")
end

function Pandoc(document)
  configure(document.meta)
  configure_title_image(document)
  configure_title_superscripts(document)
  configure_title_date(document)

  document = document:walk({ CodeBlock = compile_tikz_block })

  document = normalize_pdflatex_unicode(document)

  document = document:walk({
    Para = function(block)
      block.content = replace_embeds(block.content)
      return block
    end,
    Plain = function(block)
      block.content = replace_embeds(block.content)
      return block
    end
  })

  document = document:walk({
    Image = function(image)
      local is_wikilink = false
      local kept_classes = {}
      for _, class in ipairs(image.classes) do
        if class == "wikilink" then
          is_wikilink = true
        elseif class == "same-slide" or class == "inline-slide" then
          -- Build-only layout marker; do not pass it to the output writer.
        else
          table.insert(kept_classes, class)
        end
      end

      if is_media_path(image.src) then
        return build_media(image, is_wikilink)
      end

      if is_wikilink and is_image_path(image.src) then
        local option = trim(pandoc.utils.stringify(image.caption))
        if option == image.src or option == basename(image.src) then option = nil end

        local attributes, alt = parse_size(option)
        for key, value in pairs(attributes) do image.attributes[key] = value end
        image.caption = alt == "" and {} or { pandoc.Str(alt) }
        image.classes = kept_classes
        table.insert(image.classes, "obsidian-embed")
      end

      local standard_alt = trim(pandoc.utils.stringify(image.caption))
      if not is_wikilink then
        local control_attributes, control_caption, placement =
          parse_standard_alt(standard_alt)
        if control_attributes then
          for key, value in pairs(control_attributes) do
            if not image.attributes[key] then image.attributes[key] = value end
          end
          image.caption = control_caption == "" and {} or {
            pandoc.Str(control_caption)
          }
          table.insert(image.classes, "slide-control-alt")
          if placement and placement ~= "new" then
            table.insert(image.classes, "slide-pos-" .. placement)
          end
        end
      end

      image.src = resolve_image(image.src)
      if not image.attributes.width and not image.attributes.height then
        image.attributes.width = "92%"
      end
      if not image.attributes.height then image.attributes.height = "68%" end
      table.insert(image.classes, "resolved-image")
      return image
    end
  })

  -- Pandoc 3 creates a Figure before filters run and copies a wiki alias such
  -- as "full" into the Figure caption. Preserve only a caption that was
  -- explicitly parsed from the Markdown image.
  document = document:walk({
    Figure = function(figure)
      local contains_obsidian_embed = false
      local explicit_obsidian_caption = nil
      local contains_slide_control = false
      local explicit_control_caption = nil
      local contains_media = false
      local explicit_media_caption = nil
      local generated_filename_caption = false
      local caption_text = trim(pandoc.utils.stringify(figure.caption)):gsub("%s+", "")
      for _, block in ipairs(figure.content) do
        if block.t == "Para" or block.t == "Plain" then
          for _, inline in ipairs(block.content) do
            if inline.t == "Span" then
              for _, class in ipairs(inline.classes) do
                if class == "obsbeam-media" then
                  contains_media = true
                  local explicit = trim(inline.attributes["data-caption"] or "")
                  if explicit ~= "" then explicit_media_caption = explicit end
                end
              end
            elseif inline.t == "Image" then
              for _, class in ipairs(inline.classes) do
                if class == "obsidian-embed" then
                  contains_obsidian_embed = true
                  local explicit = trim(pandoc.utils.stringify(inline.caption))
                  if explicit ~= "" then
                    explicit_obsidian_caption = inline.caption
                  end
                elseif class == "slide-control-alt" then
                  contains_slide_control = true
                  local explicit = trim(pandoc.utils.stringify(inline.caption))
                  if explicit ~= "" then
                    explicit_control_caption = inline.caption
                  end
                end
              end

              -- Standard Obsidian Markdown often repeats the filename as the
              -- image alt text: ![diagram.png](diagram.png). Pandoc promotes
              -- that to a visible Beamer caption such as "Figurediagram.png".
              -- Remove only that generated caption; descriptive captions stay.
              local filename = basename(inline.src):gsub("%s+", "")
              local alt = trim(pandoc.utils.stringify(inline.caption)):gsub("%s+", "")
              if caption_text == filename or
                 caption_text == "Figure" .. filename or
                 caption_text:match("^%d+$") or
                 caption_text:match("^Figure%d+$") or
                 (alt ~= "" and
                   (caption_text == alt or caption_text == "Figure" .. alt) and
                   alt:lower():match("%.([%a%d]+)$")) then
                generated_filename_caption = true
              end
            end
          end
        end
      end

      if contains_media then
        if explicit_media_caption then
          figure.caption = pandoc.Caption({
            pandoc.Plain({ pandoc.Str(explicit_media_caption) })
          })
        else
          figure.caption = pandoc.Caption{}
        end
      elseif generated_filename_caption then
        figure.caption = pandoc.Caption{}
      elseif contains_slide_control then
        if explicit_control_caption then
          figure.caption = pandoc.Caption({
            pandoc.Plain(explicit_control_caption)
          })
        else
          figure.caption = pandoc.Caption{}
        end
      elseif contains_obsidian_embed then
        if explicit_obsidian_caption then
          figure.caption = pandoc.Caption({
            pandoc.Plain(explicit_obsidian_caption)
          })
        else
          figure.caption = pandoc.Caption{}
        end
      end
      return figure
    end
  })

  return document
end
