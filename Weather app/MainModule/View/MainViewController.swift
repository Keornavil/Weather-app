import UIKit
import Combine

final class MainViewController: UIViewController {

    // MARK: - Properties
    private let viewModel: MainViewModelProtocol
    private var cancellables = Set<AnyCancellable>()
    private let hourlyItemWidth: CGFloat = 90
    private var lastHourlyItemCount = 0
    private var currentDailyItems: [DailyItemViewData] = []
    private var lastDailyDetailsItemCount = 0
    private var hasLoadedContent = false
    private let defaultHourlyCardBackgroundColor = UIColor.white.withAlphaComponent(0.2)

    // MARK: - Layers
    private let gradientLayer = CAGradientLayer()
    private let safeAreaFadeLayer = CAGradientLayer()

    // MARK: - Scroll Content
    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.showsVerticalScrollIndicator = false
        view.delaysContentTouches = false
        view.clipsToBounds = true
        return view
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let safeAreaFadeView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()

    // MARK: - State Views
    private let loadingView = UIActivityIndicatorView(style: .large)

    private let errorContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.isHidden = true
        return stack
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = localizedStringRU("weather.retry")
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.2)
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
        button.configuration = config
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Current Weather Block
    private let currentCard = UIView()
    private let cityLabel = UILabel()
    private let localTimeLabel = UILabel()
    private let tempLabel = UILabel()
    private let conditionLabel = UILabel()
    private let feelsLikeLabel = UILabel()

    // MARK: - Hourly Block
    private let hourlyContainer = UIView()

    private let hourlyStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let hourlyScrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.showsHorizontalScrollIndicator = false
        return view
    }()

    // MARK: - Daily Block
    private let dailyContainer = UIView()

    private let dailyStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Daily Details View
    private let dailyDetailsView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerRadius = 0
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }()

    private let dailyDetailsTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        return label
    }()

    private lazy var dailyDetailsBackButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("←", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        button.addTarget(self, action: #selector(closeDailyDetailsTapped), for: .touchUpInside)
        return button
    }()

    private let dailyDetailsScrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.showsHorizontalScrollIndicator = false
        return view
    }()

    private let dailyDetailsHoursStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Init
    init(viewModel: MainViewModelProtocol) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        bindViewModel()
        viewModel.loadWeather()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
        safeAreaFadeLayer.frame = safeAreaFadeView.bounds
        updateHourlyContentInsets(itemCount: lastHourlyItemCount)
        updateDailyDetailsContentInsets(itemCount: lastDailyDetailsItemCount)
    }
}

// MARK: - Setup
private extension MainViewController {

    func setupView() {
        title = localizedStringRU("weather.title")
        configureNavigationBarAppearance()

        gradientLayer.colors = [
            UIColor(red: 0.15, green: 0.35, blue: 0.67, alpha: 1).cgColor,
            UIColor(red: 0.28, green: 0.58, blue: 0.86, alpha: 1).cgColor,
            UIColor(red: 0.55, green: 0.76, blue: 0.95, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.2, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.8, y: 1.0)
        view.layer.addSublayer(gradientLayer)

        setupLoadingAndError()
        setupScrollContent()
        setupSafeAreaFade()
        setupCurrentCard()
        setupHourlySection()
        setupDailySection()
    }

    func setupLoadingAndError() {
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.color = .white
        loadingView.hidesWhenStopped = true
        view.addSubview(loadingView)

        errorContainer.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.addArrangedSubview(errorLabel)
        errorContainer.addArrangedSubview(retryButton)
        view.addSubview(errorContainer)

        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            errorContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            errorContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func setupScrollContent() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    func setupSafeAreaFade() {
        view.addSubview(safeAreaFadeView)

        safeAreaFadeLayer.colors = [
            UIColor(red: 0.15, green: 0.35, blue: 0.67, alpha: 1).cgColor,
            UIColor(red: 0.15, green: 0.35, blue: 0.67, alpha: 0.75).cgColor,
            UIColor(red: 0.15, green: 0.35, blue: 0.67, alpha: 0).cgColor
        ]
        safeAreaFadeLayer.locations = [0, 0.35, 1]
        safeAreaFadeLayer.startPoint = CGPoint(x: 0.5, y: 0)
        safeAreaFadeLayer.endPoint = CGPoint(x: 0.5, y: 1)
        safeAreaFadeView.layer.addSublayer(safeAreaFadeLayer)

        NSLayoutConstraint.activate([
            safeAreaFadeView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            safeAreaFadeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            safeAreaFadeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            safeAreaFadeView.heightAnchor.constraint(equalToConstant: 64)
        ])
    }

    func configureNavigationBarAppearance() {
        guard let navigationBar = navigationController?.navigationBar else { return }

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.15, green: 0.35, blue: 0.67, alpha: 1)
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = .white
    }

    func setupCurrentCard() {
        currentCard.translatesAutoresizingMaskIntoConstraints = false
        currentCard.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        currentCard.layer.cornerRadius = 20

        cityLabel.font = .systemFont(ofSize: 30, weight: .bold)
        cityLabel.textColor = .white
        cityLabel.textAlignment = .center

        localTimeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        localTimeLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        localTimeLabel.textAlignment = .center

        tempLabel.font = .systemFont(ofSize: 56, weight: .light)
        tempLabel.textColor = .white
        tempLabel.textAlignment = .center

        conditionLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        conditionLabel.textColor = .white
        conditionLabel.textAlignment = .center

        feelsLikeLabel.font = .systemFont(ofSize: 16, weight: .medium)
        feelsLikeLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        feelsLikeLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [cityLabel, localTimeLabel, tempLabel, conditionLabel, feelsLikeLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        currentCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: currentCard.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: currentCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: currentCard.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: currentCard.bottomAnchor, constant: -20)
        ])

