//
//  ReleazioUpdatePromptViewController.swift
//  Releazio
//
//  Created by Releazio Team on 05.10.2025.
//

#if canImport(UIKit)
import UIKit

/// UIKit view controller for Releazio update prompt
/// Supports update types 2 (popup) and 3 (popup force)
public class ReleazioUpdatePromptViewController: UIViewController {
    
    // MARK: - Properties
    
    /// Update state from checkUpdates()
    public let updateState: UpdateState
    
    /// Update prompt style
    public let style: UpdatePromptStyle
    
    /// Theme configuration
    private let theme: UpdatePromptUIKitTheme
    
    /// Custom colors for component
    private let customColors: UIComponentColors?
    
    /// Custom localization strings
    private let customStrings: UILocalizationStrings?
    
    /// Localization manager (with auto-detected locale)
    private let localization: LocalizationManager
    
    /// Callback when user chooses to update
    public var onUpdate: (() -> Void)?
    
    /// Callback when user skips (type 3 only)
    public var onSkip: ((Int) -> Void)?
    
    /// Callback when user closes (type 2 only)
    public var onClose: (() -> Void)?
    
    /// Callback when user taps info button
    public var onInfoTap: (() -> Void)?
    
    private var remainingSkipAttempts: Int
    
    // MARK: - UI Components
    
