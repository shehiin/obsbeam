# obsbeam

turn obsidian markdown files into beamer pdf slides.

## requirements

install quarto from `https://quarto.org/docs/get-started/`.

```bash
sudo apt update
sudo apt install bash-completion texlive-luatex texlive-latex-extra texlive-fonts-extra
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

an image beside the note:

```markdown
![[diagram.png]]
```

images in common vault folders:

```markdown
![[attachments/diagram.png]]
![[assets/diagram.png]]
![[images/diagram.png]]
```

set the size with a percentage:

```markdown
![[diagram.png|40%]]
```

choose where the image sits on the current slide:

```markdown
![[diagram.png|left|35%]]
![[diagram.png|right|35%]]
![[diagram.png|up|50%]]
![[diagram.png|down|50%]]
```

without a position, the image stays on the current slide at the right. use `new` for another slide:

```markdown
![[diagram.png|new|75%]]
```

add a caption:

```markdown
![[diagram.png|caption=system architecture]]
![[diagram.png|left|35%|caption=system architecture]]
```

this also works:

```markdown
![left 35%](attachments/diagram.png)
![left 35%, system architecture](attachments/diagram.png)
```

numeric Obsidian widths are treated as sizes, not captions:

```markdown
![[diagram.png|525]]
```

## video

embed local video or audio with the same syntax:

```markdown
![[demo.mp4]]
![[demo.mp4|new|caption=experiment run]]
```

the media is stored inside the PDF. inline playback requires Firefox 154 or
newer; other PDF viewers show the play poster when RichMedia is unsupported.

## output

`slide lecture.md` creates `_slides/lecture.pdf` inside the vault.
