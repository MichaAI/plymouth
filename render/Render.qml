import QtQuick
import QtQuick.Window

// Рисует всё, что нужно теме Plymouth, и выходит:
//   frame-<i>.png — полный оборот модели, зациклен без шва: последний кадр
//                   переходит в первый и по повороту, и по анимации;
//   field.png     — поле пароля, как на локе;
//   dot-<i>.png   — точки пароля, градиент от первой к последней.
// Параметры — JSON в последнем аргументе (см. nix/theme.nix)
Window {
    id: win

    readonly property var p: JSON.parse(Qt.application.arguments[Qt.application.arguments.length - 1])
    readonly property int frames: p.frames

    width: Math.max(p.size, p.fieldWidth)
    height: p.size + p.fieldHeight
    visible: true
    color: "transparent"

    Avatar {
        id: avatar
        width: win.p.size
        height: win.p.size
        scene: win.p.scene
        animation: win.p.animation
        modelSize: win.p.modelSize
        pixel: win.p.pixel
        colors: win.p.palette
    }

    // Поле пароля: с ободком на прозрачном фоне
    Rectangle {
        id: field
        y: win.p.size
        width: win.p.fieldWidth
        height: win.p.fieldHeight
        radius: height / 2
        color: win.p.fieldColor
        border.width: 2
        border.color: win.p.fieldBorder
    }

    Rectangle {
        id: dot
        x: field.width + 10
        y: win.p.size
        width: 9; height: 9
        radius: 4.5
    }

    // Смешивание в OkLab (Björn Ottosson): без провала в серую середину и
    // с ровной на глаз яркостью
    function mix(a, b, t) {
        const p = oklab(Qt.color(a)), q = oklab(Qt.color(b))
        const m = i => p[i] + (q[i] - p[i]) * t
        return fromOklab(m(0), m(1), m(2))
    }

    function oklab(c) {
        const r = lin(c.r), g = lin(c.g), b = lin(c.b)
        const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return [0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s]
    }

    function fromOklab(L, A, B) {
        const l = Math.pow(L + 0.3963377774 * A + 0.2158037573 * B, 3)
        const m = Math.pow(L - 0.1055613458 * A - 0.0638541728 * B, 3)
        const s = Math.pow(L - 0.0894841775 * A - 1.2914855480 * B, 3)
        return Qt.rgba(srgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
                       srgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
                       srgb(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s), 1)
    }

    function lin(x) {
        return x <= 0.04045 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4)
    }

    function srgb(x) {
        x = Math.max(0, Math.min(1, x))
        return x <= 0.0031308 ? 12.92 * x : 1.055 * Math.pow(x, 1 / 2.4) - 0.055
    }

    function save(item, name, next) {
        item.grabToImage(r => {
            if (!r.saveToFile(p.out + "/" + name)) {
                console.error("render: не записался", name)
                Qt.exit(1)
            }
            next()
        })
    }

    // Целое число повторов анимации на один оборот — иначе на стыке шов.
    // Скорость при этом чуть подгоняется под длину оборота
    readonly property int loops: avatar.duration > 0
        ? Math.max(1, Math.round(p.seconds * 1000 * p.speed / avatar.duration))
        : 0

    function frame(i) {
        if (i === frames) {
            save(field, "field.png", () => dots(0))
            return
        }
        avatar.angle = 360 * i / frames
        avatar.time = avatar.duration * loops * i / frames
        save(avatar, "frame-" + i + ".png", () => frame(i + 1))
    }

    function dots(i) {
        if (i === p.dotColors) {
            console.log("render:", frames, "кадров, анимация",
                        p.animation || "нет", loops ? "× " + loops + " за оборот" : "")
            Qt.quit()
            return
        }
        dot.color = mix(p.gradStart, p.gradEnd, i / (p.dotColors - 1))
        save(dot, "dot-" + i + ".png", () => dots(i + 1))
    }

    // Ждём, пока сцена загрузится и меши посчитают габариты
    Timer {
        interval: 100
        repeat: true
        running: true
        property int waited: 0
        onTriggered: {
            if (avatar.ready) {
                stop()
                win.frame(0)
            } else if (++waited > 300) {
                console.error("render: сцена так и не загрузилась")
                Qt.exit(1)
            }
        }
    }
}
