import SwiftUI

struct KnobView: View {
    let value: Float
    var isMuted: Bool = false

    private let startAngle: Double = 225
    private let endAngle: Double = 495

    private var currentAngle: Double {
        startAngle + Double(value) * (endAngle - startAngle)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let knobRadius = size * 0.4
            let indicatorLength = size * 0.12
            let tickRadius = size * 0.46

            ZStack {
                // Volume arc
                Arc(startAngle: startAngle, endAngle: currentAngle)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: tickRadius * 2, height: tickRadius * 2)

                // Knob base
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.35),
                                Color(white: 0.25)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: knobRadius * 2, height: knobRadius * 2)

                // Knob top highlight
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(white: 0.45),
                                Color(white: 0.3)
                            ],
                            center: .init(x: 0.3, y: 0.3),
                            startRadius: 0,
                            endRadius: knobRadius
                        )
                    )
                    .frame(width: knobRadius * 1.9, height: knobRadius * 1.9)

                // Indicator notch
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 4, height: indicatorLength)
                    .cornerRadius(2)
                    .offset(y: -knobRadius + indicatorLength / 2 + 8)
                    .rotationEffect(.degrees(currentAngle))
                    .shadow(color: .black.opacity(0.3), radius: 1)

                // Mute icon
                if isMuted || value == 0 {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: knobRadius * 0.6))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }

                // Tick marks
                ForEach(0..<11) { i in
                    let tickAngle = startAngle + Double(i) * (endAngle - startAngle) / 10
                    let isMajor = i % 5 == 0
                    let tickLength: CGFloat = isMajor ? 10 : 6

                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: isMajor ? 2 : 1, height: tickLength)
                        .offset(y: -size * 0.48 + tickLength / 2)
                        .rotationEffect(.degrees(tickAngle))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .animation(.easeOut(duration: 0.10), value: value)
    }
}

struct Arc: Shape {
    var startAngle: Double
    var endAngle: Double

    var animatableData: Double {
        get { endAngle }
        set { endAngle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle - 90),
            endAngle: .degrees(endAngle - 90),
            clockwise: false
        )

        return path
    }
}

#Preview("Knob at 80 percent") {
    KnobView(value: 0.8)
        .frame(width: 200, height: 200)
        .padding(40)
}

#Preview("Knob Muted") {
    KnobView(value: 0)
        .frame(width: 200, height: 200)
        .padding(40)
}
