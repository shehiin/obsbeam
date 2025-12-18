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

## output

`slide lecture.md` creates `_slides/lecture.pdf` inside the vault.
