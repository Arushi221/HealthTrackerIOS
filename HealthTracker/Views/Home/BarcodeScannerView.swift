import SwiftUI
import SwiftData
import AVFoundation

struct BarcodeScannerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var goals: [Goal]

    @State private var scannedCode: String?
    @State private var fetchedProduct: FoodProduct?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingProductSheet = false

    var body: some View {
        ZStack {
            CameraPreviewView(scannedCode: $scannedCode)
                .ignoresSafeArea()

            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white, lineWidth: 2)
                    .frame(width: 260, height: 120)
                Spacer()

                if isLoading {
                    ProgressView("Looking up product…")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer().frame(height: 40)
            }
        }
        .navigationTitle("Scan Barcode")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scannedCode) { _, code in
            guard let code, fetchedProduct == nil else { return }
            Task { await lookUp(barcode: code) }
        }
        .sheet(item: $fetchedProduct) { product in
            AddFoodToMealView(product: product, onSave: { dismiss() })
        }
    }

    private func lookUp(barcode: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let product = try await FoodLookupService.shared.lookup(barcode: barcode)
            fetchedProduct = product
        } catch {
            errorMessage = (error as? OFFError)?.errorDescription ?? error.localizedDescription
            scannedCode = nil
        }
        isLoading = false
    }
}

// Thin UIKit wrapper for AVCaptureSession
struct CameraPreviewView: UIViewControllerRepresentable {
    @Binding var scannedCode: String?

    func makeUIViewController(context: Context) -> ScannerViewController {
        ScannerViewController(scannedCode: $scannedCode)
    }

    func updateUIViewController(_ vc: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    @Binding var scannedCode: String?
    private var session: AVCaptureSession?

    init(scannedCode: Binding<String?>) {
        _scannedCode = scannedCode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { self.session?.startRunning() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session?.stopRunning()
    }

    private func setupSession() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)

        self.session = session
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue,
              scannedCode == nil else { return }
        scannedCode = code
    }
}
