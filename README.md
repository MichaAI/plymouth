# Bento — тема Plymouth

3D-модель с крупным дизерингом крутится в центре экрана, как аватарка на
локе из quickshell и на экране входа SDDM. Когда спрашивают пароль (LUKS),
под ней появляется поле с точками-градиентом, как на локе.

Кадры рисуются при сборке: balsam делает из модели QML-сцену, Qt Quick 3D
рендерит полный оборот под Xvfb на программном OpenGL из mesa, а скрипт
Plymouth крутит готовые PNG. Оборот зациклен без шва: за него анимация
проходит целое число раз (скорость чуть подгоняется).

## NixOS

```nix
# flake.nix
inputs.plymouth-bento = {
  url = "github:MichaAI/plymouth";
  inputs.nixpkgs.follows = "nixpkgs";
};

# configuration.nix
imports = [ inputs.plymouth-bento.nixosModules.default ];

michaai.plymouth = {
  enable = true;
  animation = "Run";       # Survey, Walk, Run или "" — просто крутиться
  # model = ./Fox.glb;     # своя модель; по умолчанию лиса Khronos
};

# Plymouth раньше и плавнее с systemd в initrd
boot.initrd.systemd.enable = true;
```

Ещё есть `speed`, `seconds` (один оборот), `fps`, `size` (сторона кадра),
`modelSize`, `pixel` (клетка дизеринга) и `colors` (Catppuccin Mocha по
умолчанию). Кадры лежат в initrd: 120 кадров по 320 px — около 600 КБ.
Если анимации с таким именем нет, сборка упадёт и перечислит, какие есть.

Без модуля — `packages.default.override { animation = "Walk"; … }`,
тема ляжет в `share/plymouth/themes/bento`.

## Лиса

Модель по умолчанию — [Fox](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/Fox)
из glTF Sample Assets:

- модель — PixelMannen, [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/);
- риггинг и анимации — tomkranis, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/);
- перевод в glTF — @AsoboStudio и @scurest, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

В репо её нет: сборка скачивает её с закреплённого коммита.
