//
//  LocalTestingScenariosManager.swift
//  Loop
//
//  Created by Michael Pangburn on 4/22/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import LoopTestingKit
import os.log


final class LocalTestingScenariosManager: TestingScenariosManagerRequirements, DirectoryObserver {
    unowned let deviceManager: DeviceDataManager

    let log = OSLog(category: "LocalTestingScenariosManager")

    private let fileManager = FileManager.default
    private let scenariosSource: URL
    private var directoryObservationToken: DirectoryObservationToken?

    private(set) var scenarioURLs: [URL] = []
    var activeScenarioURL: URL?
    var activeScenario: TestingScenario?

    weak var delegate: TestingScenariosManagerDelegate? {
        didSet {
            delegate?.testingScenariosManager(self, didUpdateScenarioURLs: scenarioURLs)
        }
    }

    init(deviceManager: DeviceDataManager) {
        guard FeatureFlags.scenariosEnabled else {
            fatalError("\(#function) should be invoked only when scenarios are enabled")
        }

        self.deviceManager = deviceManager
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.scenariosSource = documentsDirectory.appendingPathComponent("scenarios")

        log.debug("Place testing scenarios in %{public}@", scenariosSource.path)
        if !fileManager.fileExists(atPath: scenariosSource.path) {
            do {
                try fileManager.createDirectory(at: scenariosSource, withIntermediateDirectories: false)
            } catch {
                log.error("%{public}@", String(describing: error))
            }
        }

        directoryObservationToken = observeDirectory(at: scenariosSource) { [weak self] in
            self?.reloadScenarioURLs()
        }
        reloadScenarioURLs()
    }

    func fetchScenario(from url: URL, completion: (Result<TestingScenario, Error>) -> Void) {
        let result = Result(catching: { try TestingScenario(source: url) })
        completion(result)
    }

    private func reloadScenarioURLs() {
        do {
            let scenarioURLs = try fileManager.contentsOfDirectory(at: scenariosSource, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
                .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            self.scenarioURLs = scenarioURLs
            delegate?.testingScenariosManager(self, didUpdateScenarioURLs: scenarioURLs)
            log.debug("Reloaded scenario URLs")
        } catch {
            log.error("%{public}@", String(describing: error))
        }
    }
}
