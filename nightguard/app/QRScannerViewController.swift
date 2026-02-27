//
//  QRScannerViewController.swift
//  nightguard
//
//  Created by JamOrHam on 27/02/2026.
//

import Foundation
import UIKit
import AVFoundation
import AudioToolbox

protocol QRScannerDelegate: AnyObject {
    func didScanQRCode(_ code: String)
    func didFailScanning(error: Error)
}

final class QRScannerViewController: UIViewController {

    weak var delegate: QRScannerDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraPermission()
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupScanner()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    granted ? self.setupScanner() : self.dismiss(animated: true)
                }
            }
        default:
            dismiss(animated: true)
        }
    }

    private func setupScanner() {
        let session = AVCaptureSession()
        guard let videoDevice = AVCaptureDevice.default(for: .video) else { return }

        do {
            let input = try AVCaptureDeviceInput(device: videoDevice)

            if session.canAddInput(input) {
                session.addInput(input)
            }

            let metadataOutput = AVCaptureMetadataOutput()

            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
                metadataOutput.metadataObjectTypes = [.qr]
            }

            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer?.frame = view.layer.bounds
            previewLayer?.videoGravity = .resizeAspectFill

            if let previewLayer = previewLayer {
                view.layer.addSublayer(previewLayer)
            }

            captureSession = session
            session.startRunning()

        } catch {
            delegate?.didFailScanning(error: error)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {

        captureSession?.stopRunning()

        guard
            let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let stringValue = metadataObject.stringValue
        else { return }

        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        delegate?.didScanQRCode(stringValue)
    }
}
