//
//  SettingsViewController.swift
//  particles
//
//  Created by Naruki Chigira on 2020/07/18.
//  Copyright © 2020 Naruki Chigira. All rights reserved.
//

import Combine
import UIKit

class Setting: ObservableObject {
    enum Constants {
        static let numbers: [NSNumber] = [100, 1_000, 10_000, 100_000]
        static let initialNumberIndex: Int = 1
        static let initialColoringIndex: Int = 0
    }

    enum Coloring: Int, CaseIterable {
        case colorful
        case monochrome
    }

    @Published var coloring: Coloring = Coloring.allCases[Constants.initialColoringIndex]
    @Published var number: Int = Constants.numbers[Constants.initialNumberIndex].intValue
}

protocol SettingsViewControllerDelegate: class {
    func settingsViewControllerDidComplete(_ viewCotroller: SettingsViewController, setting: Setting)
}

final class SettingsViewController: UIViewController {
    @IBOutlet private var coloringSegmentedControl: UISegmentedControl! {
        didSet {
            let titleTextAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.darkText
            ]
            coloringSegmentedControl.setTitleTextAttributes(titleTextAttributes, for: .normal)
            coloringSegmentedControl.selectedSegmentIndex = Setting.Constants.initialColoringIndex
        }
    }
    @IBOutlet private var numbersSegmentedControl: UISegmentedControl! {
        didSet {
            let titleTextAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.darkText
            ]
            numbersSegmentedControl.setTitleTextAttributes(titleTextAttributes, for: .normal)
            numbersSegmentedControl.selectedSegmentIndex = Setting.Constants.initialNumberIndex
        }
    }

    let setting = Setting()
    private var cancellables: Set<AnyCancellable> = []
    weak var delegate: SettingsViewControllerDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        coloringSegmentedControl.publisher(for: \.selectedSegmentIndex)
            .compactMap { Setting.Coloring(rawValue: $0) }
            .assign(to: \.coloring, on: setting)
            .store(in: &cancellables)

        numbersSegmentedControl.publisher(for: \.selectedSegmentIndex)
            .map { Setting.Constants.numbers[$0].intValue }
            .assign(to: \.number, on: setting)
            .store(in: &cancellables)
    }

    @IBAction private func didTapOKButton(_ sender: UIButton) {
        delegate?.settingsViewControllerDidComplete(self, setting: setting)
    }
}
