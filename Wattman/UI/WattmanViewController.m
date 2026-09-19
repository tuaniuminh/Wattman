#import "WattmanViewController.h"
#import "../Core/WattmanBatteryModel.h"
#import "WattmanCardView.h"

@interface WattmanViewController () <WattmanBatteryModelDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStackView;

// Hero Card Elements
@property (nonatomic, strong) UIView *heroCard;
@property (nonatomic, strong) UILabel *wattageLabel;
@property (nonatomic, strong) UILabel *statusBadgeLabel;
@property (nonatomic, strong) UILabel *voltageHeroLabel;
@property (nonatomic, strong) UILabel *currentHeroLabel;

// Battery Health Card Value Labels
@property (nonatomic, strong) UILabel *healthValLabel;
@property (nonatomic, strong) UILabel *capacityValLabel;
@property (nonatomic, strong) UILabel *designCapValLabel;
@property (nonatomic, strong) UILabel *cycleCountValLabel;
@property (nonatomic, strong) UILabel *temperatureValLabel;
@property (nonatomic, strong) UILabel *socValLabel;

// Charger Card Value Labels
@property (nonatomic, strong) UILabel *adapterStatusValLabel;
@property (nonatomic, strong) UILabel *adapterTypeValLabel;
@property (nonatomic, strong) UILabel *timeEstimateValLabel;

@end

@implementation WattmanViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Wattman";
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
    }
    
    [self setupScrollView];
    [self setupHeroCard];
    [self setupBatteryCard];
    [self setupChargerCard];
    
    // Model binding
    [WattmanBatteryModel sharedModel].delegate = self;
    [[WattmanBatteryModel sharedModel] startMonitoringWithInterval:1.0];
    
    [self updateUI];
}

- (void)setupScrollView {
    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:_scrollView];
    
    _contentStackView = [[UIStackView alloc] init];
    _contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
    _contentStackView.axis = UILayoutConstraintAxisVertical;
    _contentStackView.spacing = 16.0;
    _contentStackView.alignment = UIStackViewAlignmentFill;
    [_scrollView addSubview:_contentStackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [_contentStackView.topAnchor constraintEqualToAnchor:_scrollView.topAnchor constant:16],
        [_contentStackView.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor constant:16],
        [_contentStackView.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor constant:-16],
        [_contentStackView.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor constant:-24],
        [_contentStackView.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor constant:-32]
    ]];
}

