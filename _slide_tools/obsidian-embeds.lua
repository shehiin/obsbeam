-- Convert Obsidian image embeds to real Pandoc images and resolve their paths.
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

local function resolve_image(path)
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
    "Obsidian image not found: " .. path ..
    "\nSearched:\n  " .. table.concat(candidates, "\n  ") ..
    "\nMove the file into attachments/ or use an explicit vault-relative path."
  )
end

local function is_size_hint(value)
  local lower = value:lower()
  return lower == "full" or
         lower == "fit" or
         lower:match("^%d+$") ~= nil or
         lower:match("^%d+%.?%d*%%$") ~= nil or
         lower:match("^%d+%.?%d*px$") ~= nil or
         lower:match("^%d+%.?%d*cm$") ~= nil or
         lower:match("^%d+%.?%d*mm$") ~= nil or
         lower:match("^%d+%.?%d*in$") ~= nil or
         lower:match("^%d+%.?%d*em$") ~= nil or
         lower:match("^%d+x%d+$") ~= nil or
         lower:match("^width%s*=") ~= nil or
         lower:match("^w%s*=") ~= nil or
         lower:match("^height%s*=") ~= nil or
         lower:match("^h%s*=") ~= nil
end

local function parse_size(option)
  local attributes = {}
  local alt = ""
  local size_option = nil
  local caption_option = nil

  -- Layout hints are consumed by prepare-obsidian.awk. Size and an explicitly
  -- requested caption may coexist, for example:
  -- `|60%|same|caption=Training overview`.
  if option and option ~= "" then
    for token in option:gmatch("[^|]+") do
      local cleaned = trim(token)
      local layout_hint = cleaned:lower()
      if layout_hint ~= "same" and layout_hint ~= "inline" and
         layout_hint ~= "left" and layout_hint ~= "right" and
         layout_hint ~= "up" and layout_hint ~= "down" and
         layout_hint ~= "new" and layout_hint ~= "figure" and
         layout_hint ~= "separate" then
        if layout_hint:match("^caption%s*=") then
          caption_option = trim(cleaned:match("=%s*(.+)$") or "")
        elseif is_size_hint(cleaned) and not size_option then
          size_option = cleaned
        elseif not caption_option then
          -- A plain non-size wiki alias is an explicit caption.
          caption_option = cleaned
        end
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

  local specification, caption = option:match("^(.-)%s*|%s*(.+)$")
  if not specification then
    specification, caption = option:match("^(.-)%s*,%s*(.+)$")
  end
  if not specification then specification = option end
  specification = trim(specification)
  caption = caption and trim(caption) or ""

  -- A trailing Obsidian pipe value such as `|410` is legacy sizing metadata,
  -- not a requested caption. Captions remain opt-in descriptive text.
  if caption ~= "" and is_size_hint(caption) then caption = "" end

  local placement = nil
  local keyword, remainder = specification:match("^([%a]+)%s*[:=]?%s*(.-)$")
  if keyword then
    keyword = keyword:lower()
    if keyword == "same" or keyword == "inline" then
      placement = "right"
      specification = trim(remainder)
    elseif keyword == "left" or keyword == "right" or
           keyword == "up" or keyword == "down" then
      placement = keyword
      specification = trim(remainder)
    elseif keyword == "new" or keyword == "figure" or keyword == "separate" then
      placement = "new"
      specification = trim(remainder)
    end
  end

  if not placement and not is_size_hint(specification) then return nil end
  if specification ~= "" and not is_size_hint(specification) then return nil end

  local attributes = parse_size(specification ~= "" and specification or nil)
  return attributes, caption, placement
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

function Pandoc(document)
  configure(document.meta)

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
      local generated_filename_caption = false
      local caption_text = trim(pandoc.utils.stringify(figure.caption)):gsub("%s+", "")
      for _, block in ipairs(figure.content) do
        if block.t == "Para" or block.t == "Plain" then
          for _, inline in ipairs(block.content) do
            if inline.t == "Image" then
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

      if generated_filename_caption then
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
