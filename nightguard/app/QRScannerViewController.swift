//
//  QRScannerViewController.swift
//  nightguard
//
//  Created by JamOrHam on 27/02/2026.
//

import Foundation
import UIKit
import AVFoundation
#if canImport(AudioToolbox)
import AudioToolbox
#endif

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
        addCloseButton()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
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
    
    private func addCloseButton() {
        var config = UIButton.Configuration.filled()
        config.title = "Close"
        config.baseBackgroundColor = UIColor.black.withAlphaComponent(0.6)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)

        let closeButton = UIButton(configuration: config)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(dismissScanner), for: .touchUpInside)

        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
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
            DispatchQueue.global(qos: .utility).async {
                session.startRunning()
            }
           
        } catch {
            delegate?.didFailScanning(error: error)
        }
    }
    
    @objc private func dismissScanner() {
        captureSession?.stopRunning()
        dismiss(animated: true)
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