- (void)setupHeroCard {
    _heroCard = [[UIView alloc] init];
    _heroCard.translatesAutoresizingMaskIntoConstraints = NO;
    _heroCard.layer.cornerRadius = 24.0;
    _heroCard.layer.masksToBounds = YES;
    
    // Gradient / Nền sang trọng
    if (@available(iOS 13.0, *)) {
        _heroCard.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    } else {
        _heroCard.backgroundColor = [UIColor whiteColor];
    }
    
    // Title
    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.text = @"⚡ CÔNG SUẤT THỜI GIAN THỰC";
    titleLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    if (@available(iOS 13.0, *)) {
        titleLbl.textColor = [UIColor secondaryLabelColor];
    } else {
        titleLbl.textColor = [UIColor grayColor];
    }
    [_heroCard addSubview:titleLbl];
    
    // Wattage lớn
    _wattageLabel = [[UILabel alloc] init];
    _wattageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _wattageLabel.text = @"0.00 W";
    _wattageLabel.font = [UIFont systemFontOfSize:50 weight:UIFontWeightHeavy];
    _wattageLabel.textColor = [UIColor systemGreenColor];
    _wattageLabel.textAlignment = NSTextAlignmentCenter;
    [_heroCard addSubview:_wattageLabel];
    
    // Status Badge
    _statusBadgeLabel = [[UILabel alloc] init];
    _statusBadgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _statusBadgeLabel.text = @"Đang đọc dữ liệu...";
    _statusBadgeLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    _statusBadgeLabel.textAlignment = NSTextAlignmentCenter;
    _statusBadgeLabel.layer.cornerRadius = 12.0;
    _statusBadgeLabel.layer.masksToBounds = YES;
    _statusBadgeLabel.backgroundColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.15];
    _statusBadgeLabel.textColor = [UIColor systemGreenColor];
    [_heroCard addSubview:_statusBadgeLabel];
    
    // Divider
    UIView *divider = [[UIView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        divider.backgroundColor = [UIColor separatorColor];
    } else {
        divider.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    }
    [_heroCard addSubview:divider];
    
    // Sub Metrics (Voltage & Current)
    _voltageHeroLabel = [[UILabel alloc] init];
    _voltageHeroLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _voltageHeroLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    _voltageHeroLabel.textAlignment = NSTextAlignmentCenter;
    [_heroCard addSubview:_voltageHeroLabel];
    
    _currentHeroLabel = [[UILabel alloc] init];
    _currentHeroLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _currentHeroLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    _currentHeroLabel.textAlignment = NSTextAlignmentCenter;
    [_heroCard addSubview:_currentHeroLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLbl.topAnchor constraintEqualToAnchor:_heroCard.topAnchor constant:18],
        [titleLbl.centerXAnchor constraintEqualToAnchor:_heroCard.centerXAnchor],
        
        [_wattageLabel.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:10],
        [_wattageLabel.centerXAnchor constraintEqualToAnchor:_heroCard.centerXAnchor],
        
        [_statusBadgeLabel.topAnchor constraintEqualToAnchor:_wattageLabel.bottomAnchor constant:10],
        [_statusBadgeLabel.centerXAnchor constraintEqualToAnchor:_heroCard.centerXAnchor],
        [_statusBadgeLabel.heightAnchor constraintEqualToConstant:28],
        [_statusBadgeLabel.widthAnchor constraintGreaterThanOrEqualToConstant:140],
        
        [divider.topAnchor constraintEqualToAnchor:_statusBadgeLabel.bottomAnchor constant:18],
        [divider.leadingAnchor constraintEqualToAnchor:_heroCard.leadingAnchor constant:20],
        [divider.trailingAnchor constraintEqualToAnchor:_heroCard.trailingAnchor constant:-20],
        [divider.heightAnchor constraintEqualToConstant:0.5],
        
        [_voltageHeroLabel.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:12],
        [_voltageHeroLabel.leadingAnchor constraintEqualToAnchor:_heroCard.leadingAnchor constant:16],
        [_voltageHeroLabel.widthAnchor constraintEqualToAnchor:_heroCard.widthAnchor multiplier:0.45],
        [_voltageHeroLabel.bottomAnchor constraintEqualToAnchor:_heroCard.bottomAnchor constant:-16],
        
        [_currentHeroLabel.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:12],
        [_currentHeroLabel.trailingAnchor constraintEqualToAnchor:_heroCard.trailingAnchor constant:-16],
        [_currentHeroLabel.widthAnchor constraintEqualToAnchor:_heroCard.widthAnchor multiplier:0.45],
        [_currentHeroLabel.bottomAnchor constraintEqualToAnchor:_heroCard.bottomAnchor constant:-16]
    ]];
    
    [_contentStackView addArrangedSubview:_heroCard];
}

- (void)setupBatteryCard {
    WattmanCardView *card = [[WattmanCardView alloc] initWithTitle:@"Thông số Pin & Sức khỏe" icon:@"🔋"];
    
    _healthValLabel = [[UILabel alloc] init];
    [card addRowWithLabel:@"Sức khỏe pin (Chai pin)" valueLabel:_healthValLabel];
    
    _socValLabel = [[UILabel alloc] init];
    [card addRowWithLabel:@"Mức pin thực tế (SoC)" valueLabel:_socValLabel];
    
    _capacityValLabel = [[UILabel alloc] init];
    [card addRowWithLabel:@"Dung lượng sạc đầy (FCC)" valueLabel:_capacityValLabel];
    
    _designCapValLabel = [[UILabel alloc] init];
    [card addRowWithLabel:@"Dung lượng thiết kế" valueLabel:_designCapValLabel];
    
    _cycleCountValLabel = [[UILabel alloc] init];
    [card addRowWithLabel:@"Số chu kỳ sạc (Cycles)" valueLabel:_cycleCountValLabel];
    
    _temperatureValLabel = [[UILabel alloc] init];
    [card addRowWithLabel:@"Nhiệt độ cell pin" valueLabel:_temperatureValLabel];
    
    [_contentStackView addArrangedSubview:card];
}

