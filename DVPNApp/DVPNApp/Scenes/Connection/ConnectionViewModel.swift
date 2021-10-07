import Combine
import SentinelWallet
import SwiftUI
import FlagKit
import GRPC

final class ConnectionViewModel: ObservableObject {
    typealias Router = AnyRouter<Route>
    private let router: Router
    
    @Published private(set) var bandwidthConsumedGB: String?
    
    @Published private var downloadSpeed: String?
    @Published private var downloadSpeedUnits: String?
    @Published private var uploadSpeed: String?
    @Published private var uploadSpeedUnits: String?
    
    @Published private var initialBandwidthGB: String?
    @Published private var duration: String?
    
    // Location Selector
    @Published private(set) var countryImage: UIImage?
    @Published private(set) var countryName: String?
    @Published private(set) var moniker: String?
    @Published private(set) var speedImage: UIImage?
    
    // Connection Status
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected
    
    @Published private(set) var connectionInfoViewModels: [GridViewModelType] = []

    @Published var isLoading: Bool = false

    enum Route {
        case error(Error)
        case warning(Error)
        case subscribe(node: DVPNNodeInfo)
        case openPlans(for: DVPNNodeInfo)
        case accountInfo
    }
    
    private let model: ConnectionModel
    private var cancellables = Set<AnyCancellable>()
    
    private var skipViewWillAppear = true
    
    init(model: ConnectionModel, router: Router) {
        self.model = model
        self.router = router
        
        self.model.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case let .updateConnection(status):
                    self?.updateConnection(status: status)
                    log.info("Status was changed to \(status)")
                case let .update(isTunelActive):
                    self?.updateConnection(isConnected: isTunelActive)
                case let .updateLocation(countryName, moniker):
                    self?.updateLocation(countryName: countryName, moniker: moniker)
                case let .updateBandwidth(bandwidth):
                    self?.updateBandwidth(bandwidth: bandwidth)
                case let .updateSubscription(initialBandwidth, bandwidthConsumed):
                    self?.updateSubscription(
                        initialBandwidth: initialBandwidth,
                        bandwidthConsumed: bandwidthConsumed
                    )
                case let .setButton(isLoading):
                    self?.updateButton(isLoading: isLoading)
                case let .error(error):
                    self?.show(error: error)
                case let .openPlans(node):
                    router.play(event: .openPlans(for: node))
                case let .warning(error):
                    router.play(event: .warning(error))
                case .openNodes:
                    #warning("TODO handle node selection")
                }
                
            }
            .store(in: &cancellables)
        
        setConnectionInfoViewModels()
    }
    
    func viewWillAppear() {
        model.checkNodeForUpdate()
    }
}

extension ConnectionViewModel {
    
    func toggleConnection(_ newState: Bool) {
        UIImpactFeedbackGenerator.lightFeedback()
        newState ? model.connect() : model.disconnect()
    }

    func didEnterForeground() {
        model.refreshNodeState()
    }

    @objc
    func didTapAccountInfoButton() {
        UIImpactFeedbackGenerator.lightFeedback()
        router.play(event: .accountInfo)
    }
}

// MARK: - Private

extension ConnectionViewModel {
    private func show(error: Error) {
        router.play(event: .error(error))
    }
    
    private func setConnectionInfoViewModels() {
        connectionInfoViewModels = [
           .connectionInfo(.init(type: .download, value: downloadSpeed ?? "", symbols: downloadSpeedUnits)),
           .connectionInfo(.init(type: .upload, value: uploadSpeed ?? "", symbols: uploadSpeedUnits)),
            .connectionInfo(.init(type: .bandwidth, value: initialBandwidthGB ?? "", symbols: L10n.Common.gb)),
           .connectionInfo(.init(type: .duration, value: duration ?? "-", symbols: ""))
       ]
    }

    private func updateConnection(isConnected: Bool) {
        self.isConnected = isConnected
    }

    private func updateConnection(status: ConnectionStatus) {
        self.connectionStatus = status
        self.isLoading = isLoading || status.isLoading
    }
    
    private func updateLocation(countryName: String, moniker: String) {
        self.countryName = countryName
        self.moniker = moniker
        if let countryCode = CountryFormatter.code(for: countryName),
           let image = Flag(countryCode: countryCode)?.image(style: .roundedRect) {
            self.countryImage = image
        }
    }
    
    private func updateBandwidth(bandwidth: Bandwidth) {
        (downloadSpeed, downloadSpeedUnits) = bandwidth.download.getBandwidthKBorMB
        (uploadSpeed, uploadSpeedUnits) = bandwidth.upload.getBandwidthKBorMB
        speedImage = bandwidth.speedImage
    }

    private func updateButton(isLoading: Bool) {
        self.isLoading = isLoading
    }
    
    private func updateSubscription(initialBandwidth: String, bandwidthConsumed: String) {
        self.initialBandwidthGB = (Int64(initialBandwidth) ?? 0).bandwidthGBString
        self.bandwidthConsumedGB = (Int64(bandwidthConsumed) ?? 0).bandwidthGBString
    }
}
