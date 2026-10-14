import QtQuick
import QtQuick3D

// 3D-модель с дизерингом — как аватарка на локе и экране входа, только
// без своих часов: поворот и момент анимации задаёт рендер, кадр за кадром
Item {
    id: root

    property url scene              // .qml, который сделал balsam
    property string animation: ""   // имя анимации, "" — стоять
    property real angle: 0          // поворот вокруг вертикали, градусы
    property real time: 0           // момент анимации, мс от её начала
    property real modelSize: 190    // в него вписывается модель
    property real pixel: 4          // клетка дизеринга, px
    property var colors: ["#45475a", "#cba6f7", "#f5c2e7", "#f5e0dc"]

    property var timeline: null
    // Длина выбранной анимации, мс; 0 — анимации нет
    readonly property real duration: timeline
        ? (timeline.endFrame - timeline.startFrame) / (timeline.framesPerSecond ?? 1000) * 1000
        : 0

    property vector3d lo: Qt.vector3d(0, 0, 0)
    property vector3d hi: Qt.vector3d(0, 0, 0)
    readonly property real extent: Math.max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, 0)
    readonly property real k: modelSize / Math.max(extent, 0.0001)
    readonly property bool ready: sceneLoader.status === Loader3D.Ready && extent > 0.0001

    property var models: []

    onTimeChanged: apply()
    function apply() {
        if (timeline)
            timeline.currentFrame = timeline.startFrame
                + (time % Math.max(duration, 1)) / 1000 * (timeline.framesPerSecond ?? 1000)
    }

    function walk(obj, out) {
        if (!obj)
            return
        if (obj.bounds !== undefined && obj.skeleton !== undefined)
            out.push(obj)
        for (const c of obj.children ?? [])
            walk(c, out)
    }

    function measure() {
        const corners = []
        for (const m of models) {
            const a = m.bounds.minimum, b = m.bounds.maximum
            for (const x of [a.x, b.x]) for (const y of [a.y, b.y]) for (const z of [a.z, b.z])
                corners.push(m.mapPositionToNode(sceneLoader.item, Qt.vector3d(x, y, z)))
        }
        if (corners.length === 0)
            return
        lo = Qt.vector3d(Math.min(...corners.map(c => c.x)), Math.min(...corners.map(c => c.y)), Math.min(...corners.map(c => c.z)))
        hi = Qt.vector3d(Math.max(...corners.map(c => c.x)), Math.max(...corners.map(c => c.y)), Math.max(...corners.map(c => c.z)))
    }

    function pickAnimation() {
        const all = []
        for (const o of sceneLoader.item?.resources ?? [])
            if (o.currentFrame !== undefined && o.keyframeGroups !== undefined)
                all.push(o)
        let found = null
        for (const t of all) {
            t.enabled = t.objectName === animation
            if (t.enabled)
                found = t
        }
        if (animation !== "" && !found) {
            console.error("render: в модели нет анимации", animation,
                          "— есть:", all.map(t => t.objectName).join(", ") || "никаких")
            Qt.exit(1)
        }
        timeline = found
        apply()
    }

    View3D {
        anchors.fill: parent

        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Transparent
            antialiasingMode: SceneEnvironment.NoAA
        }

        PerspectiveCamera {
            position: Qt.vector3d(0, 0, 300)
            clipNear: 1
            clipFar: 3000
        }
        DirectionalLight {
            eulerRotation: Qt.vector3d(-30, -35, 0)
            brightness: 1.0
        }
        // Контровой свет сзади — чтобы силуэт не сливался с тенью
        DirectionalLight {
            eulerRotation: Qt.vector3d(15, 150, 0)
            brightness: 0.35
        }

        Node {
            eulerRotation.y: root.angle

            // Модель вписываем в один размер и ставим центром в начало
            // координат: тогда она крутится вокруг себя, а не по орбите
            Node {
                scale: Qt.vector3d(root.k, root.k, root.k)
                position: Qt.vector3d(-(root.lo.x + root.hi.x) / 2 * root.k,
                                      -(root.lo.y + root.hi.y) / 2 * root.k,
                                      -(root.lo.z + root.hi.z) / 2 * root.k)

                Loader3D {
                    id: sceneLoader
                    source: root.scene
                    onLoaded: {
                        const out = []
                        root.walk(item, out)
                        root.models = out
                        for (const m of out)
                            m.boundsChanged.connect(root.measure)
                        root.measure()
                        root.pickAnimation()
                    }
                    onStatusChanged: {
                        if (status === Loader3D.Error) {
                            console.error("render: сцена", source, "не открылась")
                            Qt.exit(1)
                        }
                    }
                }
            }
        }

        layer.enabled: true
        layer.effect: ShaderEffect {
            fragmentShader: "dither.frag.qsb"
            property vector2d size: Qt.vector2d(width, height)
            property real pixel: root.pixel
            property color c0: root.colors[0]
            property color c1: root.colors[1]
            property color c2: root.colors[2]
            property color c3: root.colors[3]
        }
    }
}