- (void)setupChargerCard {
    WattmanCardView *card = [[WattmanCardView alloc] initWithTitle:@"Nguồn sạc & Năng lượng" icon:@"🔌"];
    
    _adapterStatusValLabel = [[UILabel alloc] init];
    [card addRowWithLabel:@"Cắm sạc ngoài" valueLabel:_adapterStatusValLabel];
    
    _adapterTypeValLabel = [[UILabel alloc] init];
    [card addRowWithLabel:@"Chế độ nhận diện" valueLabel:_adapterTypeValLabel];
    
    _timeEstimateValLabel = [[UILabel alloc] init];
    [card addRowWithLabel:@"Thời gian pin còn lại" valueLabel:_timeEstimateValLabel];
    
    [_contentStackView addArrangedSubview:card];
}

#pragma mark - UI Updates

- (void)updateUI {
    WattmanBatteryModel *model = [WattmanBatteryModel sharedModel];
    WattmanMetrics m = model.currentMetrics;
    
    // 1. Hero Card
    self.wattageLabel.text = model.wattageString;
    if (m.current_ma > 0) {
        // Đang sạc: Màu xanh lá
        self.wattageLabel.textColor = [UIColor systemGreenColor];
        self.statusBadgeLabel.textColor = [UIColor systemGreenColor];
        self.statusBadgeLabel.backgroundColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.15];
    } else if (m.current_ma < -800) {
        // Xả pin nhanh (>800mA): Màu cam/đỏ
        self.wattageLabel.textColor = [UIColor systemOrangeColor];
        self.statusBadgeLabel.textColor = [UIColor systemOrangeColor];
        self.statusBadgeLabel.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:0.15];
    } else {
        // Xả pin bình thường: Màu xanh dương / xám
        self.wattageLabel.textColor = [UIColor systemBlueColor];
        self.statusBadgeLabel.textColor = [UIColor systemBlueColor];
        self.statusBadgeLabel.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.15];
    }
    
    self.statusBadgeLabel.text = model.statusBadgeString;
    self.voltageHeroLabel.text = [NSString stringWithFormat:@"Điện áp: %u mV", m.voltage_mv];
    self.currentHeroLabel.text = [NSString stringWithFormat:@"Dòng: %d mA", m.current_ma];
    
    // 2. Battery Card
    self.healthValLabel.text = model.healthString;
    self.socValLabel.text = model.stateOfChargeString;
    self.capacityValLabel.text = model.capacityString;
    self.designCapValLabel.text = model.designCapacityString;
    self.cycleCountValLabel.text = model.cycleCountString;
    self.temperatureValLabel.text = model.temperatureString;
    
    // 3. Charger Card
    self.adapterStatusValLabel.text = m.adapter_connected ? @"Đã kết nối A/C" : @"Không cắm";
    if (m.adapter_desc[0] != '\0') {
        self.adapterTypeValLabel.text = [NSString stringWithFormat:@"%s (%@)", m.adapter_desc, model.sourceTypeString];
    } else {
        self.adapterTypeValLabel.text = model.sourceTypeString;
    }
    if (m.time_to_empty_min > 0 && m.time_to_empty_min < 1440) {
        self.timeEstimateValLabel.text = [NSString stringWithFormat:@"~%u giờ %u phút", m.time_to_empty_min / 60, m.time_to_empty_min % 60];
    } else {
        self.timeEstimateValLabel.text = m.is_charging ? @"Đang sạc..." : @"Không xác định";
    }
}

#pragma mark - WattmanBatteryModelDelegate

- (void)batteryModelDidUpdateMetrics:(WattmanMetrics)metrics {
    [self updateUI];
}

@end