        contentStack.addArrangedSubview(currentCard)
    }

    func setupHourlySection() {
        let titleLabel = makeSectionTitle(localizedStringRU("weather.hourly.title"))
        hourlyContainer.translatesAutoresizingMaskIntoConstraints = false
        hourlyContainer.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        hourlyContainer.layer.cornerRadius = 16

        hourlyContainer.addSubview(hourlyScrollView)
        hourlyScrollView.addSubview(hourlyStack)

        NSLayoutConstraint.activate([
            hourlyScrollView.topAnchor.constraint(equalTo: hourlyContainer.topAnchor, constant: 12),
            hourlyScrollView.leadingAnchor.constraint(equalTo: hourlyContainer.leadingAnchor, constant: 12),
            hourlyScrollView.trailingAnchor.constraint(equalTo: hourlyContainer.trailingAnchor, constant: -12),
            hourlyScrollView.bottomAnchor.constraint(equalTo: hourlyContainer.bottomAnchor, constant: -12),
            hourlyScrollView.heightAnchor.constraint(equalToConstant: 112),

            hourlyStack.topAnchor.constraint(equalTo: hourlyScrollView.contentLayoutGuide.topAnchor),
            hourlyStack.leadingAnchor.constraint(equalTo: hourlyScrollView.contentLayoutGuide.leadingAnchor),
            hourlyStack.trailingAnchor.constraint(equalTo: hourlyScrollView.contentLayoutGuide.trailingAnchor),
            hourlyStack.bottomAnchor.constraint(equalTo: hourlyScrollView.contentLayoutGuide.bottomAnchor),
            hourlyStack.heightAnchor.constraint(equalTo: hourlyScrollView.frameLayoutGuide.heightAnchor)
        ])

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(hourlyContainer)
    }

    func setupDailySection() {
        let titleLabel = makeSectionTitle(localizedStringRU("weather.daily.title"))
        dailyContainer.translatesAutoresizingMaskIntoConstraints = false
        dailyContainer.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        dailyContainer.layer.cornerRadius = 16

        dailyContainer.addSubview(dailyStack)
        dailyContainer.addSubview(dailyDetailsView)
        dailyDetailsView.addSubview(dailyDetailsBackButton)
        dailyDetailsView.addSubview(dailyDetailsTitleLabel)
        dailyDetailsView.addSubview(dailyDetailsScrollView)
        dailyDetailsScrollView.addSubview(dailyDetailsHoursStack)

        NSLayoutConstraint.activate([
            dailyStack.topAnchor.constraint(equalTo: dailyContainer.topAnchor, constant: 12),
            dailyStack.leadingAnchor.constraint(equalTo: dailyContainer.leadingAnchor, constant: 12),
            dailyStack.trailingAnchor.constraint(equalTo: dailyContainer.trailingAnchor, constant: -12),
            dailyStack.bottomAnchor.constraint(equalTo: dailyContainer.bottomAnchor, constant: -12),

            dailyDetailsView.topAnchor.constraint(equalTo: dailyContainer.topAnchor, constant: 12),
            dailyDetailsView.leadingAnchor.constraint(equalTo: dailyContainer.leadingAnchor, constant: 12),
            dailyDetailsView.trailingAnchor.constraint(equalTo: dailyContainer.trailingAnchor, constant: -12),
            dailyDetailsView.bottomAnchor.constraint(equalTo: dailyContainer.bottomAnchor, constant: -12),

            dailyDetailsBackButton.topAnchor.constraint(equalTo: dailyDetailsView.topAnchor, constant: 10),
            dailyDetailsBackButton.leadingAnchor.constraint(equalTo: dailyDetailsView.leadingAnchor, constant: 10),
            dailyDetailsBackButton.widthAnchor.constraint(equalToConstant: 30),
            dailyDetailsBackButton.heightAnchor.constraint(equalToConstant: 30),

            dailyDetailsTitleLabel.centerYAnchor.constraint(equalTo: dailyDetailsBackButton.centerYAnchor),
            dailyDetailsTitleLabel.leadingAnchor.constraint(equalTo: dailyDetailsBackButton.trailingAnchor, constant: 8),
            dailyDetailsTitleLabel.trailingAnchor.constraint(equalTo: dailyDetailsView.trailingAnchor, constant: -10),

            dailyDetailsScrollView.topAnchor.constraint(equalTo: dailyDetailsBackButton.bottomAnchor, constant: 10),
            dailyDetailsScrollView.leadingAnchor.constraint(equalTo: dailyDetailsView.leadingAnchor),
            dailyDetailsScrollView.trailingAnchor.constraint(equalTo: dailyDetailsView.trailingAnchor),
            dailyDetailsScrollView.bottomAnchor.constraint(equalTo: dailyDetailsView.bottomAnchor),
            dailyDetailsScrollView.heightAnchor.constraint(equalToConstant: 112),

            dailyDetailsHoursStack.topAnchor.constraint(equalTo: dailyDetailsScrollView.contentLayoutGuide.topAnchor),
            dailyDetailsHoursStack.leadingAnchor.constraint(equalTo: dailyDetailsScrollView.contentLayoutGuide.leadingAnchor),
            dailyDetailsHoursStack.trailingAnchor.constraint(equalTo: dailyDetailsScrollView.contentLayoutGuide.trailingAnchor),
            dailyDetailsHoursStack.bottomAnchor.constraint(equalTo: dailyDetailsScrollView.contentLayoutGuide.bottomAnchor),
            dailyDetailsHoursStack.heightAnchor.constraint(equalTo: dailyDetailsScrollView.frameLayoutGuide.heightAnchor)
        ])

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(dailyContainer)
    }
}

