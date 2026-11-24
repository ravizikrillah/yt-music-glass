import SwiftUI

/// Shared interactive Tap-to-Sync stage rendered inside both Lyrics Sidebar and Full Screen Lyrics.
struct TapSyncPanelView: View {
    @ObservedObject var store: AppStore
    let compactLayout: Bool

    var body: some View {
        if let session = store.tapSyncSession {
            VStack(spacing: 0) {
                headerBar(session: session)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                linesScrollList(session: session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                actionDock(session: session)
            }
            .frame(maxWidth: compactLayout ? .infinity : 920)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, compactLayout ? 0 : 72)
            .padding(.bottom, compactLayout ? 0 : 12)
        }
    }

    private func headerBar(session: TapSyncSession) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: compactLayout ? 11 : 12.5, weight: .semibold))
                        .foregroundStyle(store.palette.accentColor)
                    Text("Live Tap-to-Sync")
                        .font(AppFont.styled(compactLayout ? 13 : 15, weight: .bold, style: store.fontStyle))
                        .foregroundStyle(.white.opacity(0.96))
                }
                Text("Press Space or Tap Line as each lyric starts · Click any line to re-sync from there")
                    .font(.system(size: compactLayout ? 10.5 : 11.5))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Text(TapSyncSession.formatLrcTimestamp(store.tapSyncElapsedTime))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(store.palette.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(store.palette.accentColor.opacity(0.16))
                    .clipShape(Capsule())

                Text("\(session.tappedCount)/\(session.totalCount)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.84))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())

                Button {
                    store.restartTapSyncFromBeginning()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 9.5, weight: .semibold))
                        Text("0:00")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Reset taps and restart track from 0:00")
            }
        }
        .padding(.horizontal, compactLayout ? 14 : 24)
        .padding(.vertical, compactLayout ? 10 : 14)
    }

    private func linesScrollList(session: TapSyncSession) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: !compactLayout) {
                LazyVStack(alignment: .leading, spacing: compactLayout ? 8 : 10) {
                    ForEach(session.lines) { line in
                        let isNext = line.id == session.currentIndex
                        let isTapped = line.timestamp != nil
                        let romaji = store.autoRomanizeEnabled
                            ? Romanizer.romanizeLine(line.text)
                            : nil

                        Button {
                            store.tapSyncJump(to: line.id)
                        } label: {
                            HStack(spacing: 10) {
                                Text(line.timestamp.map { TapSyncSession.formatLrcTimestamp($0) } ?? (isNext ? "NEXT" : "--:--.--"))
                                    .font(.system(size: 10.5, weight: .bold).monospacedDigit())
                                    .foregroundStyle(
                                        isTapped
                                            ? store.palette.accentColor
                                            : (isNext ? .white : .white.opacity(0.36))
                                    )
                                    .frame(width: 70, alignment: .center)
                                    .padding(.vertical, 4)
                                    .background(
                                        isTapped
                                            ? store.palette.accentColor.opacity(0.16)
                                            : (isNext ? store.palette.accentColor.opacity(0.32) : Color.white.opacity(0.06))
                                    )
                                    .clipShape(Capsule())

                                VStack(alignment: .leading, spacing: 2) {
                                    if romaji != nil {
                                        Text(line.text)
                                            .font(AppFont.styled(compactLayout ? 11.5 : 13, weight: .regular, style: store.fontStyle))
                                            .foregroundStyle(.white.opacity(isNext ? 0.80 : 0.48))
                                    }
                                    Text(romaji ?? line.text)
                                        .font(AppFont.styled(compactLayout ? (isNext ? 16 : 14) : (isNext ? 20 : 16), weight: isNext ? .bold : .medium, style: store.fontStyle))
                                        .foregroundStyle(.white.opacity(isNext ? 0.98 : (isTapped ? 0.72 : 0.44)))
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer(minLength: 0)

                                if isTapped {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(store.palette.accentColor.opacity(0.9))
                                }
                            }
                            .padding(.horizontal, compactLayout ? 10 : 14)
                            .padding(.vertical, isNext ? (compactLayout ? 11 : 14) : 8)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(isNext ? Color.white.opacity(0.08) : Color.white.opacity(isTapped ? 0.03 : 0.015))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(
                                        isNext ? store.palette.accentColor.opacity(0.60) : Color.white.opacity(0.06),
                                        lineWidth: isNext ? 1.2 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .id(line.id)
                    }
                }
                .padding(.horizontal, compactLayout ? 12 : 24)
                .padding(.vertical, 14)
            }
            .onChange(of: session.currentIndex) { nextIdx in
                let target = min(nextIdx, max(0, session.totalCount - 1))
                withAnimation(.easeInOut(duration: 0.22)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
    }

    private func actionDock(session: TapSyncSession) -> some View {
        HStack(spacing: 8) {
            Button {
                store.cancelTapSync()
            } label: {
                Text("Cancel")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.80))
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.11), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                store.tapSyncUndo()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Undo")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(session.tappedCount > 0 ? 0.90 : 0.36))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color.white.opacity(0.07))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.11), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(session.tappedCount == 0)
            .help("Undo last tapped line (⌫)")

            Button {
                store.tapSyncNext()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: session.isComplete ? "checkmark.seal.fill" : "hand.tap.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(session.isComplete ? "All Lines Synced" : "Tap Line (Space)")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    session.isComplete
                        ? Color.white.opacity(0.12)
                        : store.palette.accentColor.opacity(0.32)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        session.isComplete ? Color.white.opacity(0.18) : store.palette.accentColor.opacity(0.68),
                        lineWidth: 1
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(session.isComplete)

            Button {
                store.saveTapSync()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("Save")
                        .font(.system(size: 11.5, weight: .bold))
                }
                .foregroundStyle(.white.opacity(session.tappedCount > 0 ? 0.96 : 0.38))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    session.tappedCount > 0
                        ? store.palette.accentColor.opacity(0.28)
                        : Color.white.opacity(0.06)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        session.tappedCount > 0 ? store.palette.accentColor.opacity(0.55) : Color.white.opacity(0.10),
                        lineWidth: 1
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(session.tappedCount == 0)
            .help("Save synced LRC and apply immediately")
        }
        .padding(.horizontal, compactLayout ? 12 : 24)
        .padding(.vertical, compactLayout ? 10 : 14)
    }
}
