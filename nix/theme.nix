# Тема Plymouth: balsam делает из модели сцену, Qt рисует её полный
# оборот кадрами (под Xvfb, на программном OpenGL из mesa), а скрипт
# Plymouth их крутит
{
  lib,
  stdenvNoCC,
  fetchurl,
  writeText,
  kdePackages,
  mesa,
  xvfb-run,

  # Модель .glb/.gltf/.fbx/.obj; по умолчанию — лиса Khronos
  model ? null,
  # Анимация из модели; "" — модель стоит и просто крутится
  animation ? "Run",
  # Скорость анимации; подгоняется, чтобы за оборот она прошла целое число раз
  speed ? 1,
  # Один оборот, секунды, и кадров в секунду
  seconds ? 4,
  fps ? 30,
  # Сторона кадра и размер модели в нём: 280 из 320 — модель почти во
  # весь кадр (на локе 190 из 340)
  size ? 320,
  modelSize ? 280,
  # Клетка дизеринга, px
  pixel ? 4,
  # Catppuccin Mocha, как на локе: фон, 4 цвета модели от тёмного к
  # светлому, поле пароля, градиент точек и цвет текста
  colors ? { },
}:

let
  inherit (kdePackages)
    qtbase
    qtdeclarative
    qtquick3d
    qtquicktimeline
    ;

  c = {
    background = "#11111b";
    palette = [
      "#45475a"
      "#cba6f7"
      "#f5c2e7"
      "#f5e0dc"
    ];
    field = "#1e1e2e";
    fieldBorder = "#cba6f7";
    gradStart = "#f38ba8";
    gradEnd = "#cba6f7";
    text = "#6c7086";
  }
  // colors;

  fox = fetchurl {
    name = "Fox.glb";
    url = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/edc7c9e67c639d230715049ee31f9a96a6babbbe/Models/Fox/glTF-Binary/Fox.glb";
    hash = "sha256-2XBE5wGCK6xaYmlkWbJ9ezdaraXehXTtQ2Ltu6lHcfc=";
  };
  src' = if model == null then fox else model;
  ext = lib.last (lib.splitString "." (baseNameOf src'));

  dotColors = 16;
  frames = builtins.floor (seconds * fps + 0.5);

  params = writeText "params.json" (
    builtins.toJSON {
      scene = "@SCENE@";
      out = "@OUT@";
      inherit
        animation
        speed
        seconds
        frames
        size
        modelSize
        pixel
        dotColors
        ;
      palette = c.palette;
      fieldWidth = 340;
      fieldHeight = 50;
      fieldColor = c.field;
      fieldBorder = c.fieldBorder;
      inherit (c) gradStart gradEnd;
    }
  );

  # "#rrggbb" → дроби 0…1 для скрипта Plymouth
  channel =
    hex: i:
    let
      d = lib.fromHexString (builtins.substring (1 + 2 * i) 2 hex);
    in
    builtins.toString (d / 255.0);

  qml = [
    qtdeclarative
    qtquick3d
    qtquicktimeline
  ];
in
stdenvNoCC.mkDerivation {
  pname = "plymouth-theme-bento";
  version = "1.0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../render
      ../theme
    ];
  };

  nativeBuildInputs = [
    qtquick3d
    qtdeclarative
    xvfb-run
  ];
  # Приложений тут нет: Qt нужен только чтобы нарисовать кадры
  dontWrapQtApps = true;

  buildPhase = ''
    runHook preBuild

    export HOME=$TMPDIR
    export QT_PLUGIN_PATH=${lib.makeSearchPath qtbase.qtPluginPrefix ([ qtbase ] ++ qml)}
    export QML_IMPORT_PATH=${lib.makeSearchPath qtbase.qtQmlPrefix qml}

    # balsam называет сцену по файлу: avatar.glb → Avatar.qml. Ключевые
    # кадры — прямо в QML: двоичные .qad, сделанные в песочнице, Timeline
    # потом не читает
    cp ${src'} avatar.${ext}
    QT_QPA_PLATFORM=offscreen balsam --manualAnimations --disable-useBinaryKeyframes \
      -o scene avatar.${ext}

    # Программный OpenGL: в песочнице видеокарты нет
    export LIBGL_DRIVERS_PATH=${mesa}/lib/dri
    export __EGL_VENDOR_LIBRARY_FILENAMES=${mesa}/share/glvnd/egl_vendor.d/50_mesa.json
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    export LD_LIBRARY_PATH=${mesa}/lib

    mkdir out
    sed -e "s|@SCENE@|file://$PWD/scene/Avatar.qml|" -e "s|@OUT@|$PWD/out|" ${params} > params.json
    xvfb-run -s "-screen 0 1024x768x24" \
      qml render/Render.qml -- "$(cat params.json)"
    test -f out/dot-${toString (dotColors - 1)}.png

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    dir=$out/share/plymouth/themes/bento
    mkdir -p $dir
    cp out/*.png $dir
    substitute theme/bento.plymouth $dir/bento.plymouth --replace-fail @DIR@ $dir
    substitute theme/bento.script $dir/bento.script \
      --replace-fail @FRAMES@ ${toString frames} \
      --replace-fail @FPS@ ${toString fps} \
      --replace-fail @DOT_COLORS@ ${toString dotColors} \
      --replace-fail @BG_R@ ${channel c.background 0} \
      --replace-fail @BG_G@ ${channel c.background 1} \
      --replace-fail @BG_B@ ${channel c.background 2} \
      --replace-fail @MUTED_R@ ${channel c.text 0} \
      --replace-fail @MUTED_G@ ${channel c.text 1} \
      --replace-fail @MUTED_B@ ${channel c.text 2}

    runHook postInstall
  '';

  meta = {
    description = "Тема Plymouth: модель с дизерингом крутится, пароль — точками";
    platforms = lib.platforms.linux;
  };
}
