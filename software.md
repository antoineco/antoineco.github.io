---
layout: software
title: Software
categories:
  - name: Shell
    entries:
    - name: jq
      url: https://jqlang.github.io/jq/
      desc: The programming language for data mangling.
    - name: Zim
      url: https://zimfw.sh/
      desc: Make Zsh instantly great.
    - name: fzf
      url: https://github.com/junegunn/fzf
      desc: The one filter that takes junk in and spits magic out.
    - name: tldr
      url: https://tldr.sh/
      desc: man pages for the impatient.
    - name: difftastic
      url: https://difftastic.wilfred.me.uk/
      desc: Like diff, but structural.
    - name: VisiData
      url: https://www.visidata.org/
      desc: Microsoft&#174; Excel for anything, in the terminal.
  - name: Development
    entries:
    - name: Neovim
      url: https://neovim.io/
      desc: Vim(proved)-improved. The greatest text editor, this time by the people for the people.
    - name: Helix
      url: https://helix-editor.com/
      desc: Modal text editing re-imagined from the ground up.
  - name: Kubernetes
    entries:
    - name: ko
      url: https://ko.build
      desc: Single-command, zero-dependency deployment of Go programs.
    - name: ketall
      url: https://github.com/corneliusweig/ketall
      desc: Get all. Really all.
    - name: lineage
      url: https://github.com/tohjustin/kube-lineage
      desc: Who said one had to lose their mind working with dependent objects?
  - name: General
    entries:
    - name: WezTerm
      url: https://wezfurlong.org/wezterm/
      desc: If the name "suckless terminal" wasn't already taken, this one would've deserved it.
    - name: WSL2
      url: https://learn.microsoft.com/windows/wsl/
      desc: Linux on the desktop. Turns out "Microsoft &#10084; Linux" wasn't just a marketing stunt.
    - name: Lima
      url: https://lima-vm.io/
      desc: Disposable Linux virtual machines at my fingertips.
    - name: MonoLisa
      url: https://www.monolisa.dev/
      desc: My eyes are too precious for staring at some clunky-looking font all day.
  - name: Macintosh
    entries:
    - name: Mac Mouse Fix
      url: https://macmousefix.com
      desc: Because macOS comes without mouse support.
    - name: BetterDisplay
      url: https://betterdisplay.pro/
      desc: Because macOS comes without support for external displays.
---

Because good software deserves to be celebrated[^1], here is a selection of
computer programs of all sorts that I use—some by devotion over necessity—and
consider to be a true labor of love.

{% for category in page.categories %}
<h2>{{ category.name }}</h2>
<table>
  <thead>
    <tr>
      <th>Name</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    {% for entry in category.entries -%}
    <tr>
      <td><a href="{{ entry.url }}">{{ entry.name }}</a></td>
      <td>{{ entry.desc | smartify }}</td>
    </tr>
    {% endfor -%}
  </tbody>
</table>
{% endfor %}

[^1]: The form and tone of this page was inspired by Reyan Chaudhry's [personal homepage][1].

[1]: https://reyan.co/software
