import Foundation

/// Dandelion foliage, as drawn. Each entry is (x, y, cell); positions are in
/// scene cells, so they sit to the right of the tortoise at mouth height.
enum TortoisePlant: Equatable {
    /// Nothing there.
    case none
    /// The dandelion he gets at the end of a focus session: flower head up in the
    /// headroom, stem down the right, leafy rosette at biting height.
    case dandelion
    /// The same plant with everything above the rosette chewed off.
    case rosette

    var cells: [(x: Int, y: Int, cell: TortoiseCell)] {
        switch self {
        case .none:
            return []
        case .dandelion:
            // The flower head sits up in the headroom on a stalk that hangs down
            // the right-hand side to the leaves, and the leaves are drawn against
            // the mouth so he is biting the plant rather than the air beside it.
            return TortoisePlant.flower + TortoisePlant.stalk + TortoisePlant.rosetteLeaves
        case .rosette:
            // Flower and stalk eaten away: what is left is the leaves at his mouth.
            return TortoisePlant.rosetteLeaves
        }
    }

    /// The stalk, from the flower down to the leaves. Drawn as a single column so
    /// it reads as one plant with the head.
    static let stalk: [(x: Int, y: Int, cell: TortoiseCell)] = stride(from: 4, through: 9, by: 1)
        .map { (19, $0, .stem) }

    /// The flower head: a rounded tuft of petals, with the stalk leaving its base.
    static let flower: [(x: Int, y: Int, cell: TortoiseCell)] = [
        (19, 0, .petal),
        (18, 1, .petal), (19, 1, .petal), (20, 1, .petal),
        (17, 2, .petal), (18, 2, .petal), (19, 2, .petal), (20, 2, .petal), (21, 2, .petal),
        (18, 3, .petal), (19, 3, .petal), (20, 3, .petal),
    ]

    /// The leaves he actually eats: a serrated rosette hanging from his mouth. The
    /// nearest lobe is against his face at the row he bites on, and the run of the
    /// teeth is staggered so it reads as a dandelion leaf rather than a green blob.
    ///
    /// The column nearest the face is x=16, which is one cell past the front of
    /// his head; the row he bites on is the lowest row of the reeling head, since
    /// that is where a tortoise's mouth is. `AnimationSheetTests` checks the two
    /// meet rather than trusting these numbers to stay in step with the poses.
    static let rosetteLeaves: [(x: Int, y: Int, cell: TortoiseCell)] = [
        // upper lobe, pointing away from the bite
        (17, 8, .leaf), (18, 8, .leaf), (19, 8, .leaf),
        (18, 9, .leaf), (19, 9, .leaf), (20, 9, .leaf), (21, 9, .leaf),
        (16, 10, .leaf), (17, 10, .leaf), (18, 10, .leaf),
        (19, 10, .leaf), (20, 10, .leaf), (21, 10, .leaf),
        // the body of the leaf, down to the bite
        (16, 11, .leaf), (17, 11, .leaf), (19, 11, .leaf), (20, 11, .leaf),
        (16, 12, .leaf), (17, 12, .leaf), (18, 12, .leaf), (19, 12, .leaf),
        (16, 13, .leaf), (17, 13, .leaf), (18, 13, .leaf),
        // the tip, level with his mouth
        (16, 14, .leaf), (16, 15, .leaf),
    ]
}

/// A sprig at the mouth: the little dandelion leaf he nibbles each minute.
enum TortoiseLeaf: Equatable {
    case none
    /// Stem and blade, out at arm's length.
    case sprig
    /// The same leaf with the blade chewed away, just before it disappears.
    case stripped

    var cells: [(x: Int, y: Int, cell: TortoiseCell)] {
        switch self {
        case .none:
            return []
        case .sprig:
            return [
                (16, 10, .leaf), (17, 10, .leaf), (18, 10, .leaf),
                (16, 11, .leaf), (17, 11, .leaf), (18, 11, .leaf), (19, 11, .leaf),
                (15, 12, .stem), (16, 12, .leaf), (17, 12, .leaf), (18, 12, .leaf),
                (16, 13, .leaf), (17, 13, .leaf),
            ]
        case .stripped:
            return [(15, 12, .stem)]
        }
    }
}

/// One rendered frame of the tortoise: which pose he holds, what is in front of
/// him, and the loose detailing that makes the motion read.
struct TortoiseFrame: Equatable {
    var pose: TortoisePose
    var plant: TortoisePlant = .none
    /// 0...1, lets a prop fade out instead of popping.
    var plantAlpha: Double = 1
    var leaf: TortoiseLeaf = .none
    /// Crumbs at the mouth, 0 when there are none.
    var crumbs: Double = 0
    /// How far a sleeping "z" has drifted: 0 at the head, 1 fully gone, nil for
    /// no z at all.
    var sleepZ: Double?

