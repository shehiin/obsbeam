# obsbeam

turn obsidian markdown files into beamer pdf slides.

## requirements

install quarto from `https://quarto.org/docs/get-started/`.

```bash
sudo apt update
sudo apt install bash-completion texlive-latex-extra texlive-fonts-extra
```

## install

```bash
git clone https://github.com/shehiin/obsbeam.git
cd obsbeam
./install /path/to/obsidian-vault
```

## usage

```bash
slide note.md
slide note.md custom-name.pdf
```

use `slide obs/` and tab to complete note names from the vault.

## title page

the title defaults to the markdown filename. optional fields can be added at the start of the note:

```markdown
title: presentation title
text: research presentation
name: author
```

`text` adds secondary text.

## images

use:

```markdown
![position size](file.jpg)
```

examples:

```markdown
![right 40%](diagram.jpg)
![left 35%, system architecture](diagram.jpg)
![new 100%, full-slide diagram](diagram.jpg)
```

the caption is optional and follows a comma. `new` places the image on a new
slide. other positions keep it on the current slide.

positions: `left`, `right`, `up`, `down`, `topleft`, `topright`, `bottomleft`,
`bottomright`, `grid`, `new`.

use a relative path when the image is in an assets folder:

```markdown
![right 40%](assets/diagram.jpg)
```

## video

embed local video or audio with the same syntax:

```markdown
![right 40%](demo.mp4)
![new 80%, experiment run](demo.mp4)
```

the media is stored inside the PDF. inline playback requires Firefox 154 or
newer; other PDF viewers show the play poster when RichMedia is unsupported.

## output

`slide lecture.md` creates `slides/lecture.pdf` inside the vault.
