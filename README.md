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
name: author one^1, author two^2
affiliation: ^1university one, ^2university two
date: jul 2025
image: ![[logo.png]]
```

`text` adds secondary text. superscript numbers connect authors to affiliations. the date defaults to the export month and year.

## images

use one syntax for image layout:

```markdown
![right 40%](diagram.png)
```

the form is `![position size, optional caption](file)`:

```markdown
![left 35%](diagram.png)
![right 40%, system architecture](diagram.png)
![new 100%, full-slide diagram](diagram.png)
```

available positions are `left`, `right`, `up`, `down`, `topleft`,
`topright`, `bottomleft`, `bottomright`, `grid`, and `new`.

paths may be relative to the note or use a common vault folder:

```markdown
![right 40%](attachments/diagram.png)
![right 40%](assets/diagram.png)
![right 40%](images/diagram.png)
```

pasted Obsidian embeds still render, but they are not a second layout syntax:

```markdown
![[diagram.png]]
![[diagram.png|525]]
```

Obsidian's numeric width is treated as resize metadata, not a caption.

stack two images on one side:

```markdown
![topright 44%, upper image](diagram-one.png)
![bottomright 44%, lower image](diagram-two.png)
```

place three images in a row:

```markdown
![grid 31%, first](one.png)
![grid 31%, second](two.png)
![grid 31%, third](three.png)
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

`slide lecture.md` creates `_slides/lecture.pdf` inside the vault.