    /// The pose in which nothing is animating.
    static let rest = TortoiseFrame(pose: .resting)
}

/// Builds the drawable scene: the tortoise's pose plus whatever is in front of
/// him, as one grid of cells.
///
/// The scene is deliberately larger than the tortoise. He is bottom-anchored in
/// the bottom-left 16x16; the rows above are headroom for the sleeping z's and
/// the dandelion's flower, and the columns to the right are where the leaf he
/// eats lives. Growing the scene therefore never moves him on screen.
struct TortoiseScene {
    /// One pixel of a prop, as drawn: which cell, and how opaque.
    struct Prop {
        var x: Int
        var y: Int
        var cell: TortoiseCell
        var alpha: Double
    }

    static let spriteX = 0
    static let spriteY = 4
    /// Wide enough for the dandelion to sit against his mouth rather than on top
    /// of him, and tall enough for the z's to float clear above his head.
    static let width = 22
    static let height = 20

    var frame: TortoiseFrame

    init(frame: TortoiseFrame) {
        self.frame = frame
    }

    /// The tortoise's own cell at a sprite coordinate, in the current pose.
    func spriteCell(x: Int, y: Int) -> TortoiseCell {
        guard x >= 0, x < TortoiseSprite.size, y >= 0, y < TortoiseSprite.size else { return .empty }
        let rows = frame.pose.rows
        guard y < rows.count else { return .empty }
        let row = Array(rows[y])
        guard x < row.count else { return .empty }
        return TortoiseCell(rawValue: row[x]) ?? .empty
    }

    /// Props for this frame, back to front.
    var props: [Prop] {
        var out: [Prop] = []
        for cell in frame.plant.cells {
            out.append(Prop(x: cell.x, y: cell.y, cell: cell.cell, alpha: frame.plantAlpha))
        }
        for cell in frame.leaf.cells {
            out.append(Prop(x: cell.x, y: cell.y, cell: cell.cell, alpha: 1))
        }
        if frame.crumbs > 0 {
            for spot in [(16, 12), (18, 13), (16, 14)] {
                out.append(Prop(x: spot.0, y: spot.1, cell: .crumb, alpha: frame.crumbs))
            }
        }
        if let drift = frame.sleepZ {
            out += TortoiseScene.sleepZ(drift: drift)
        }
        return out
    }

    /// A small "z" drifting up from the back of the shell and fading out.
    ///
    /// Sits over the crown of the shell rather than out to one side, so it reads
    /// as coming off the sleeping tortoise instead of floating in the corner.
    /// While he sleeps his head is inside the shell, so the headroom the z rises
    /// through is empty, and the lowest of the glyph touches the crown row.
    static func sleepZ(drift: Double) -> [Prop] {
        // Over the crown, which is columns 4...7 of the sprite.
        let x0 = 5
        let y0 = 4 - Int((drift * 3).rounded())
        let alpha: Double = drift < 0.45 ? 1 : max(0, (1 - drift) / 0.55)
        guard alpha > 0 else { return [] }
        let shape = [(0, 0), (1, 0), (2, 0), (1, 1), (0, 2), (1, 2), (2, 2)]
        return shape.map { Prop(x: x0 + $0.0, y: y0 + $0.1, cell: .sleepGlyph, alpha: alpha) }
    }

    /// The cell drawn at a scene coordinate, props winning over the tortoise, or
    /// nil when the pixel is transparent.
    func cell(x: Int, y: Int) -> (cell: TortoiseCell, alpha: Double)? {
        guard x >= 0, x < TortoiseScene.width, y >= 0, y < TortoiseScene.height else { return nil }

        for prop in props where prop.x == x && prop.y == y && prop.alpha > 0 {
            return (prop.cell, prop.alpha)
        }

        let sx = x - TortoiseScene.spriteX
        let sy = y - TortoiseScene.spriteY
        guard sy >= 0, sy < TortoiseSprite.size else { return nil }
        let cell = spriteCell(x: sx, y: sy)
        guard cell.coversPixel else { return nil }
        return (cell, 1)
    }

    /// True when a scene cell has ink in it, for pixel-accurate click-through.
    func covers(x: Int, y: Int) -> Bool { cell(x: x, y: y) != nil }
}