// MARK: - Binding
private extension MainViewController {

    func bindViewModel() {
        viewModel.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.render(state: state)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Render
private extension MainViewController {

    func render(state: MainViewState) {
        switch state {
        case .idle:
            setLoading(false)
            errorContainer.isHidden = true
            scrollView.isHidden = !hasLoadedContent
            scrollView.isUserInteractionEnabled = true
        case .loading:
            setLoading(true)
            errorContainer.isHidden = true
            scrollView.isHidden = !hasLoadedContent
            scrollView.isUserInteractionEnabled = false
        case let .loaded(content):
            setLoading(false)
            errorContainer.isHidden = true
            scrollView.isHidden = false
            scrollView.isUserInteractionEnabled = true
            apply(content: content)
            hasLoadedContent = true
        case let .error(message):
            setLoading(false)
            scrollView.isHidden = !hasLoadedContent
            scrollView.isUserInteractionEnabled = true
            errorLabel.text = message.isEmpty ? localizedStringRU("error.generic") : message
            errorContainer.isHidden = false
        }
    }

    func apply(content: MainViewContent) {
        cityLabel.text = content.cityTitle
        localTimeLabel.text = content.localTimeText
        tempLabel.text = content.temperatureText
        conditionLabel.text = content.conditionText
        feelsLikeLabel.text = content.feelsLikeText

        replaceStackContent(in: hourlyStack) {
            content.hourlyItems.map(makeHourlyItemView)
        }
        lastHourlyItemCount = content.hourlyItems.count
        updateHourlyContentInsets(itemCount: lastHourlyItemCount)

        replaceStackContent(in: dailyStack) {
            content.dailyItems.enumerated().map(makeDailyItemView)
        }
        currentDailyItems = content.dailyItems
        closeDailyDetailsIfNeeded()
    }

    func replaceStackContent(in stack: UIStackView, builder: () -> [UIView]) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        builder().forEach { stack.addArrangedSubview($0) }
    }

    func setLoading(_ isLoading: Bool) {
        if isLoading {
            loadingView.startAnimating()
        } else {
            loadingView.stopAnimating()
        }
        retryButton.isEnabled = !isLoading
    }

    func updateHourlyContentInsets(itemCount: Int) {
        guard itemCount > 0 else {
            hourlyScrollView.contentInset = .zero
            return
        }

        let spacing = hourlyStack.spacing
        let contentWidth = (CGFloat(itemCount) * hourlyItemWidth) + (CGFloat(max(itemCount - 1, 0)) * spacing)
        let availableWidth = hourlyScrollView.bounds.width

        if itemCount < 4 && contentWidth < availableWidth {
            let horizontalInset = (availableWidth - contentWidth) / 2
            hourlyScrollView.contentInset = UIEdgeInsets(top: 0, left: horizontalInset, bottom: 0, right: horizontalInset)
            hourlyScrollView.setContentOffset(CGPoint(x: -horizontalInset, y: 0), animated: false)
        } else {
            hourlyScrollView.contentInset = .zero
            hourlyScrollView.setContentOffset(.zero, animated: false)
        }
    }

    func updateDailyDetailsContentInsets(itemCount: Int) {
        guard itemCount > 0 else {
            dailyDetailsScrollView.contentInset = .zero
            return
        }

        let spacing = dailyDetailsHoursStack.spacing
        let contentWidth = (CGFloat(itemCount) * hourlyItemWidth) + (CGFloat(max(itemCount - 1, 0)) * spacing)
        let availableWidth = dailyDetailsScrollView.bounds.width

        if itemCount < 4 && contentWidth < availableWidth {
            let inset = (availableWidth - contentWidth) / 2
            dailyDetailsScrollView.contentInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
            dailyDetailsScrollView.setContentOffset(CGPoint(x: -inset, y: 0), animated: false)
        } else {
            dailyDetailsScrollView.contentInset = .zero
            dailyDetailsScrollView.setContentOffset(.zero, animated: false)
        }
    }

    func closeDailyDetailsIfNeeded() {
        guard !dailyDetailsView.isHidden else { return }
        dailyDetailsView.isHidden = true
        dailyDetailsView.isUserInteractionEnabled = false
        dailyStack.isHidden = false
        dailyStack.isUserInteractionEnabled = true
        dailyStack.alpha = 1
        dailyStack.transform = .identity
        dailyDetailsView.transform = .identity
        dailyContainer.bringSubviewToFront(dailyStack)
    }
}

// MARK: - Factory
private extension MainViewController {

