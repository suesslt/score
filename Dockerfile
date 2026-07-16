FROM swift:6.1-noble

WORKDIR /package
COPY Package.swift ./
COPY Sources ./Sources
COPY Tests ./Tests

# ScoreUI ist Apple-only (SwiftUI/CoreGraphics) — auf Linux nur das Score-Target bauen.
# (--product Score würde via SwiftPM trotzdem alle Targets mitbauen.)
RUN swift build --target Score
