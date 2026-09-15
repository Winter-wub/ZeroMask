import SwiftUI
import Charts

// จอ "อำพราง" ตอนสลับแอป: แดชบอร์ดสถิติพิกเกิลบอลปลอม ๆ ที่ดูสมจริง + เลื่อนเองช้า ๆ
// แทนที่การเบลอเดิม — ใครแอบดู app switcher จะเห็นเป็นแอปกีฬาธรรมดา
struct PickleDashboard: View {
    private let brand = Color(red: 0.09, green: 0.63, blue: 0.34)
    private let brandLight = Color(red: 0.18, green: 0.78, blue: 0.44)

    @State private var scrollTarget = 0
    @State private var animateRing = false

    // แถบกิจกรรมรายวัน (จ.–อา.)
    private let week: [(day: String, games: Int)] = [
        ("Mon", 2), ("Tue", 1), ("Wed", 3), ("Thu", 0),
        ("Fri", 2), ("Sat", 4), ("Sun", 3)
    ]
    // เทรนด์เรตติ้ง (DUPR) 8 จุดล่าสุด
    private let rating: [Double] = [4.02, 4.08, 4.05, 4.14, 4.19, 4.22, 4.28, 4.35]
    // แมตช์ล่าสุด
    private let matches: [(opp: String, score: String, win: Bool)] = [
        ("Aomsin", "11–7", true),
        ("Krit", "9–11", false),
        ("Bank", "11–4", true),
        ("Mild", "11–9", true),
        ("Tarn", "8–11", false),
        ("Prima", "11–6", true),
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    header.id(0)
                    heroCard
                    statTiles
                    activityCard.id(1)
                    ratingCard
                    recentMatches.id(2)
                    achievements
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(bg)
            .onReceive(Timer.publish(every: 2.6, on: .main, in: .common).autoconnect()) { _ in
                // เลื่อนเองช้า ๆ ให้ดูเหมือนกำลังใช้งานอยู่ วนกลับขึ้นบน
                scrollTarget = (scrollTarget + 1) % 3
                withAnimation(.easeInOut(duration: 1.6)) {
                    proxy.scrollTo(scrollTarget, anchor: .top)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) { animateRing = true }
            }
        }
    }

    // พื้นหลังทึบเต็มจอ (สีระบบ) + สีเขียวจาง ๆ วางทับด้านบน — ไม่ให้ทะลุเห็น Tinder
    private var bg: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(colors: [brand.opacity(0.12), .clear],
                           startPoint: .top, endPoint: .center)
        }
        .ignoresSafeArea()
    }

    // ── Header ──
    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Good evening")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                HStack(spacing: 7) {
                    Image(systemName: "circle.grid.3x3.fill").foregroundColor(brand)
                    Text("PickleWatch")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
            }
            Spacer()
            Circle().fill(LinearGradient(colors: [brandLight, brand],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 38, height: 38)
                .overlay(Text("P").font(.system(size: 17, weight: .bold)).foregroundColor(.white))
        }
        .padding(.top, 6)
    }

    // ── Hero: สัปดาห์นี้ + วงแหวนอัตราชนะ ──
    private var heroCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(brand.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: animateRing ? 0.68 : 0)
                    .stroke(brand, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("68%").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("win").font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 10) {
                Text("This Week").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                heroStat("15", "matches")
                heroStat("4.2 h", "on court")
            }
            Spacer()
        }
        .padding(16)
        .background(card)
    }

    private func heroStat(_ v: String, _ l: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(v).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(l).font(.system(size: 13)).foregroundColor(.secondary)
        }
    }

    // ── Stat tiles ──
    private var statTiles: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            tile("flame.fill", "2,480", "kcal burned", .orange)
            tile("figure.pickleball", "3.8 km", "distance", brand)
            tile("bolt.fill", "8.4", "avg rally", .blue)
            tile("trophy.fill", "6W", "best streak", .yellow)
        }
    }

    private func tile(_ icon: String, _ value: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(Circle().fill(color.opacity(0.15)))
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 17, weight: .bold, design: .rounded))
                Text(label).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(card)
    }

    // ── Weekly activity bar chart ──
    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Weekly Activity", "games played")
            Chart(week, id: \.day) { d in
                BarMark(x: .value("Day", d.day),
                        y: .value("Games", d.games),
                        width: .fixed(18))
                    .foregroundStyle(brand.gradient)
                    .cornerRadius(5)
            }
            .frame(height: 130)
            .chartYAxis { AxisMarks(position: .leading, values: [0, 2, 4]) }
        }
        .padding(16)
        .background(card)
    }

    // ── Rating trend area chart ──
    private var ratingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                cardTitle("DUPR Rating", "last 8 sessions")
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold))
                    Text("+0.33").font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(brand)
            }
            Chart(Array(rating.enumerated()), id: \.offset) { i, v in
                LineMark(x: .value("s", i), y: .value("r", v))
                    .foregroundStyle(brand)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("s", i), y: .value("r", v))
                    .foregroundStyle(brand.opacity(0.15).gradient)
                    .interpolationMethod(.catmullRom)
            }
            .frame(height: 110)
            .chartXAxis(.hidden)
            .chartYScale(domain: 3.9...4.5)
            .chartYAxis { AxisMarks(position: .leading, values: [4.0, 4.25, 4.5]) }
        }
        .padding(16)
        .background(card)
    }

    // ── Recent matches ──
    private var recentMatches: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Recent Matches", "")
            ForEach(matches.indices, id: \.self) { i in
                let m = matches[i]
                HStack(spacing: 12) {
                    Circle().fill(Color.secondary.opacity(0.15))
                        .frame(width: 34, height: 34)
                        .overlay(Text(String(m.opp.prefix(1)))
                            .font(.system(size: 15, weight: .semibold)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("vs \(m.opp)").font(.system(size: 15, weight: .medium))
                        Text("Singles · Court \(i % 3 + 1)")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(m.score).font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(m.win ? "W" : "L")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(m.win ? brand : Color.red.opacity(0.75)))
                }
                if i < matches.count - 1 { Divider() }
            }
        }
        .padding(16)
        .background(card)
    }

    // ── Achievements ──
    private var achievements: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Achievements", "")
            HStack(spacing: 12) {
                badge("flame.fill", "6-day", "streak", .orange)
                badge("star.fill", "Level 12", "Advanced", brand)
                badge("medal.fill", "Top 8%", "local", .blue)
            }
        }
        .padding(16)
        .background(card)
    }

    private func badge(_ icon: String, _ t: String, _ s: String, _ c: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 20)).foregroundColor(c)
                .frame(width: 46, height: 46)
                .background(Circle().fill(c.opacity(0.15)))
            Text(t).font(.system(size: 12, weight: .semibold))
            Text(s).font(.system(size: 10)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // ── helpers ──
    private func cardTitle(_ t: String, _ s: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(t).font(.system(size: 15, weight: .semibold))
            if !s.isEmpty { Text(s).font(.system(size: 11)).foregroundColor(.secondary) }
        }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.secondarySystemBackground))
    }
}
