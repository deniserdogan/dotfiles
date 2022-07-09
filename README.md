# My Minimal Neovim Setup

I use Neovim's builtin LSP setting up language servers and features such as:

- Go to definition
- (auto)completion
- Code Actions (automatic formatting when saved, organize imports, ...)
- Fixing autofixables
- Show method signatures
- Show/go to references/go to implementation
- Snippets

[packer.nvim](https://github.com/wbthomason/packer.nvim) for plugin/package management

For listing features above I use [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

For file explorer [NvimTree](https://github.com/kyazdani42/nvim-tree.lua)

Colorscheme is [nordfox.nvim](https://github.com/EdenEast/nightfox.nvim) with some customization

To install language sarvers [LspInstall](https://github.com/kabouzeid/nvim-lspinstall) 

Using specific servers for formatters, linters, errors, and code actions [null-ls.nvim](https://github.com/jose-elias-alvarez/null-ls.nvim)
**and more..**

> ⚠️ Check keymaps.lua and dannzi.lua to see all shortcuts

### Languages with settings and ready to use:

- Javascript/Typescript (React)

- Python

- Go

- Lua

# Setup

Before you install anything don't forget to backup your old config!

```console
mv ~/.config/nvim ~/.config/nvimbackup
```

Clone repo to `~/.config/nvim/` folder

```console
git clone https://github.com/deniserdogan/dotfiles ~/.config/nvim
nvim +PackerSync
```


# Some Features & Screenshots


### Autocompletion, snippets and show docs 

> To view docs in normal mode bring cursor to called function and hit "K"

<img width="600" alt="Screenshot 2022-07-08 at 19 37 38" src="https://user-images.githubusercontent.com/40524858/178035696-57fd915f-d1f8-426a-85ea-641a80002ed9.png">


### Linting errors and warnings 

<img width="600" alt="Screenshot 2022-07-08 at 19 39 04" src="https://user-images.githubusercontent.com/40524858/178037287-1bd6284d-d2e7-47dc-8dae-a9b3762cde03.png">

### List files, references and more with telescope.nvim

<img width="600" alt="Screenshot 2022-07-08 at 19 34 54" src="https://user-images.githubusercontent.com/40524858/178037615-3fcfb8e3-a6f4-4573-bcc3-a102206e4589.png">