    func makeHourlyItemView(item: HourlyItemViewData) -> UIView {
        let container = UIView()
        container.backgroundColor = item.isCurrent
            ? UIColor.white.withAlphaComponent(0.34)
            : defaultHourlyCardBackgroundColor
        container.layer.cornerRadius = 14
        container.layer.borderWidth = item.isCurrent ? 1.5 : 0
        container.layer.borderColor = item.isCurrent
            ? UIColor.white.withAlphaComponent(0.8).cgColor
            : UIColor.clear.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        container.widthAnchor.constraint(equalToConstant: hourlyItemWidth).isActive = true

        let timeLabel = makeLabel(font: .systemFont(ofSize: 13, weight: .semibold), text: item.timeText)
        timeLabel.numberOfLines = 2
        if item.isCurrent {
            timeLabel.textColor = UIColor.white.withAlphaComponent(1.0)
        }
        let tempLabel = makeLabel(font: .systemFont(ofSize: 22, weight: .bold), text: item.temperatureText)
        if item.isCurrent {
            tempLabel.textColor = UIColor.white.withAlphaComponent(1.0)
        }
        let conditionLabel = makeLabel(font: .systemFont(ofSize: 11, weight: .medium), text: item.conditionText)
        conditionLabel.numberOfLines = 2
        if item.isCurrent {
            conditionLabel.textColor = UIColor.white.withAlphaComponent(0.95)
        }

        let stack = UIStackView(arrangedSubviews: [timeLabel, tempLabel, conditionLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])
        return container
    }

