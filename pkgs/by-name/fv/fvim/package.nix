{ lib
, stdenv
, fetchFromGitHub
, makeWrapper
, cargo
, curl
, fd
, fzf
, git
, gnumake
, gnused
, gnutar
, gzip
, lua-language-server
, neovim
, nodejs
, nodePackages
, ripgrep
, tree-sitter
, unzip
, nvimAlias ? false
, viAlias ? false
, vimAlias ? false
, globalConfig ? ""
}:

stdenv.mkDerivation (finalAttrs: {
  inherit nvimAlias viAlias vimAlias globalConfig;

  pname = "fhsneovim";
  version = "1.4.0";

  src = fetchFromGitHub {
    owner = "ooo-mmm";
    repo = "fvim";
  };

  nativeBuildInputs = [
    gnused
    makeWrapper
  ];

  runtimeDeps = [
    stdenv.cc
    cargo
    curl
    fd
    fzf
    git
    gnumake
    gnutar
    gzip
    lua-language-server
    neovim
    nodejs
    nodePackages.neovim
    ripgrep
    tree-sitter
    unzip
  ];

  buildPhase = ''
    runHook preBuild

    mkdir -p share/fvim
    cp init.lua lazy-lock.json share/fvim
    cp -r lua share/fvim

    mkdir bin
    cp fvim.template bin/fvim
    chmod +x bin/fvim

    # LunarVim automatically copies config.example.lua, but we need to make it writable.
    sed -i "2 i\\
            if [ ! -f \$HOME/.config/fvim/lazy-lock.json ]; then \\
              cp $out/share/fvim/config.example.lua \$HOME/.config/fvim/config.lua \\
              chmod +w \$HOME/.config/fvim/config.lua \\
            fi
    " bin/fvim

    substituteInPlace bin/fvim \
      --replace NVIM_APPNAME_VAR fvim \
      --replace RUNTIME_DIR_VAR \$HOME/.local/share/fvim \
      --replace CONFIG_DIR_VAR \$HOME/.config/fvim \
      --replace CACHE_DIR_VAR \$HOME/.cache/fvim \
      --replace BASE_DIR_VAR $out/share/fvim \
      --replace nvim ${neovim}/bin/nvim

    # Allow language servers to be overridden by appending instead of prepending
    # the mason.nvim path.
    echo "fvim.builtin.mason.PATH = \"append\"" > share/fvim/global.lua
    echo ${ lib.strings.escapeShellArg finalAttrs.globalConfig } >> share/fvim/global.lua
    sed -i "s/add_to_path()/add_to_path(true)/" share/fvim/lua/fvim/core/mason.lua
    sed -i "/Log:set_level/idofile(\"$out/share/fvim/global.lua\")" share/fvim/lua/fvim/config/init.lua

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r bin share $out

    for iconDir in utils/desktop/*/; do
      install -Dm444 $iconDir/lvim.svg -t $out/share/icons/hicolor/$(basename $iconDir)/apps
    done

    install -Dm444 utils/desktop/fvim.desktop -t $out/share/applications

    wrapProgram $out/bin/fvim --prefix PATH : ${ lib.makeBinPath finalAttrs.runtimeDeps } \
      --prefix LD_LIBRARY_PATH : ${stdenv.cc.cc.lib} \
      --prefix CC : ${stdenv.cc.targetPrefix}cc
  '' + lib.optionalString finalAttrs.nvimAlias ''
    ln -s $out/bin/fvim $out/bin/nvim
  '' + lib.optionalString finalAttrs.viAlias ''
    ln -s $out/bin/fvim $out/bin/vi
  '' + lib.optionalString finalAttrs.vimAlias ''
    ln -s $out/bin/fvim $out/bin/vim
  '' + ''
    runHook postInstall
  '';

  meta = with lib; {
    description = "IDE layer for Neovim";
    sourceProvenance = with sourceTypes; [ fromSource ];
    license = licenses.gpl3Only;
    platforms = platforms.unix;
    mainProgram = "fvim";
  };
})
