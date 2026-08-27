import AppKit

/// El ícono de la barra de menú: un cerdito de contorno que se va llenando
/// de abajo hacia arriba conforme el total se acerca a la meta.
///
/// Se dibuja como imagen de plantilla (`isTemplate`), así que macOS lo tiñe
/// solo para que combine con la barra clara u oscura, igual que los íconos
/// del sistema.
enum PiggyBankIcon {
    /// El cerdito se dibuja en este espacio y luego se escala al tamaño final.
    private static let designWidth: CGFloat = 100
    private static let designHeight: CGFloat = 84

    private static let body = CGRect(x: 26, y: 26, width: 56, height: 40)
    private static let snout = CGRect(x: 13, y: 44, width: 17, height: 13)

    private static let earTip = CGPoint(x: 44, y: 16)
    private static let earFront = CGPoint(x: 46, y: 29)
    private static let earBack = CGPoint(x: 56, y: 26)

    private static let eyeCenter = CGPoint(x: 39, y: 40)
    private static let eyeRadius: CGFloat = 4.2

    /// Ranura de la moneda, dibujada dentro del lomo.
    private static let slotStart = CGPoint(x: 58, y: 33)
    private static let slotEnd = CGPoint(x: 69, y: 36)
    private static let slotWidth: CGFloat = 6

    private static let strokeWidth: CGFloat = 8.5

    /// Debajo de esta altura la ranura de la moneda se omite: a tamaño de barra
    /// de menú se funde con la oreja y sólo ensucia la silueta. En el panel de
    /// escritorio, que es más grande, sí cabe y aporta.
    private static let slotMinimumHeight: CGFloat = 24

    /// - Parameters:
    ///   - progress: nivel de llenado de 0 a 1, o `nil` cuando no hay meta
    ///     definida (el cerdito se queda vacío).
    ///   - accessibilityDescription: lo que lee VoiceOver — el total acumulado.
    ///   - height: altura del ícono en puntos; el ancho se deriva de la
    ///     proporción del dibujo.
    static func image(
        progress: Double?,
        accessibilityDescription: String,
        height: CGFloat = 18
    ) -> NSImage {
        let width = height * designWidth / designHeight
        let image = NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            draw(in: context, scale: height / designHeight, height: height, progress: progress)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }

    private static func draw(in context: CGContext, scale: CGFloat, height: CGFloat, progress: Double?) {
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        context.setStrokeColor(NSColor.black.cgColor)
        context.setFillColor(NSColor.black.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Patas, cola y oreja van primero: lo que quede dentro del cuerpo lo
        // tapa el relleno, de modo que sólo asoma la parte de afuera.
        strokeLegs(in: context)
        strokeTail(in: context)
        strokeEar(in: context)

        if let fillTop = fillTopY(for: progress) {
            fillSilhouette(in: context, from: fillTop)
        }

        strokeSilhouette(in: context)

        // El ojo y la ranura son detalles interiores: cuando el relleno ya los
        // cubrió los recortamos para que sigan viéndose en negativo.
        let fillTop = fillTopY(for: progress)
        drawEye(in: context, fillTop: fillTop)
        if height >= slotMinimumHeight {
            drawCoinSlot(in: context, fillTop: fillTop)
        }

        context.restoreGState()
    }

    /// Altura donde arranca el relleno, o `nil` si no hay nada que llenar.
    private static func fillTopY(for progress: Double?) -> CGFloat? {
        guard let progress, progress > 0 else { return nil }
        let clamped = CGFloat(min(max(progress, 0), 1))
        return body.maxY - body.height * clamped
    }

    /// Rellena cuerpo y hocico como una sola silueta, para que el nivel se vea
    /// continuo entre los dos.
    private static func fillSilhouette(in context: CGContext, from top: CGFloat) {
        let silhouette = CGMutablePath()
        silhouette.addEllipse(in: body)
        silhouette.addEllipse(in: snout)

        context.saveGState()
        context.addPath(silhouette)
        context.clip()
        context.fill(CGRect(x: 0, y: top, width: designWidth, height: designHeight - top))
        context.restoreGState()
    }

    /// Cuerpo y hocico se contornean recortando cada uno el interior del otro,
    /// para que juntos lean como una sola silueta y no como dos óvalos encimados.
    private static func strokeSilhouette(in context: CGContext) {
        context.saveGState()
        clip(outside: snout, in: context)
        context.strokeEllipse(in: body)
        context.restoreGState()

        context.saveGState()
        clip(outside: body, in: context)
        context.strokeEllipse(in: snout)
        context.restoreGState()
    }

    private static func strokeEar(in context: CGContext) {
        context.saveGState()
        clip(outside: body, in: context)
        context.move(to: earFront)
        context.addLine(to: earTip)
        context.addLine(to: earBack)
        context.strokePath()
        context.restoreGState()
    }

    private static func strokeTail(in context: CGContext) {
        context.move(to: CGPoint(x: 80, y: 42))
        context.addQuadCurve(to: CGPoint(x: 89, y: 48), control: CGPoint(x: 91, y: 37))
        context.strokePath()
    }

    private static func strokeLegs(in context: CGContext) {
        let legs = [
            (x: CGFloat(39), bottom: CGFloat(69)),
            (x: CGFloat(72), bottom: CGFloat(69))
        ]
        context.saveGState()
        clip(outside: body, in: context)
        for leg in legs {
            // Arrancan dentro del cuerpo y el recorte deja ver sólo lo que
            // asoma por debajo, así no queda costura visible.
            context.move(to: CGPoint(x: leg.x, y: body.midY))
            context.addLine(to: CGPoint(x: leg.x, y: leg.bottom))
        }
        context.strokePath()
        context.restoreGState()
    }

    private static func drawEye(in context: CGContext, fillTop: CGFloat?) {
        let rect = CGRect(
            x: eyeCenter.x - eyeRadius,
            y: eyeCenter.y - eyeRadius,
            width: eyeRadius * 2,
            height: eyeRadius * 2
        )
        context.saveGState()
        if isCovered(by: fillTop, atY: eyeCenter.y + eyeRadius) {
            context.setBlendMode(.clear)
        }
        context.fillEllipse(in: rect)
        context.restoreGState()
    }

    private static func drawCoinSlot(in context: CGContext, fillTop: CGFloat?) {
        context.saveGState()
        context.setLineWidth(slotWidth)
        if isCovered(by: fillTop, atY: max(slotStart.y, slotEnd.y) + slotWidth / 2) {
            context.setBlendMode(.clear)
        }
        context.move(to: slotStart)
        context.addLine(to: slotEnd)
        context.strokePath()
        context.restoreGState()
    }

    private static func isCovered(by fillTop: CGFloat?, atY y: CGFloat) -> Bool {
        guard let fillTop else { return false }
        return fillTop <= y
    }

    /// Recorta todo menos el interior de la elipse dada.
    private static func clip(outside ellipse: CGRect, in context: CGContext) {
        let path = CGMutablePath()
        path.addRect(CGRect(x: -designWidth, y: -designHeight,
                            width: designWidth * 3, height: designHeight * 3))
        path.addEllipse(in: ellipse)
        context.addPath(path)
        context.clip(using: .evenOdd)
    }
}