    private lazy var overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.translatesAutoresizingMaskIntoConstraints = false
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(overlayTapped))
        view.addGestureRecognizer(tapGesture)
        return view
    }()
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowRadius = 10
        view.layer.shadowOpacity = 0.2
        view.layer.shadowOffset = CGSize(width: 0, height: 5)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var headerContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var headerStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        // Will be set in setupUI after initialization
        return label
    }()
    
    private lazy var infoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
        button.tintColor = .systemGray
        button.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .systemGray
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textColor = .systemGray
        label.numberOfLines = 0
        label.textAlignment = .center
        // Will be set in setupUI after initialization
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var updateButton: UIButton = {
        let button = UIButton(type: .system)
        // Will be set in setupUI after initialization
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(updateTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var skipButton: UIButton = {
        let button = UIButton(type: .system)
        // Will be set in setupUI after initialization
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Initialization
    
    /// Initialize update prompt view controller
    /// - Parameters:
    ///   - updateState: Update state from checkUpdates()
    ///   - style: Update prompt style (default: .native)
    ///   - customColors: Custom colors for buttons and text (optional)
    ///   - customStrings: Custom localization strings (optional)
    ///   - onUpdate: Update action
    ///   - onSkip: Skip action (for type 3)
    ///   - onClose: Close action (for type 2)
    ///   - onInfoTap: Info button action (opens post_url)
    public init(
        updateState: UpdateState,
        style: UpdatePromptStyle = .default,
        customColors: UIComponentColors? = nil,
        customStrings: UILocalizationStrings? = nil,
        onUpdate: (() -> Void)? = nil,
        onSkip: ((Int) -> Void)? = nil,
        onClose: (() -> Void)? = nil,
        onInfoTap: (() -> Void)? = nil
    ) {
        self.updateState = updateState
        self.style = style
        // Auto-detect color scheme from trait collection will be done in viewDidLoad
        self.theme = UpdatePromptUIKitTheme(style: style, colorScheme: .light)
        self.customColors = customColors
        self.customStrings = customStrings
        // Auto-detect locale from system
        let detectedLocale = LocalizationManager.detectSystemLocale()
        self.localization = LocalizationManager(locale: detectedLocale)
        self.onUpdate = onUpdate
        self.onSkip = onSkip
        self.onClose = onClose
        self.onInfoTap = onInfoTap
        self.remainingSkipAttempts = updateState.remainingSkipAttempts
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        if style == .inAppUpdate {
            setupInAppUpdateStyle()
        } else {
            setupNativeStyle()
        }
    }
    private func setupNativeStyle() {
        // Set texts from custom strings or localization
        titleLabel.text = updateTitle
        let message = updateState.channelData.updateMessage.isEmpty ? updateMessage : updateState.channelData.updateMessage
        messageLabel.text = message
        
        updateButton.setTitle(updateButtonText, for: .normal)
        updateButton.setTitleColor(updateButtonTextColor, for: .normal)
        updateButton.backgroundColor = updateButtonColor
        
        skipButton.setTitle(skipButtonText + " (\(remainingSkipAttempts))", for: .normal)
        skipButton.setTitleColor(.lightGray, for: .normal)
        skipButton.backgroundColor = .clear
        
        view.addSubview(overlayView)
        view.addSubview(containerView)
        
        // Header container
        containerView.addSubview(headerContainer)
        
        // Title (centered)
        headerContainer.addSubview(titleLabel)
        
        // Buttons stack (overlay on title)
        if updateState.channelData.postUrl != nil {
            headerStackView.addArrangedSubview(infoButton)
        }
        
        headerStackView.addArrangedSubview(UIView()) // Center spacer (stretches)
        
        if updateState.updateType == 2 {
            headerStackView.addArrangedSubview(closeButton)
        }
        
        headerContainer.addSubview(headerStackView)
        
        // Content
        containerView.addSubview(messageLabel)
        
        // Buttons
        containerView.addSubview(updateButton)
        if updateState.updateType == 3 && remainingSkipAttempts > 0 {
            containerView.addSubview(skipButton)
        }
        
        setupNativeConstraints()
    }
    private func setupInAppUpdateStyle() {
        // Set texts
        titleLabel.text = updateTitle
        let message = updateState.channelData.updateMessage.isEmpty ? updateMessage : updateState.channelData.updateMessage
        messageLabel.text = message
        
        // Configure buttons
        updateButton.setTitle(updateButtonText, for: .normal)
        updateButton.setTitleColor(updateButtonTextColor, for: .normal)
        updateButton.backgroundColor = updateButtonColor
        updateButton.layer.cornerRadius = 14
        updateButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        
        skipButton.setTitle(skipButtonText + " (\(remainingSkipAttempts))", for: .normal)
        skipButton.setTitleColor(theme.secondaryTextColor, for: .normal)
        skipButton.backgroundColor = .clear
        
        // Setup full-screen view with white background
        view.backgroundColor = .white
        
        // Top header with buttons
        let topHeaderStack = UIStackView()
        topHeaderStack.axis = .horizontal
        topHeaderStack.alignment = .center
        topHeaderStack.distribution = .fill
        topHeaderStack.spacing = 12
        topHeaderStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Info button (left)
        if updateState.channelData.postUrl != nil {
            let infoBtn = UIButton(type: .system)
            infoBtn.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
            infoBtn.tintColor = theme.closeButtonColor
            infoBtn.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)
            topHeaderStack.addArrangedSubview(infoBtn)
        } else {
            topHeaderStack.addArrangedSubview(UIView())
        }
        
        topHeaderStack.addArrangedSubview(UIView()) // Spacer
        
        // Close button (right, only for type 2)
        if updateState.updateType == 2 {
            let closeBtn = UIButton(type: .system)
            closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
            closeBtn.tintColor = theme.closeButtonColor
            closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
            topHeaderStack.addArrangedSubview(closeBtn)
        } else {
            topHeaderStack.addArrangedSubview(UIView())
        }
        
        view.addSubview(topHeaderStack)
        
        // Rocket icon
        let rocketImageView = UIImageView()
        rocketImageView.image = UIImage(named: "rocket", in: Bundle.module, compatibleWith: nil)
        rocketImageView.contentMode = .scaleAspectFit
        rocketImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Content area with rocket, title and message
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 20
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentStack.addArrangedSubview(rocketImageView)
        
        titleLabel.textAlignment = .center
        titleLabel.textColor = theme.textColor
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        contentStack.addArrangedSubview(titleLabel)
        
        messageLabel.textAlignment = .center
        messageLabel.textColor = theme.secondaryTextColor
        messageLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        messageLabel.numberOfLines = 0
        contentStack.addArrangedSubview(messageLabel)
        
        view.addSubview(contentStack)
        
        // Buttons stack at bottom
        let buttonsStack = UIStackView()
        buttonsStack.axis = .vertical
        buttonsStack.alignment = .center
        buttonsStack.spacing = 12
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        
        buttonsStack.addArrangedSubview(updateButton)
        if updateState.updateType == 3 && remainingSkipAttempts > 0 {
            buttonsStack.addArrangedSubview(skipButton)
        }
        
        view.addSubview(buttonsStack)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Top header
            topHeaderStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            topHeaderStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            topHeaderStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Rocket icon
            rocketImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
            rocketImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 300),
            
            // Content stack (centered vertically)
            contentStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            
            // Buttons at bottom
            buttonsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonsStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            buttonsStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            buttonsStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            
            updateButton.widthAnchor.constraint(equalToConstant: 300),
            updateButton.heightAnchor.constraint(equalToConstant: 56),
            
            skipButton.widthAnchor.constraint(equalToConstant: 300),
            skipButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    private func setupNativeConstraints() {
        // Proportional width constraint (85% of screen)
        let proportionalWidth = containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85)
        proportionalWidth.priority = .defaultHigh
        
        var constraints: [NSLayoutConstraint] = [
            // Overlay
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Container
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            proportionalWidth,  // 85% of screen width (with high priority)
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 500),  // But max 500pt
            
            // Header container
            headerContainer.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            headerContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            headerContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            headerContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            
            // Title (centered in header)
            titleLabel.centerXAnchor.constraint(equalTo: headerContainer.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: headerContainer.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerContainer.trailingAnchor, constant: -32),
            
            // Buttons stack (overlay on header)
            headerStackView.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            headerStackView.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            headerStackView.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            headerStackView.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            
            // Message
            messageLabel.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 16),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Buttons
            updateButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),
            updateButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            updateButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            updateButton.heightAnchor.constraint(equalToConstant: 50),
            updateButton.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -16),
        ]
        // Skip button constraints (only if added to view)
        if updateState.updateType == 3 && remainingSkipAttempts > 0 && skipButton.superview != nil {
            constraints.append(contentsOf: [
                skipButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
                skipButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
                skipButton.topAnchor.constraint(equalTo: updateButton.bottomAnchor, constant: 12),
                skipButton.heightAnchor.constraint(equalToConstant: 44),
                skipButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
            ])
            updateButton.bottomAnchor.constraint(lessThanOrEqualTo: skipButton.topAnchor, constant: -12).isActive = true
        } else {
            updateButton.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -16).isActive = true
        }
        
        NSLayoutConstraint.activate(constraints)
    }
    
    private func updateUI() {
            // Update skip button visibility and title
            if updateState.updateType == 3 && remainingSkipAttempts > 0 {
                skipButton.isHidden = false
                skipButton.setTitle(skipButtonText + " (\(remainingSkipAttempts))", for: .normal)
            } else {
                skipButton.isHidden = true
            }
        }
    
    // MARK: - Computed Properties for Custom Strings and Colors
    
    private var updateTitle: String {
        return customStrings?.updateTitle ?? localization.updateTitle
    }
    
    private var updateMessage: String {
        return customStrings?.updateMessage ?? localization.updateMessage
    }
    
    private var updateButtonText: String {
        return customStrings?.updateButtonText ?? localization.updateButtonText
    }
    
    private var skipButtonText: String {
        return customStrings?.skipButtonText ?? localization.skipButtonText
    }
    
    private var skipRemainingText: String {
        if let customFormat = customStrings?.skipRemainingTextFormat {
            return String(format: customFormat, remainingSkipAttempts)
        }
        return localization.skipRemainingText(count: remainingSkipAttempts)
    }
    
    private var updateButtonColor: UIColor {
        return .black
    }
    
    private var updateButtonTextColor: UIColor {
        if let customColor = customColors?.updateButtonTextColor {
            return customColor
        }
        return .white
    }
    
    // MARK: - Actions
    
    @objc private func overlayTapped() {
        // Only allow dismiss for type 2
        if updateState.updateType == 2 {
            closeTapped()
        }
    }
    
    @objc private func infoTapped() {
        onInfoTap?()
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true) {
            self.onClose?()
        }
    }
    
    @objc private func updateTapped() {
        onUpdate?()
    }
    
    @objc private func skipTapped() {
        let newRemaining = remainingSkipAttempts - 1
        remainingSkipAttempts = newRemaining
        updateUI()
        onSkip?(newRemaining)
        
        // "Skip" means close the popup
        dismiss(animated: true)
    }
}

#endif

