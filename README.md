# BillSnap

AR bill splitting that deep-links into Vipps and MobilePay.
Point your camera at a restaurant bill, tap the items, assign them to the people who ate them — and BillSnap opens Vipps for each person with their exact amount pre-filled.

![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![iOS](https://img.shields.io/badge/iOS-17%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)

---

## What makes this different

Every other bill-splitting app asks you to manually type in amounts. BillSnap uses the device camera and Apple's Vision framework to read the bill in real time — price lines float as tappable AR chips directly over the physical receipt. There is no form to fill in.

The flow is four steps:

1. **Add diners** — type names (and optionally phone numbers)
2. **Scan the bill** — live camera feed with OCR; tap floating chips to confirm items
3. **Assign items** — drag-and-drop style assignment of each item to the people who ate it; shared items split automatically
4. **Pay** — one Vipps or MobilePay button per person, pre-filled with their exact share

---

## Tech

| | |
|---|---|
| Language | Swift 6, strict concurrency enabled |
| UI | SwiftUI + `@Observable` |
| Camera | AVFoundation (`AVCaptureSession`) |
| OCR | Vision (`VNRecognizeTextRequest`, `.fast` level for live video) |
| AR overlay | Pure SwiftUI `GeometryReader` + normalised coordinate mapping |
| Persistence | SwiftData |
| Payments | Vipps MobilePay deeplink API |
| Dependencies | **Zero** |

---

## Architecture

```
BillSnap/
├── App/
│   ├── VippsARApp.swift            # @main, ModelContainer setup
│   ├── AppContainer.swift          # @Observable root state; owns all services
│   └── RootView.swift              # TabView shell
│
├── Features/
│   ├── ARSplit/
│   │   ├── ARSplitSession.swift    # @Observable session model (all 4 phases)
│   │   ├── ARSplitEntryView.swift  # Start screen + phase shell + PhaseIndicator
│   │   ├── AddDinersView.swift     # Phase 1 — add diners
│   │   ├── ScanBillView.swift      # Phase 2 — live camera + OCR frame loop
│   │   ├── AssignItemsView.swift   # Phase 3 — item-to-diner assignment
│   │   ├── PaymentView.swift       # Phase 4 — per-diner Vipps buttons
│   │   ├── AROverlayView.swift     # Transparent overlay with bounding-box chips
│   │   ├── CameraPreviewView.swift # UIViewRepresentable for AVCaptureVideoPreviewLayer
│   │   └── CameraFeedController.swift  # ObservableObject wrapping AVCaptureSession
│   │
│   └── History/
│       ├── HistoryView.swift       # SwiftData @Query list
│       └── PersistenceModels.swift # BillSession, BillItem, Diner @Model definitions
│
└── Services/
    ├── MenuOCRService.swift        # actor — Vision pipeline, price pairing, dedup
    ├── VippsDeepLinkService.swift  # Builds vipps:// and mobilepay:// URLs
    └── HapticsService.swift        # UIImpactFeedbackGenerator wrapper
```

---

## OCR pipeline

`MenuOCRService` is a Swift `actor` that processes one camera frame at a time (frames are throttled to ~3/sec to stay off the main thread).

For each frame:

1. Run `VNRecognizeTextRequest` at `.fast` recognition level — accurate enough for printed receipts, fast enough for live video
2. Detect text observations and group them into `TextLine` structs with normalised bounding boxes
3. For each line containing a price pattern (`\d{1,4}[,.]\d{2}`), look for an adjacent label on the same horizontal band
4. Merge the label and price bounding boxes; flip Y-axis from Vision space (bottom-left origin) to UIKit space (top-left origin)
5. Deduplicate across frames by comparing vertical position and price value

Results are published back to `ScanBillView` via a `Combine` sink on `CameraFeedController.$latestFrame`.

---

## Deep link integration

`VippsDeepLinkService` auto-detects locale at launch (`DK` → MobilePay, everything else → Vipps) and builds the appropriate URL scheme.

Amounts are converted to øre (smallest unit) before URL construction:
- `149.50 NOK` → query param `"14950"`

```
Norway:  vipps://payment?amount=14950&recipient=98765432&message=BillSnap
Denmark: mobilepay://send?amount=14950&to=12345678&comment=BillSnap
```

---

## Running it

Requires Xcode 16+ and iOS 17. No API keys or config needed.

```bash
git clone https://github.com/yourusername/BillSnap
open BillSnap.xcodeproj
```

Camera permission is required for scanning. Run on a **physical device** with Vipps or MobilePay installed to test the payment deep link — the simulator will show a "cannot open URL" alert as expected.

---

## What's next

- [ ] Line-item QR codes so each diner can scan to claim their share
- [ ] Running group tabs across multiple visits to the same restaurant
- [ ] Vipps Login (OAuth) integration to fetch contacts directly from the Vipps address book
- [ ] On-device ML model fine-tuned on Nordic receipt layouts for higher OCR accuracy
- [ ] Home screen widget for rapid "same group, new bill" sessions

---

## Why I built this

Vipps and MobilePay are already the settlement layer for 12 million people across the Nordics. The friction isn't the payment — it's the 60 seconds before it, figuring out who owes what. BillSnap removes that friction entirely by reading the bill directly through the camera.

---

## License

MIT. Not affiliated with Vipps MobilePay AS.
