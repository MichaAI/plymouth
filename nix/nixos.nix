# Модуль NixOS: michaai.plymouth
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.michaai.plymouth;
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.michaai.plymouth = {
    enable = mkEnableOption "Plymouth с темой bento";

    model = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = lib.literalExpression "./Fox.glb";
      description = "3D-модель (.glb/.gltf/.fbx/.obj); null — лиса Khronos.";
    };

    animation = mkOption {
      type = types.str;
      default = "Run";
      description = ''
        Анимация из модели; "" — модель стоит и просто крутится. Если такой
        нет, сборка упадёт и перечислит, какие есть.
      '';
    };

    speed = mkOption {
      type = types.number;
      default = 1;
      description = "Скорость анимации: подгоняется, чтобы за оборот она прошла целое число раз.";
    };

    seconds = mkOption {
      type = types.number;
      default = 4;
      description = "Один полный оборот, секунды.";
    };

    fps = mkOption {
      type = types.ints.positive;
      default = 30;
      description = "Кадров в секунду. Кадры лежат в initrd: больше кадров — толще initrd.";
    };

    size = mkOption {
      type = types.ints.positive;
      default = 320;
      description = "Сторона кадра в пикселях экрана.";
    };

    modelSize = mkOption {
      type = types.number;
      default = 280;
      description = "Размер модели в кадре, px: она вписывается в него по самой длинной стороне.";
    };

    pixel = mkOption {
      type = types.number;
      default = 4;
      description = "Клетка дизеринга, px.";
    };

    colors = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      example = lib.literalExpression ''
        { background = "#1e1e2e"; palette = [ "#313244" "#89b4fa" "#b4befe" "#cdd6f4" ]; }
      '';
      description = ''
        Цвета поверх Catppuccin Mocha: background, palette (4 цвета модели от
        тёмного к светлому), field, fieldBorder, gradStart, gradEnd, text.
      '';
    };

    package = mkOption {
      type = types.package;
      readOnly = true;
      description = "Собранная тема.";
    };
  };

  config = lib.mkIf cfg.enable {
    michaai.plymouth.package = pkgs.callPackage ./theme.nix {
      inherit (cfg)
        model
        animation
        speed
        seconds
        fps
        size
        modelSize
        pixel
        colors
        ;
    };

    boot.plymouth = {
      enable = true;
      theme = "bento";
      themePackages = [ cfg.package ];
    };
  };
}
