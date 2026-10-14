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

    function mix(a, b, t) {
        a = Qt.color(a); b = Qt.color(b)
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
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