    func makeDailyItemView(indexedItem: (offset: Int, element: DailyItemViewData)) -> UIView {
        let index = indexedItem.offset
        let item = indexedItem.element

        let row = UIButton(type: .system)
        row.backgroundColor = .clear
        row.layer.cornerRadius = 12
        row.layer.borderWidth = 1
        row.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 56).isActive = true
        row.tag = index
        row.addTarget(self, action: #selector(dailyItemTapped(_:)), for: .touchUpInside)

        let dayLabel = makeLabel(font: .systemFont(ofSize: 16, weight: .semibold), text: item.dayText)
        dayLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let conditionLabel = makeLabel(font: .systemFont(ofSize: 14, weight: .medium), text: item.conditionText)
        conditionLabel.textAlignment = .right
        conditionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let minMaxLabel = makeLabel(font: .systemFont(ofSize: 16, weight: .bold), text: item.minMaxText)
        minMaxLabel.textAlignment = .right
        minMaxLabel.setContentHuggingPriority(.required, for: .horizontal)

        let chevronLabel = makeLabel(font: .systemFont(ofSize: 16, weight: .bold), text: ">")
        chevronLabel.textAlignment = .right
        chevronLabel.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [dayLabel, conditionLabel, minMaxLabel, chevronLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12)
        ])
        return row
    }

    func makeDayHourlyItemView(item: DayHourlyItemViewData) -> UIView {
        let container = UIView()
        container.backgroundColor = item.isCurrent
            ? UIColor.white.withAlphaComponent(0.34)
            : defaultHourlyCardBackgroundColor
        container.layer.cornerRadius = 14
        container.layer.borderWidth = item.isCurrent ? 1.5 : 0
        container.layer.borderColor = item.isCurrent
            ? UIColor.white.withAlphaComponent(0.8).cgColor
            : UIColor.clear.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        container.widthAnchor.constraint(equalToConstant: hourlyItemWidth).isActive = true

        let timeLabel = makeLabel(font: .systemFont(ofSize: 13, weight: .semibold), text: item.timeText)
        if item.isCurrent {
            timeLabel.textColor = UIColor.white.withAlphaComponent(1.0)
        }
        let tempLabel = makeLabel(font: .systemFont(ofSize: 22, weight: .bold), text: item.temperatureText)
        if item.isCurrent {
            tempLabel.textColor = UIColor.white.withAlphaComponent(1.0)
        }
        let conditionLabel = makeLabel(font: .systemFont(ofSize: 11, weight: .medium), text: item.conditionText)
        conditionLabel.numberOfLines = 2
        if item.isCurrent {
            conditionLabel.textColor = UIColor.white.withAlphaComponent(0.95)
        }

        let stack = UIStackView(arrangedSubviews: [timeLabel, tempLabel, conditionLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])
        return container
    }

    func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .white
        label.text = text
        return label
    }

    func makeLabel(font: UIFont, text: String) -> UILabel {
        let label = UILabel()
        label.font = font
        label.textColor = .white
        label.text = text
        label.textAlignment = .center
        return label
    }

    func localizedStringRU(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: "ru", ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }
        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }
}

// MARK: - Actions
private extension MainViewController {

    @objc
    func retryTapped() {
        viewModel.loadWeather()
    }

    @objc
    func dailyItemTapped(_ sender: UIButton) {
        guard currentDailyItems.indices.contains(sender.tag) else { return }
        let selectedItem = currentDailyItems[sender.tag]
        showDailyDetails(title: selectedItem.dayText, items: selectedItem.hourlyItems)
    }

    func showDailyDetails(title: String, items: [DayHourlyItemViewData]) {
        dailyDetailsTitleLabel.text = title
        replaceStackContent(in: dailyDetailsHoursStack) {
            items.map(makeDayHourlyItemView)
        }
        lastDailyDetailsItemCount = items.count
        updateDailyDetailsContentInsets(itemCount: lastDailyDetailsItemCount)

        let width = dailyContainer.bounds.width
        dailyDetailsView.isHidden = false
        dailyDetailsView.isUserInteractionEnabled = true
        dailyDetailsView.alpha = 1
        dailyDetailsView.transform = CGAffineTransform(translationX: width, y: 0)
        dailyStack.isHidden = false
        dailyStack.isUserInteractionEnabled = false
        dailyContainer.bringSubviewToFront(dailyDetailsView)

        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseInOut],
            animations: {
                self.dailyStack.transform = CGAffineTransform(translationX: -width * 0.35, y: 0)
                self.dailyStack.alpha = 0
                self.dailyDetailsView.transform = .identity
            },
            completion: { _ in
                self.dailyStack.isHidden = true
                self.dailyStack.transform = .identity
            }
        )
    }

    @objc
    func closeDailyDetailsTapped() {
        guard !dailyDetailsView.isHidden else { return }
        let width = dailyContainer.bounds.width
        dailyStack.isHidden = false
        dailyStack.alpha = 0
        dailyStack.transform = CGAffineTransform(translationX: -width * 0.35, y: 0)
        dailyStack.isUserInteractionEnabled = false

        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseInOut],
            animations: {
                self.dailyStack.alpha = 1
                self.dailyStack.transform = .identity
                self.dailyDetailsView.transform = CGAffineTransform(translationX: width, y: 0)
            },
            completion: { _ in
                self.dailyDetailsView.isHidden = true
                self.dailyDetailsView.isUserInteractionEnabled = false
                self.dailyDetailsView.transform = .identity
                self.dailyStack.isUserInteractionEnabled = true
                self.dailyContainer.bringSubviewToFront(self.dailyStack)
            }
        )
    }
}
